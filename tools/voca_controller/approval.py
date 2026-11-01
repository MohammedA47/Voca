"""ApprovalRecord — validate and persist operator-granted approvals.

Two separate gates must be granted by the local operator:
  • step='spec'      — binds repo, issue, branch, base_sha, spec/accept text
  • step='execution' — explicit execution acknowledgement (requires prior spec)

The canonical approved spec is persisted (via its digest) in the DB; a changed
spec invalidates the execution gate. granted_by is always derived from the local
machine identity — never from issue content or --owner-id flags.
"""
from __future__ import annotations

import datetime
import getpass
import hashlib
import socket
from typing import Any

from .db import SQLiteStore
from .errors import ApprovalGateError, InvalidApprovalError, SpecChangedError

VOCA_REPO_NAME = "MohammedA47/Voca"
VOCA_REPO_ID = "1219099434"

_REQUIRED_APPROVAL_FIELDS = (
    "task_id",
    "step",
    "spec_digest",
    "accept_digest",
)

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

    def grant(
        self,
        step: str,
        spec_text: str,
        accept_text: str,
    ) -> dict[str, str]:
        """Persist an approval grant. Returns the stored record.

        The spec_digest and accept_digest are computed from the supplied text —
        never trusted from an external source.

        If step='execution' and the stored spec digest has changed since the
        spec approval, raises SpecChangedError.
        """
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
                        "Spec text digest does not match previously approved spec; "
                        "re-approve 'spec' first"
                    )

            self._store.execute(
                """
                INSERT OR REPLACE INTO approvals
                    (task_id, step, granted_at, granted_by, spec_digest, accept_digest)
                VALUES (?,?,?,?,?,?)
                """,
                (
                    self._task_id,
                    step,
                    granted_at,
                    granted_by,
                    spec_digest,
                    accept_digest,
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
        """Return approval record or raise ApprovalGateError.

        Also raises SpecChangedError if spec_digest has changed since approval.
        """
        row = self._store.fetchone(
            "SELECT * FROM approvals WHERE task_id=? AND step=?",
            (self._task_id, step),
        )
        if row is None:
            raise ApprovalGateError(
                f"Required approval step {step!r} has not been granted for task {self._task_id!r}"
            )
        if row["spec_digest"] != current_spec_digest:
            raise SpecChangedError(
                f"Spec changed since {step!r} approval was granted; re-approve required"
            )
        return row

    def get(self, step: str) -> dict[str, Any] | None:
        return self._store.fetchone(
            "SELECT * FROM approvals WHERE task_id=? AND step=?",
            (self._task_id, step),
        )

    def invalidate_execution(self) -> None:
        """Remove execution approval (called when spec changes)."""
        with self._store.transaction():
            self._store.execute(
                "DELETE FROM approvals WHERE task_id=? AND step='execution'",
                (self._task_id,),
            )
