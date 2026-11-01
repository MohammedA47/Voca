"""CrashReconciler — safe fail-closed crash recovery on startup.

On every startup (before lease acquisition):
  1. Query op_ledger for outcome='uncertain' entries.
  2. For each: check if recorded PID+PGID is still alive.
  3. If alive → cannot acquire lease; exit 3 (UncertainOpBlocksError).
  4. If dead → mark 'crashed-unobserved'; move task to 'awaiting-human'.
  5. Only after all uncertain ops resolved → lease acquisition may proceed.

Conservative principles:
- No automatic takeover of live processes.
- No blind retry after uncertain state.
- If we cannot determine liveness, fail closed (treat as live).
"""
from __future__ import annotations

import os
from typing import Any

from .db import SQLiteStore
from .errors import UncertainOpBlocksError
from .task import TaskManager


def _pid_alive(pid: int) -> bool:
    """True if process is alive (POSIX; darwin + linux)."""
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # alive but we lack signal permission


def _pgid_matches(pid: int, expected_pgid: int) -> bool:
    try:
        return os.getpgid(pid) == expected_pgid
    except (ProcessLookupError, OSError):
        return False


class CrashReconciler:
    def __init__(self, store: SQLiteStore) -> None:
        self._store = store
        self._task_mgr = TaskManager(store)

    def reconcile(self, *, dry_run: bool = True) -> list[dict[str, Any]]:
        """Check uncertain ops and resolve dead ones.

        Returns list of actions taken (or that would be taken in dry_run).
        Raises UncertainOpBlocksError if any live uncertain op exists.
        """
        uncertain = self._store.fetchall(
            "SELECT * FROM op_ledger WHERE outcome='uncertain'"
        )
        actions: list[dict[str, Any]] = []
        live_blocking: list[dict[str, Any]] = []

        for op in uncertain:
            pid = op.get("pid")
            pgid = op.get("pgid")
            op_id = op["op_id"]
            task_id = op["task_id"]

            if pid is not None and _pid_alive(pid):
                if pgid is not None and _pgid_matches(pid, pgid):
                    live_blocking.append(op)
                    actions.append({
                        "op_id": op_id,
                        "task_id": task_id,
                        "action": "live-blocking",
                        "pid": pid,
                        "pgid": pgid,
                    })
                    continue
            # Dead or unverifiable — mark crashed
            action = {
                "op_id": op_id,
                "task_id": task_id,
                "action": "crashed-unobserved",
                "pid": pid,
                "pgid": pgid,
            }
            actions.append(action)
            if not dry_run:
                self._mark_crashed(op_id, task_id)

        if live_blocking:
            raise UncertainOpBlocksError(
                f"{len(live_blocking)} uncertain supervised ops have live processes; "
                "cannot acquire lease. Verify manually then re-run reconcile."
            )
        return actions

    def _mark_crashed(self, op_id: str, task_id: str) -> None:
        import datetime
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with self._store.transaction():
            self._store.execute(
                "UPDATE op_ledger SET outcome='crashed-unobserved', ended_at=? WHERE op_id=?",
                (now, op_id),
            )
            task = self._store.fetchone("SELECT state FROM tasks WHERE id=?", (task_id,))
            if task and task["state"] not in ("awaiting-human",):
                self._store.execute(
                    "UPDATE tasks SET state='awaiting-human', updated_at=? WHERE id=?",
                    (now, task_id),
                )
                self._store.execute(
                    """
                    INSERT INTO audit_log(ts, task_id, action, actor, detail)
                    VALUES(?,?,'reconcile-crash','controller',?)
                    """,
                    (now, task_id, f"op {op_id} crashed-unobserved"),
                )
