"""TaskRecord and finite-state-machine transitions.

Correction count semantics (FIXED):
- Review rejection stores findings and sets state='correcting' but does NOT
  increment correction_count.
- correction_count is incremented ONLY at correction launch (begin_correction_run).
- Launches 1, 2, 3 are permitted (count becomes 1, 2, 3).
- A fourth launch (count already 3) is denied -> awaiting-human.
- Counts survive recovery, spec re-approval, and restart -- never reset via CLI.

Infra retry budget:
- Keyed by (task_id, phase) so budget persists across op UUIDs.
- Maximum 2 retries per phase (initial + 2 = 3 total attempts).
- Auth failures consume NO retries; they pause immediately.
"""
from __future__ import annotations

import datetime
from typing import Any

from .db import SQLiteStore
from .errors import (
    InfraRetryExhaustedError,
    InvalidTransitionError,
    MaxCorrectionsError,
    ReviewerConflictError,
    SpecChangedError,
)

_TRANSITIONS: dict[str, set[str]] = {
    "idle":           {"implementing"},
    "implementing":   {"review", "correcting", "awaiting-human"},
    "correcting":     {"implementing", "awaiting-human"},
    "review":         {"validated", "correcting", "awaiting-human"},
    "validated":      {"awaiting-human"},
    "awaiting-human": set(),
}

MAX_CORRECTIONS = 3
MAX_INFRA_RETRIES = 2


def _iso_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


class TaskManager:
    def __init__(self, store: SQLiteStore) -> None:
        self._store = store

    # ------------------------------------------------------------------ #
    # CRUD                                                                 #
    # ------------------------------------------------------------------ #

    def create(
        self,
        *,
        task_id: str,
        repo_name: str,
        repo_id: str,
        issue_number: int,
        base_sha: str,
        branch: str,
        spec_digest: str,
        accept_digest: str,
        authorized_scope: str,
        authorized_roles: str,
        complexity: str = "routine",
    ) -> dict[str, Any]:
        """Create task if not exists; idempotent on same task_id."""
        now = _iso_now()
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT * FROM tasks WHERE id=?", (task_id,)
            )
            if existing is not None:
                return existing
            self._store.execute(
                """INSERT INTO tasks(
                    id, repo_name, repo_id, issue_number, base_sha, branch,
                    spec_digest, accept_digest, authorized_scope, authorized_roles,
                    state, correction_count, complexity, created_at, updated_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,'idle',0,?,?,?)""",
                (
                    task_id, repo_name, repo_id, issue_number, base_sha, branch,
                    spec_digest, accept_digest, authorized_scope, authorized_roles,
                    complexity, now, now,
                ),
            )
        return self.get(task_id)

    def get(self, task_id: str) -> dict[str, Any] | None:
        return self._store.fetchone("SELECT * FROM tasks WHERE id=?", (task_id,))

    def list_all(self) -> list[dict[str, Any]]:
        return self._store.fetchall("SELECT * FROM tasks ORDER BY created_at")

    def _update(self, task_id: str, **kwargs: Any) -> None:
        """Low-level field update.  Caller holds transaction."""
        kwargs["updated_at"] = _iso_now()
        sets = ", ".join(f"{k}=?" for k in kwargs)
        vals = list(kwargs.values()) + [task_id]
        self._store.execute(f"UPDATE tasks SET {sets} WHERE id=?", tuple(vals))

    # ------------------------------------------------------------------ #
    # State transitions                                                    #
    # ------------------------------------------------------------------ #

    def transition(
        self, task_id: str, new_state: str, **extra_fields: Any,
    ) -> dict[str, Any]:
        with self._store.transaction():
            task = self._store.fetchone("SELECT * FROM tasks WHERE id=?", (task_id,))
            if task is None:
                raise KeyError(f"Task {task_id!r} not found")
            current = task["state"]
            allowed = _TRANSITIONS.get(current, set())
            if new_state not in allowed:
                raise InvalidTransitionError(
                    f"Cannot transition {task_id!r} from {current!r} to {new_state!r}"
                )
            extra_fields["state"] = new_state
            self._update(task_id, **extra_fields)
        return self.get(task_id)

    # ------------------------------------------------------------------ #
    # Correction logic (FIXED -- split into rejection + launch)            #
    # ------------------------------------------------------------------ #

    def store_rejection(self, task_id: str, findings: str) -> dict[str, Any]:
        """Record review rejection.  Sets state='correcting' and stores findings.

        Does NOT increment correction_count -- that happens only at launch.
        """
        with self._store.transaction():
            task = self._store.fetchone("SELECT * FROM tasks WHERE id=?", (task_id,))
            if task is None:
                raise KeyError(f"Task {task_id!r} not found")
            allowed = _TRANSITIONS.get(task["state"], set())
            if "correcting" not in allowed:
                raise InvalidTransitionError(
                    f"Cannot transition {task_id!r} from {task['state']!r} to 'correcting'"
                )
            self._update(
                task_id,
                state="correcting",
                review_findings=findings,
                candidate_sha=None,
                reviewer_adapter=None,
            )
        return self.get(task_id)

    def begin_correction_run(self, task_id: str) -> int:
        """Increment correction_count atomically BEFORE spawning.

        Returns new correction_count (1..3).
        Raises MaxCorrectionsError if count is already at MAX_CORRECTIONS.
        """
        with self._store.transaction():
            task = self._store.fetchone("SELECT * FROM tasks WHERE id=?", (task_id,))
            if task is None:
                raise KeyError(f"Task {task_id!r} not found")
            count = task["correction_count"]
            if count >= MAX_CORRECTIONS:
                self._update(task_id, state="awaiting-human")
                raise MaxCorrectionsError(
                    f"Task {task_id!r} has exhausted {MAX_CORRECTIONS} corrections; "
                    "moved to awaiting-human"
                )
            new_count = count + 1
            self._update(task_id, correction_count=new_count)
        return new_count

    # ------------------------------------------------------------------ #
    # Infra retry budget (keyed by task_id + phase)                        #
    # ------------------------------------------------------------------ #

    def check_infra_budget(self, task_id: str, phase: str) -> int:
        """Return remaining infra attempts for task+phase."""
        row = self._store.fetchone(
            "SELECT attempts FROM infra_budget WHERE task_id=? AND phase=?",
            (task_id, phase),
        )
        used = row["attempts"] if row else 0
        return max(0, MAX_INFRA_RETRIES - used)

    def consume_infra_attempt(
        self, task_id: str, phase: str, *, is_auth: bool = False,
    ) -> int:
        """Consume one infra attempt.  Returns new count.

        Auth failures raise immediately without consuming.
        """
        if is_auth:
            raise InfraRetryExhaustedError(
                f"Auth failure for {task_id!r} phase {phase!r}; no retry"
            )
        with self._store.transaction():
            row = self._store.fetchone(
                "SELECT attempts FROM infra_budget WHERE task_id=? AND phase=?",
                (task_id, phase),
            )
            used = row["attempts"] if row else 0
            if used >= MAX_INFRA_RETRIES:
                raise InfraRetryExhaustedError(
                    f"Task {task_id!r} phase {phase!r} exhausted "
                    f"{MAX_INFRA_RETRIES} infra retries"
                )
            new_count = used + 1
            if row:
                self._store.execute(
                    "UPDATE infra_budget SET attempts=? WHERE task_id=? AND phase=?",
                    (new_count, task_id, phase),
                )
            else:
                self._store.execute(
                    "INSERT INTO infra_budget(task_id, phase, attempts) VALUES(?,?,?)",
                    (task_id, phase, new_count),
                )
        return new_count

    # ------------------------------------------------------------------ #
    # Validation helpers                                                   #
    # ------------------------------------------------------------------ #

    def validate_reviewer_differs(
        self, task: dict[str, Any], reviewer_provider: str,
    ) -> None:
        """Raise ReviewerConflictError if reviewer provider == writer provider."""
        writer = task.get("writer_adapter") or ""
        if writer and writer == reviewer_provider:
            raise ReviewerConflictError(
                f"Reviewer provider {reviewer_provider!r} must differ from "
                f"writer {writer!r}"
            )

    def check_base_sha_valid(self, task: dict[str, Any], current_base_sha: str) -> None:
        if task["base_sha"] != current_base_sha:
            raise SpecChangedError(
                f"Base SHA changed: task has {task['base_sha']!r}, "
                f"current is {current_base_sha!r}"
            )

    def recover_to_awaiting_human(
        self, task_id: str, actor: str, reason: str,
    ) -> dict[str, Any]:
        """Move to awaiting-human.  Does NOT reset counts."""
        with self._store.transaction():
            task = self._store.fetchone("SELECT * FROM tasks WHERE id=?", (task_id,))
            if task is None:
                raise KeyError(f"Task {task_id!r} not found")
            self._update(task_id, state="awaiting-human", review_findings=reason)
            self._store.execute(
                """INSERT INTO audit_log(ts, task_id, action, actor, detail)
                   VALUES(?,?,'recover',?,?)""",
                (_iso_now(), task_id, actor, reason),
            )
        return self.get(task_id)
