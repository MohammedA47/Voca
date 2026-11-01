"""ApprovalRecord -- validate and persist operator-granted approvals.

Two gates:
  * step='spec'       -- binds all task parameters via canonical spec
  * step='execution'  -- explicit typed acknowledgement with digest

The canonical full spec JSON is persisted in the DB.  A changed spec
invalidates execution approval.  granted_by is always derived from the
local machine identity -- never from issue content or --owner-id flags.
"""
from __future__ import annotations

import datetime
import getpass
import hashlib
import socket
from typing import Any

from .db import SQLiteStore
from .errors import ApprovalGateError, InvalidApprovalError, SpecChangedError
from .spec import CanonicalSpec

VALID_STEPS = ("spec", "execution")


def _local_identity() -> str:
    return f"{getpass.getuser()}@{socket.gethostname()}"


def compute_digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _iso_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


class ApprovalRecord:
    """Manages approval persistence and validation for a single task."""

    def __init__(self, store: SQLiteStore, task_id: str) -> None:
        self._store = store
        self._task_id = task_id

    def grant_spec(self, spec: CanonicalSpec) -> dict[str, str]:
        """Persist spec approval with full canonical content.

        If the spec digest differs from a previous spec approval,
        any existing execution approval is invalidated.
        """
        if spec.task_id != self._task_id:
            raise InvalidApprovalError(
                f"Spec task_id {spec.task_id!r} != record task_id {self._task_id!r}"
            )
        spec_json = spec.canonical_json()
        spec_digest = spec.digest()
        accept_digest = compute_digest(spec.acceptance_text)
        granted_by = _local_identity()
        granted_at = _iso_now()

        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT spec_digest FROM approvals WHERE task_id=? AND step='spec'",
                (self._task_id,),
            )
            if existing and existing["spec_digest"] != spec_digest:
                # Spec changed -- invalidate execution + review/CI evidence
                self._store.execute(
                    "DELETE FROM approvals WHERE task_id=? AND step='execution'",
                    (self._task_id,),
                )
                # Clear candidate_sha to invalidate review
                self._store.execute(
                    "UPDATE tasks SET candidate_sha=NULL, reviewer_adapter=NULL "
                    "WHERE id=?",
                    (self._task_id,),
                )

            self._store.execute(
                """INSERT OR REPLACE INTO approvals
                   (task_id, step, granted_at, granted_by,
                    spec_digest, accept_digest, spec_content)
                   VALUES (?,?,?,?,?,?,?)""",
                (
                    self._task_id, "spec", granted_at, granted_by,
                    spec_digest, accept_digest, spec_json,
                ),
            )

        return {
            "task_id": self._task_id,
            "step": "spec",
            "granted_at": granted_at,
            "granted_by": granted_by,
            "spec_digest": spec_digest,
            "accept_digest": accept_digest,
        }

    def grant_execution(self, spec: CanonicalSpec, typed_digest: str) -> dict[str, str]:
        """Persist execution approval with typed digest verification.

        The operator must supply the digest they are acknowledging.
        """
        spec_digest = spec.digest()
        if typed_digest != spec_digest:
            raise InvalidApprovalError(
                f"Typed digest does not match spec: "
                f"{typed_digest[:16]}... != {spec_digest[:16]}..."
            )
        accept_digest = compute_digest(spec.acceptance_text)
        granted_by = _local_identity()
        granted_at = _iso_now()

        with self._store.transaction():
            spec_approval = self._store.fetchone(
                "SELECT spec_digest FROM approvals WHERE task_id=? AND step='spec'",
                (self._task_id,),
            )
            if spec_approval is None:
                raise ApprovalGateError(
                    "Must grant 'spec' approval before 'execution'"
                )
            if spec_approval["spec_digest"] != spec_digest:
                raise SpecChangedError(
                    "Spec has changed since spec approval; re-approve 'spec' first"
                )

            self._store.execute(
                """INSERT OR REPLACE INTO approvals
                   (task_id, step, granted_at, granted_by,
                    spec_digest, accept_digest, spec_content)
                   VALUES (?,?,?,?,?,?,?)""",
                (
                    self._task_id, "execution", granted_at, granted_by,
                    spec_digest, accept_digest, spec.canonical_json(),
                ),
            )

        return {
            "task_id": self._task_id,
            "step": "execution",
            "granted_at": granted_at,
            "granted_by": granted_by,
            "spec_digest": spec_digest,
        }

    # -- legacy grant for simpler test usage --
    def grant(
        self, step: str, spec_text: str, accept_text: str,
    ) -> dict[str, str]:
        """Legacy grant that takes raw text.  Builds a minimal CanonicalSpec."""
        if step not in VALID_STEPS:
            raise InvalidApprovalError(f"Unknown approval step {step!r}")
        if not spec_text.strip():
            raise InvalidApprovalError("spec_text must not be empty")
        if not accept_text.strip():
            raise InvalidApprovalError("accept_text must not be empty")

        spec_digest = compute_digest(spec_text)
        accept_digest = compute_digest(accept_text)
        granted_by = _local_identity()
        granted_at = _iso_now()

        with self._store.transaction():
            if step == "execution":
                prev = self._store.fetchone(
                    "SELECT spec_digest FROM approvals WHERE task_id=? AND step='spec'",
                    (self._task_id,),
                )
                if prev is None:
                    raise ApprovalGateError(
                        "Must grant 'spec' approval before 'execution'"
                    )
                if prev["spec_digest"] != spec_digest:
                    raise SpecChangedError(
                        "Spec text digest does not match previously approved spec"
                    )

            self._store.execute(
                """INSERT OR REPLACE INTO approvals
                   (task_id, step, granted_at, granted_by,
                    spec_digest, accept_digest, spec_content)
                   VALUES (?,?,?,?,?,?,?)""",
                (
                    self._task_id, step, granted_at, granted_by,
                    spec_digest, accept_digest, spec_text,
                ),
            )

        return {
            "task_id": self._task_id,
            "step": step,
            "granted_at": granted_at,
            "granted_by": granted_by,
            "spec_digest": spec_digest,
            "accept_digest": accept_digest,
        }

    def require(self, step: str, current_spec_digest: str) -> dict[str, Any]:
        """Return approval record or raise.  Validates digest match."""
        row = self._store.fetchone(
            "SELECT * FROM approvals WHERE task_id=? AND step=?",
            (self._task_id, step),
        )
        if row is None:
            raise ApprovalGateError(
                f"Required approval step {step!r} not granted for task {self._task_id!r}"
            )
        if row["spec_digest"] != current_spec_digest:
            raise SpecChangedError(
                f"Spec changed since {step!r} approval; re-approve required"
            )
        return row

    def get(self, step: str) -> dict[str, Any] | None:
        return self._store.fetchone(
            "SELECT * FROM approvals WHERE task_id=? AND step=?",
            (self._task_id, step),
        )

    def get_spec_content(self) -> str | None:
        """Return the persisted canonical spec JSON, or None."""
        row = self._store.fetchone(
            "SELECT spec_content FROM approvals WHERE task_id=? AND step='spec'",
            (self._task_id,),
        )
        return row["spec_content"] if row else None

    def invalidate_execution(self) -> None:
        """Remove execution approval (called when spec changes)."""
        with self._store.transaction():
            self._store.execute(
                "DELETE FROM approvals WHERE task_id=? AND step='execution'",
                (self._task_id,),
            )
