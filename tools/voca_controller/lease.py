"""WriteLease -- global single-writer lease via SQLite fencing counter.

Rules:
- Only one row ever exists in the leases table (id=1).
- Fencing token is monotonically incremented each acquisition; it never resets.
- A new process may only take over a dead holder's lease when there are no
  uncertain ops in the ledger.
- PID+PGID liveness cross-check for anti-reuse guard.
- Absent lease row does NOT make uncertain ops safe.
"""
from __future__ import annotations

import datetime
import os
import socket
import sys
import time

from .db import SQLiteStore
from .errors import LeaseHeldError, LeaseTokenMismatchError, UncertainOpBlocksError


def _current_identity() -> str:
    """Best-effort start identity for the current process."""
    return f"pid={os.getpid()}:pgid={os.getpgrp()}:t={time.monotonic_ns()}"


def _pid_alive(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # alive but we can't signal


def _pgid_matches(pid: int, expected_pgid: int) -> bool:
    try:
        return os.getpgid(pid) == expected_pgid
    except (ProcessLookupError, PermissionError):
        return False


def _has_uncertain_ops(store: SQLiteStore) -> bool:
    row = store.fetchone(
        "SELECT COUNT(*) AS c FROM op_ledger WHERE outcome='uncertain'"
    )
    return (row["c"] if row else 0) > 0


def _iso_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


class WriteLease:
    def __init__(self, store: SQLiteStore) -> None:
        self._store = store

    def acquire(
        self,
        pid: int | None = None,
        pgid: int | None = None,
        host: str | None = None,
        cmdline: str | None = None,
        start_identity: str | None = None,
    ) -> int:
        """Acquire the global write lease.  Returns fencing token.

        Raises LeaseHeldError if a live process holds the lease.
        Raises UncertainOpBlocksError if uncertain ops exist (even without
        a lease row -- absent lease does not make uncertain ops safe).
        """
        if pid is None:
            pid = os.getpid()
        if pgid is None:
            pgid = os.getpgrp()
        if host is None:
            host = socket.gethostname()
        if cmdline is None:
            cmdline = " ".join(sys.argv)
        if start_identity is None:
            start_identity = _current_identity()

        now = _iso_now()

        with self._store.transaction():
            # Check uncertain ops FIRST -- even if no lease row exists
            if _has_uncertain_ops(self._store):
                raise UncertainOpBlocksError(
                    "Cannot acquire lease: uncertain ops exist; run 'reconcile' first"
                )

            existing = self._store.fetchone("SELECT * FROM leases WHERE id=1")
            if existing is not None:
                holder_pid = existing["holder_pid"]
                holder_pgid = existing["holder_pgid"]
                if _pid_alive(holder_pid) and _pgid_matches(holder_pid, holder_pgid):
                    raise LeaseHeldError(
                        f"Lease held by live pid={holder_pid} pgid={holder_pgid}"
                    )
                # Holder is dead -- safe to take over (uncertain ops already checked)
                self._store.execute("DELETE FROM leases WHERE id=1")

            token = self._store.next_fencing_token()
            self._store.execute(
                """INSERT INTO leases(id, holder_pid, holder_pgid, holder_host,
                    holder_cmdline, start_identity, acquired_at, fencing_token)
                   VALUES(1,?,?,?,?,?,?,?)""",
                (pid, pgid, host, cmdline, start_identity, now, token),
            )
        return token

    def release(self, fencing_token: int) -> None:
        """Release the lease, verified by fencing token."""
        with self._store.transaction():
            existing = self._store.fetchone(
                "SELECT fencing_token FROM leases WHERE id=1"
            )
            if existing is None:
                return
            if existing["fencing_token"] != fencing_token:
                raise LeaseTokenMismatchError(
                    f"Token {fencing_token} != stored {existing['fencing_token']}"
                )
            self._store.execute("DELETE FROM leases WHERE id=1")

    def current(self) -> dict | None:
        return self._store.fetchone("SELECT * FROM leases WHERE id=1")
