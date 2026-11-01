"""ExternalOpLedger — record and observe supervised external operations.

Every adapter launch is recorded BEFORE Popen:
  1. record_start() → outcome='uncertain'
  2. Popen happens
  3. On completion: record_end()

Rules:
- Duplicate op_id with different payload is rejected.
- Uncertain ops block lease takeover (checked in lease.py).
- Infra retries: max 2 for transient errors; auth failures → 0 retries.
- Operations in 'uncertain' state can only be reconciled by CrashReconciler
  or explicit observation — never auto-retried.
"""
from __future__ import annotations

import datetime
import hashlib
from typing import Any

from .db import SQLiteStore
from .errors import InfraRetryExhaustedError

MAX_INFRA_RETRIES = 2

_FINAL_OUTCOMES = frozenset(
    {"success", "failure", "rejected", "timeout-killed", "crashed-unobserved",
     "auth-failure", "spawn-failed"}
)


def _iso_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _payload_digest(kind: str, adapter: str, task_id: str) -> str:
    return hashlib.sha256(f"{kind}:{adapter}:{task_id}".encode()).hexdigest()


class ExternalOpLedger:
    def __init__(self, store: SQLiteStore) -> None:
        self._store = store

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
    ) -> None:
        """Record an operation start BEFORE Popen. outcome='uncertain'."""
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT op_id, kind, adapter, task_id FROM op_ledger WHERE op_id=?",
                (op_id,),
            )
            if existing is not None:
                existing_digest = _payload_digest(
                    existing["kind"], existing["adapter"], existing["task_id"]
                )
                new_digest = _payload_digest(kind, adapter, task_id)
                if existing_digest != new_digest:
                    raise ValueError(
                        f"Duplicate op_id {op_id!r} with different payload rejected"
                    )
                return  # idempotent same-payload re-record

            self._store.execute(
                """
                INSERT INTO op_ledger(
                    op_id, task_id, kind, adapter, pid, pgid, start_identity,
                    started_at, outcome
                ) VALUES(?,?,?,?,?,?,?,?,'uncertain')
                """,
                (op_id, task_id, kind, adapter, pid, pgid, start_identity, _iso_now()),
            )

    def record_end(
        self,
        op_id: str,
        outcome: str,
        notes: str | None = None,
    ) -> None:
        """Update outcome for a recorded operation."""
        if outcome not in _FINAL_OUTCOMES:
            raise ValueError(f"Unknown outcome {outcome!r}")
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT outcome FROM op_ledger WHERE op_id=?", (op_id,)
            )
            if existing is None:
                raise KeyError(f"op_id {op_id!r} not found in ledger")
            if existing["outcome"] in _FINAL_OUTCOMES:
                return  # already finalised; idempotent
            self._store.execute(
                "UPDATE op_ledger SET outcome=?, ended_at=?, notes=? WHERE op_id=?",
                (outcome, _iso_now(), notes, op_id),
            )

    def get_uncertain(self) -> list[dict[str, Any]]:
        return self._store.fetchall(
            "SELECT * FROM op_ledger WHERE outcome='uncertain'"
        )

    def get(self, op_id: str) -> dict[str, Any] | None:
        return self._store.fetchone(
            "SELECT * FROM op_ledger WHERE op_id=?", (op_id,)
        )

    def increment_infra_retry(self, op_id: str, is_auth_failure: bool = False) -> int:
        """Increment infra retry count; raise if exhausted or auth failure."""
        if is_auth_failure:
            raise InfraRetryExhaustedError(
                f"Auth failure for op {op_id!r}; no infra retry allowed"
            )
        with self._store.transaction():
            row = self._store.fetchone(
                "SELECT count FROM infra_retries WHERE op_id=?", (op_id,)
            )
            current = row["count"] if row else 0
            if current >= MAX_INFRA_RETRIES:
                raise InfraRetryExhaustedError(
                    f"op {op_id!r} has exhausted {MAX_INFRA_RETRIES} infra retries"
                )
            new_count = current + 1
            if row:
                self._store.execute(
                    "UPDATE infra_retries SET count=? WHERE op_id=?",
                    (new_count, op_id),
                )
            else:
                self._store.execute(
                    "INSERT INTO infra_retries(op_id, count) VALUES(?,?)",
                    (op_id, new_count),
                )
        return new_count

    def get_infra_retry_count(self, op_id: str) -> int:
        row = self._store.fetchone(
            "SELECT count FROM infra_retries WHERE op_id=?", (op_id,)
        )
        return row["count"] if row else 0
