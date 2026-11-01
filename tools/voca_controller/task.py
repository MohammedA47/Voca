"""TaskRecord and finite-state-machine transitions.

Correction count semantics:
- Initial implementation run: correction_count unchanged (stays 0).
- Correction run N is allowed when correction_count < 3 BEFORE the increment.
- correction_count is incremented transactionally BEFORE spawning the correction.
- The third correction (N=3, count becomes 3) is always allowed.
- A fourth correction (count already 3) is denied → awaiting-human.
- Counts survive task recovery and spec re-approval; they cannot be reset via CLI.
"""
from __future__ import annotations

import datetime
from typing import Any

from .db import SQLiteStore
from .errors import (
    InvalidTransitionError,
    MaxCorrectionsError,
    ReviewerConflictError,
    SpecChangedError,
)

# Allowed state transitions
_TRANSITIONS: dict[str, set[str]] = {
    "idle":           {"implementing"},
    "implementing":   {"review", "correcting", "awaiting-human"},
    "correcting":     {"implementing", "awaiting-human"},
    "review":         {"validated", "correcting", "awaiting-human"},
    "validated":      {"awaiting-human"},
    "awaiting-human": {},  # human-only gate; operator may reset to implementing via recover
}

MAX_CORRECTIONS = 3


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
    ) -> dict[str, Any]:
        """Create task if not exists; idempotent (same task_id → no-op)."""
        now = _iso_now()
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT * FROM tasks WHERE id=?", (task_id,)
            )
            if existing is not None:
                return existing
            self._store.execute(
                """
                INSERT INTO tasks(
                    id, repo_name, repo_id, issue_number, base_sha, branch,
                    spec_digest, accept_digest, authorized_scope, authorized_roles,
                    state, correction_count, created_at, updated_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,'idle',0,?,?)
                """,
                (
                    task_id, repo_name, repo_id, issue_number, base_sha, branch,
                    spec_digest, accept_digest, authorized_scope, authorized_roles,
                    now, now,
                ),
            )
        return self.get(task_id)

    def get(self, task_id: str) -> dict[str, Any] | None:
        return self._store.fetchone("SELECT * FROM tasks WHERE id=?", (task_id,))

    def list_all(self) -> list[dict[str, Any]]:
        return self._store.fetchall("SELECT * FROM tasks ORDER BY created_at")

    def _update(self, task_id: str, **kwargs: Any) -> None:
        """Low-level field update; caller must hold transaction."""
        kwargs["updated_at"] = _iso_now()
        sets = ", ".join(f"{k}=?" for k in kwargs)
        vals = list(kwargs.values()) + [task_id]
        self._store.execute(f"UPDATE tasks SET {sets} WHERE id=?", tuple(vals))

    # ------------------------------------------------------------------ #
    # State transitions                                                    #
    # ------------------------------------------------------------------ #

    def transition(
        self, task_id: str, new_state: str, **extra_fields: Any
    ) -> dict[str, Any]:
        """Transition task to new_state, updating extra_fields atomically."""
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
    # Correction logic                                                     #
    # ------------------------------------------------------------------ #

    def begin_correction(
        self, task_id: str, findings: str = ""
    ) -> int:
        """Increment correction_count (inside transaction) before spawning.

        Returns new correction_count. Raises MaxCorrectionsError if exhausted.
        Must be called inside an existing transaction or starts one internally.

        The state is set to 'correcting' with findings stored, but NOT to
        'implementing' — the caller transitions to 'implementing' after spawn.
        """
        with self._store.transaction():
            task = self._store.fetchone("SELECT * FROM tasks WHERE id=?", (task_id,))
            if task is None:
                raise KeyError(f"Task {task_id!r} not found")
            count = task["correction_count"]
            if count >= MAX_CORRECTIONS:
                self._update(task_id, state="awaiting-human", review_findings=findings)
                raise MaxCorrectionsError(
                    f"Task {task_id!r} has exhausted {MAX_CORRECTIONS} corrections; "
                    "moved to awaiting-human"
                )
            new_count = count + 1
            self._update(
                task_id,
                correction_count=new_count,
                state="correcting",
                review_findings=findings,
            )
        return new_count

    def validate_reviewer_differs(self, task: dict[str, Any], reviewer_adapter: str) -> None:
        """Raise ReviewerConflictError if reviewer == writer."""
        writer = task.get("writer_adapter") or ""
        if writer and writer == reviewer_adapter:
            raise ReviewerConflictError(
                f"Reviewer adapter {reviewer_adapter!r} must differ from writer {writer!r}"
            )

    def check_base_sha_valid(self, task: dict[str, Any], current_base_sha: str) -> None:
        """Raise SpecChangedError if base SHA has advanced beyond task's base."""
        if task["base_sha"] != current_base_sha:
            raise SpecChangedError(
                f"Base SHA changed: task has {task['base_sha']!r}, "
                f"current is {current_base_sha!r}; review invalidated"
            )

    def recover_to_awaiting_human(
        self, task_id: str, actor: str, reason: str
    ) -> dict[str, Any]:
        """Move task to awaiting-human for operator attention. Does NOT reset counts."""
        with self._store.transaction():
            task = self._store.fetchone("SELECT * FROM tasks WHERE id=?", (task_id,))
            if task is None:
                raise KeyError(f"Task {task_id!r} not found")
            self._update(task_id, state="awaiting-human", review_findings=reason)
            self._store.execute(
                """
                INSERT INTO audit_log(ts, task_id, action, actor, detail)
                VALUES(?,?,'recover',?,?)
                """,
                (_iso_now(), task_id, actor, reason),
            )
        return self.get(task_id)
