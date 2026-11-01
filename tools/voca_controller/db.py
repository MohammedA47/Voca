"""SQLiteStore -- all schema and low-level DB access.

All writes use BEGIN IMMEDIATE for serialisation.  isolation_level=None means
Python's sqlite3 does NOT issue implicit BEGIN; we manage transactions manually.

Transaction nesting is explicitly prevented via ``_in_txn`` tracking.
"""
from __future__ import annotations

import sqlite3
import threading
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Generator

_SCHEMA_STMTS = [
    "CREATE TABLE IF NOT EXISTS projects (key TEXT PRIMARY KEY, content TEXT NOT NULL)",
    """CREATE TABLE IF NOT EXISTS meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
    )""",
    """CREATE TABLE IF NOT EXISTS fencing_sequence (
        id         INTEGER PRIMARY KEY CHECK (id = 1),
        next_token INTEGER NOT NULL DEFAULT 1
    )""",
    """CREATE TABLE IF NOT EXISTS leases (
        id               INTEGER PRIMARY KEY CHECK (id = 1),
        holder_pid       INTEGER NOT NULL,
        holder_pgid      INTEGER NOT NULL,
        holder_host      TEXT NOT NULL,
        holder_cmdline   TEXT NOT NULL,
        start_identity   TEXT NOT NULL,
        acquired_at      TEXT NOT NULL,
        fencing_token    INTEGER NOT NULL
    )""",
    """CREATE TABLE IF NOT EXISTS tasks (
        id               TEXT PRIMARY KEY,
        repo_name        TEXT NOT NULL,
        repo_id          TEXT NOT NULL,
        issue_number     INTEGER NOT NULL,
        base_sha         TEXT NOT NULL,
        branch           TEXT NOT NULL,
        spec_digest      TEXT NOT NULL,
        accept_digest    TEXT NOT NULL,
        authorized_scope TEXT NOT NULL,
        authorized_roles TEXT NOT NULL,
        state            TEXT NOT NULL DEFAULT 'idle',
        correction_count INTEGER NOT NULL DEFAULT 0,
        candidate_sha    TEXT,
        writer_adapter   TEXT,
        reviewer_adapter TEXT,
        review_findings  TEXT,
        complexity       TEXT NOT NULL DEFAULT 'routine',
        controller_data  TEXT NOT NULL DEFAULT '{}',
        created_at       TEXT NOT NULL,
        updated_at       TEXT NOT NULL
    )""",
    """CREATE TABLE IF NOT EXISTS approvals (
        task_id       TEXT NOT NULL,
        step          TEXT NOT NULL,
        granted_at    TEXT NOT NULL,
        granted_by    TEXT NOT NULL,
        spec_digest   TEXT NOT NULL,
        accept_digest TEXT NOT NULL,
        spec_content  TEXT,
        PRIMARY KEY (task_id, step)
    )""",
    """CREATE TABLE IF NOT EXISTS op_ledger (
        op_id           TEXT PRIMARY KEY,
        task_id         TEXT NOT NULL,
        kind            TEXT NOT NULL,
        adapter         TEXT NOT NULL,
        pid             INTEGER,
        pgid            INTEGER,
        start_identity  TEXT,
        fencing_token   INTEGER,
        started_at      TEXT NOT NULL,
        ended_at        TEXT,
        outcome         TEXT NOT NULL DEFAULT 'uncertain',
        notes           TEXT,
        model_requested TEXT,
        model_reported  TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS infra_budget (
        task_id  TEXT NOT NULL,
        phase    TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (task_id, phase)
    )""",
    """CREATE TABLE IF NOT EXISTS routing_selections (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id         TEXT NOT NULL,
        role            TEXT NOT NULL,
        run_ordinal     INTEGER NOT NULL,
        profile_name    TEXT NOT NULL,
        provider        TEXT NOT NULL,
        model           TEXT NOT NULL,
        effort          TEXT NOT NULL,
        catalog_version INTEGER NOT NULL,
        rationale       TEXT NOT NULL,
        escalated_from  TEXT,
        created_at      TEXT NOT NULL
    )""",
    """CREATE TABLE IF NOT EXISTS external_ops (
        op_key         TEXT PRIMARY KEY,
        task_id        TEXT NOT NULL,
        kind           TEXT NOT NULL,
        payload_digest TEXT NOT NULL,
        outcome        TEXT NOT NULL DEFAULT 'planned',
        attestation    TEXT,
        created_at     TEXT NOT NULL,
        observed_at    TEXT
    )""",
    """CREATE TABLE IF NOT EXISTS audit_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        ts         TEXT NOT NULL,
        task_id    TEXT,
        action     TEXT NOT NULL,
        actor      TEXT NOT NULL,
        detail     TEXT
    )""",
]


class SQLiteStore:
    """Thin wrapper around sqlite3 with explicit transaction management."""

    def __init__(self, db_path: Path) -> None:
        self.db_path = db_path
        self._conn: sqlite3.Connection | None = None
        self._in_txn: bool = False
        self._readonly: bool = False
        self._mutex = threading.RLock()

    # ------------------------------------------------------------------ #
    # Open / close                                                         #
    # ------------------------------------------------------------------ #

    def open(self) -> None:
        """Open (or create) the database in read-write mode and apply schema."""
        self._conn = sqlite3.connect(
            str(self.db_path),
            isolation_level=None,
            check_same_thread=False,
        )
        self._conn.row_factory = sqlite3.Row
        version = self._conn.execute("PRAGMA user_version").fetchone()[0]
        exists = self._conn.execute("SELECT 1 FROM sqlite_master WHERE name='tasks'").fetchone()
        if exists and version != 2:
            self.close()
            raise RuntimeError("Unvalidated legacy database: manual migration required; history was not reset")
        self._conn.execute("PRAGMA journal_mode=DELETE")
        self._conn.execute("PRAGMA foreign_keys=ON")
        for stmt in _SCHEMA_STMTS:
            self._conn.execute(stmt)
        self._conn.execute(
            "INSERT OR IGNORE INTO fencing_sequence(id, next_token) VALUES(1, 1)"
        )
        self._conn.execute("PRAGMA user_version=2")
        self._readonly = False

    def open_readonly(self) -> None:
        """Open in read-only mode via SQLite URI.  No schema writes."""
        if not self.db_path.exists():
            raise FileNotFoundError(f"DB not found: {self.db_path}")
        uri = self.db_path.resolve().as_uri() + "?mode=ro"
        self._conn = sqlite3.connect(
            uri,
            uri=True,
            isolation_level=None,
            check_same_thread=False,
        )
        self._conn.row_factory = sqlite3.Row
        self._readonly = True

    def close(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None
            self._in_txn = False

    @property
    def readonly(self) -> bool:
        return self._readonly

    # ------------------------------------------------------------------ #
    # Transactions                                                         #
    # ------------------------------------------------------------------ #

    @contextmanager
    def transaction(self) -> Generator[sqlite3.Connection, None, None]:
        """Context manager for BEGIN IMMEDIATE.  Nesting is rejected."""
        with self._mutex:
            with self._transaction_unlocked() as conn:
                yield conn

    @contextmanager
    def _transaction_unlocked(self):
        assert self._conn is not None, "Store not open"
        if self._readonly:
            raise RuntimeError("Cannot start transaction on read-only store")
        if self._in_txn:
            raise RuntimeError(
                "Cannot nest transactions; already inside BEGIN IMMEDIATE"
            )
        self._conn.execute("BEGIN IMMEDIATE")
        self._in_txn = True
        try:
            yield self._conn
            self._conn.execute("COMMIT")
        except Exception:
            try:
                self._conn.execute("ROLLBACK")
            except Exception:
                pass
            raise
        finally:
            self._in_txn = False

    # ------------------------------------------------------------------ #
    # Fencing sequence                                                     #
    # ------------------------------------------------------------------ #

    def next_fencing_token(self) -> int:
        """Consume and return the next fencing token.  Must be inside transaction."""
        assert self._conn is not None
        if not self._in_txn:
            raise RuntimeError("next_fencing_token requires an active transaction")
        row = self._conn.execute(
            "SELECT next_token FROM fencing_sequence WHERE id=1"
        ).fetchone()
        token = row[0]
        self._conn.execute(
            "UPDATE fencing_sequence SET next_token=? WHERE id=1", (token + 1,)
        )
        return token

    # ------------------------------------------------------------------ #
    # Generic helpers                                                      #
    # ------------------------------------------------------------------ #

    def execute(self, sql: str, params: tuple = ()) -> sqlite3.Cursor:
        assert self._conn is not None
        return self._conn.execute(sql, params)

    def fetchone(self, sql: str, params: tuple = ()) -> dict[str, Any] | None:
        assert self._conn is not None
        row = self._conn.execute(sql, params).fetchone()
        return dict(row) if row is not None else None

    def fetchall(self, sql: str, params: tuple = ()) -> list[dict[str, Any]]:
        assert self._conn is not None
        rows = self._conn.execute(sql, params).fetchall()
        return [dict(r) for r in rows]
