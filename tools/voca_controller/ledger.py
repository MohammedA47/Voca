"""ExternalOpLedger -- record and observe supervised operations.

Every adapter launch is recorded BEFORE Popen (outcome='uncertain').
External supervised mutations (e.g. GitHub push) use the external_ops table
with planned/uncertain/observed lifecycle.

Rules:
- Duplicate op_id with different payload is rejected.
- Uncertain ops block lease takeover.
- External ops: same key + different payload digest rejects; uncertain
  outcomes block retry; observations labeled operator-attested or API-observed.
"""
from __future__ import annotations

import datetime
import hashlib
from typing import Any

from .db import SQLiteStore
from .errors import InfraRetryExhaustedError, UncertainOpBlocksError

_FINAL_OUTCOMES = frozenset(
    {"success", "failure", "rejected", "timeout-killed",
     "crashed-unobserved", "auth-failure", "spawn-failed"}
)

_EXTERNAL_FINAL = frozenset(
    {"observed-succeeded", "observed-absent", "observed-failed", "cancelled"}
)


def _iso_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _payload_digest(kind: str, adapter: str, task_id: str) -> str:
    return hashlib.sha256(f"{kind}:{adapter}:{task_id}".encode()).hexdigest()


class ExternalOpLedger:
    def __init__(self, store: SQLiteStore) -> None:
        self._store = store

    # ------------------------------------------------------------------ #
    # Adapter op lifecycle                                                 #
    # ------------------------------------------------------------------ #

    def record_start(
        self,
        *,
        op_id: str,
        task_id: str,
        kind: str,
        adapter: str,
        pid: int | None = None,
        pgid: int | None = None,
        start_identity: str | None = None,
        fencing_token: int | None = None,
        model_requested: str | None = None,
    ) -> None:
        """Record BEFORE Popen.  outcome='uncertain'."""
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT op_id, kind, adapter, task_id FROM op_ledger WHERE op_id=?",
                (op_id,),
            )
            if existing is not None:
                ed = _payload_digest(existing["kind"], existing["adapter"], existing["task_id"])
                nd = _payload_digest(kind, adapter, task_id)
                if ed != nd:
                    raise ValueError(
                        f"Duplicate op_id {op_id!r} with different payload"
                    )
                return  # idempotent

            self._store.execute(
                """INSERT INTO op_ledger(
                    op_id, task_id, kind, adapter, pid, pgid, start_identity,
                    fencing_token, started_at, outcome, model_requested
                ) VALUES(?,?,?,?,?,?,?,?,?,'uncertain',?)""",
                (op_id, task_id, kind, adapter, pid, pgid, start_identity,
                 fencing_token, _iso_now(), model_requested),
            )

    def update_pid(
        self, op_id: str, pid: int, pgid: int, start_identity: str,
    ) -> None:
        """Update PID/PGID after successful Popen."""
        with self._store.transaction():
            self._store.execute(
                "UPDATE op_ledger SET pid=?, pgid=?, start_identity=? WHERE op_id=?",
                (pid, pgid, start_identity, op_id),
            )

    def record_end(
        self,
        op_id: str,
        outcome: str,
        notes: str | None = None,
        model_reported: str | None = None,
    ) -> None:
        if outcome not in _FINAL_OUTCOMES:
            raise ValueError(f"Unknown outcome {outcome!r}")
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT outcome FROM op_ledger WHERE op_id=?", (op_id,)
            )
            if existing is None:
                raise KeyError(f"op_id {op_id!r} not found in ledger")
            if existing["outcome"] in _FINAL_OUTCOMES:
                return  # already final
            self._store.execute(
                "UPDATE op_ledger SET outcome=?, ended_at=?, notes=?, model_reported=? "
                "WHERE op_id=?",
                (outcome, _iso_now(), notes, model_reported, op_id),
            )

    def get_uncertain(self) -> list[dict[str, Any]]:
        return self._store.fetchall(
            "SELECT * FROM op_ledger WHERE outcome='uncertain'"
        )

    def get(self, op_id: str) -> dict[str, Any] | None:
        return self._store.fetchone(
            "SELECT * FROM op_ledger WHERE op_id=?", (op_id,)
        )

    # ------------------------------------------------------------------ #
    # External supervised operations                                       #
    # ------------------------------------------------------------------ #

    def plan_external(
        self, op_key: str, task_id: str, kind: str, payload: str,
    ) -> None:
        """Record a planned external operation.

        Same key + same payload digest is idempotent.
        Same key + different payload digest raises ValueError.
        """
        digest = hashlib.sha256(payload.encode()).hexdigest()
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT payload_digest, outcome FROM external_ops WHERE op_key=?",
                (op_key,),
            )
            if existing is not None:
                if existing["payload_digest"] != digest:
                    raise ValueError(
                        f"External op {op_key!r}: payload changed "
                        f"({existing['payload_digest'][:16]}... != {digest[:16]}...)"
                    )
                return  # idempotent
            self._store.execute(
                """INSERT INTO external_ops
                   (op_key, task_id, kind, payload_digest, outcome, created_at)
                   VALUES (?,?,?,?,'planned',?)""",
                (op_key, task_id, kind, digest, _iso_now()),
            )

    def observe_external(
        self, op_key: str, outcome: str, attestation: str,
    ) -> None:
        """Record an observation for an external op.

        outcome must be in _EXTERNAL_FINAL.
        attestation describes the source (e.g. 'operator-attested', 'api-observed').
        """
        if outcome not in _EXTERNAL_FINAL:
            raise ValueError(f"Invalid external outcome {outcome!r}")
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT outcome FROM external_ops WHERE op_key=?", (op_key,)
            )
            if existing is None:
                raise KeyError(f"External op {op_key!r} not found")
            if existing["outcome"] in _EXTERNAL_FINAL:
                return  # already observed
            self._store.execute(
                "UPDATE external_ops SET outcome=?, attestation=?, observed_at=? "
                "WHERE op_key=?",
                (outcome, attestation, _iso_now(), op_key),
            )

    def get_external(self, op_key: str) -> dict[str, Any] | None:
        return self._store.fetchone(
            "SELECT * FROM external_ops WHERE op_key=?", (op_key,)
        )

    def has_uncertain_external(self, task_id: str) -> bool:
        """True if task has any external ops in non-final state."""
        row = self._store.fetchone(
            "SELECT COUNT(*) AS c FROM external_ops "
            "WHERE task_id=? AND outcome NOT IN ('observed-succeeded','observed-absent','observed-failed','cancelled')",
            (task_id,),
        )
        return (row["c"] if row else 0) > 0
