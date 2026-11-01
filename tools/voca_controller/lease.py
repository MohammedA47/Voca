"""WriteLease — global single-writer lease via SQLite fencing counter.

Rules:
- Only one row ever exists in the leases table (id=1).
- Fencing token is monotonically incremented each acquisition; it never resets
  even when the row is deleted.
- A new process may only take over a dead holder's lease when there are no
  uncertain ops in the ledger (checked before acquire, inside the transaction).
- PID liveness: os.kill(pid, 0); PGID cross-check for anti-reuse guard.
"""
from __future__ import annotations

import os
import socket
import sys
import time

from .db import SQLiteStore
from .errors import LeaseHeldError, LeaseTokenMismatchError, UncertainOpBlocksError


def _current_identity() -> str:
    """Return a best-effort start identity string for the current process."""
    return f"pid={os.getpid()}:pgid={os.getpgrp()}:t={time.monotonic_ns()}"


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # exists but we can't signal — still alive


def _pgid_matches(pid: int, expected_pgid: int) -> bool:
    """Return True if pid's current pgid matches expected_pgid."""
    try:
        return os.getpgid(pid) == expected_pgid
    except (ProcessLookupError, PermissionError):
        return False


def _has_uncertain_ops(store: SQLiteStore) -> bool:
    row = store.fetchone(
        "SELECT COUNT(*) AS c FROM op_ledger WHERE outcome='uncertain'"
    )
    return (row["c"] if row else 0) > 0


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
        """Acquire the global write lease. Returns the fencing token.

        Raises:
            LeaseHeldError: if a live process holds the lease.
            UncertainOpBlocksError: if uncertain ops prevent takeover.
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
            existing = self._store.fetchone("SELECT * FROM leases WHERE id=1")
            if existing is not None:
                holder_pid = existing["holder_pid"]
                holder_pgid = existing["holder_pgid"]
                if _pid_alive(holder_pid) and _pgid_matches(holder_pid, holder_pgid):
                    raise LeaseHeldError(
                        f"Lease held by live pid={holder_pid} pgid={holder_pgid}"
                    )
                # Holder is dead — check uncertain ops before takeover
                if _has_uncertain_ops(self._store):
                    raise UncertainOpBlocksError(
                        "Cannot take over lease: uncertain supervised ops exist; "
                        "run 'reconcile' first"
                    )
                token = self._store.next_fencing_token()
                self._store.execute("DELETE FROM leases WHERE id=1")
            else:
                token = self._store.next_fencing_token()

            self._store.execute(
                """
                INSERT INTO leases(id, holder_pid, holder_pgid, holder_host,
                    holder_cmdline, start_identity, acquired_at, fencing_token)
                VALUES(1,?,?,?,?,?,?,?)
                """,
                (pid, pgid, host, cmdline, start_identity, now, token),
            )
        return token

    def release(self, fencing_token: int) -> None:
        """Release the lease, verified by fencing token."""
        with self._store.transaction():
            existing = self._store.fetchone("SELECT fencing_token FROM leases WHERE id=1")
            if existing is None:
                return  # already released
            if existing["fencing_token"] != fencing_token:
                raise LeaseTokenMismatchError(
                    f"Token {fencing_token} != stored {existing['fencing_token']}"
                )
            self._store.execute("DELETE FROM leases WHERE id=1")

    def current(self) -> dict | None:
        """Return current lease row or None."""
        return self._store.fetchone("SELECT * FROM leases WHERE id=1")


def _iso_now() -> str:
    import datetime
    return datetime.datetime.now(datetime.timezone.utc).isoformat()
