"""SQLiteStore — all schema and low-level DB access.

All writes use BEGIN IMMEDIATE for serialisation. isolation_level=None means
Python's sqlite3 does NOT issue implicit BEGIN; we manage transactions manually.
"""
from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Generator

_SCHEMA_STMTS = [
    """
    CREATE TABLE IF NOT EXISTS meta (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
    )
    """,
    # Monotonically increasing fencing counter — never resets even if leases row
    # is deleted.
    """
    CREATE TABLE IF NOT EXISTS fencing_sequence (
        id         INTEGER PRIMARY KEY CHECK (id = 1),
        next_token INTEGER NOT NULL DEFAULT 1
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS leases (
        id               INTEGER PRIMARY KEY CHECK (id = 1),
        holder_pid       INTEGER NOT NULL,
        holder_pgid      INTEGER NOT NULL,
        holder_host      TEXT NOT NULL,
        holder_cmdline   TEXT NOT NULL,
        start_identity   TEXT NOT NULL,
        acquired_at      TEXT NOT NULL,
        fencing_token    INTEGER NOT NULL
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS tasks (
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
        created_at       TEXT NOT NULL,
        updated_at       TEXT NOT NULL
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS approvals (
        task_id      TEXT NOT NULL,
        step         TEXT NOT NULL,
        granted_at   TEXT NOT NULL,
        granted_by   TEXT NOT NULL,
        spec_digest  TEXT NOT NULL,
        accept_digest TEXT NOT NULL,
        PRIMARY KEY (task_id, step)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS op_ledger (
        op_id          TEXT PRIMARY KEY,
        task_id        TEXT NOT NULL,
        kind           TEXT NOT NULL,
        adapter        TEXT NOT NULL,
        pid            INTEGER,
        pgid           INTEGER,
        start_identity TEXT,
        started_at     TEXT NOT NULL,
        ended_at       TEXT,
        outcome        TEXT NOT NULL DEFAULT 'uncertain',
        notes          TEXT
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS infra_retries (
        op_id TEXT PRIMARY KEY,
        count INTEGER NOT NULL DEFAULT 0
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS audit_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        ts         TEXT NOT NULL,
        task_id    TEXT,
        action     TEXT NOT NULL,
        actor      TEXT NOT NULL,
        detail     TEXT
    )
    """,
]


class SQLiteStore:
    def __init__(self, db_path: Path) -> None:
        self.db_path = db_path
        self._conn: sqlite3.Connection | None = None

    def open(self) -> None:
        self._conn = sqlite3.connect(
            str(self.db_path),
            isolation_level=None,  # manual transaction control
            check_same_thread=False,
        )
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA journal_mode=WAL")
        self._conn.execute("PRAGMA foreign_keys=ON")
        for stmt in _SCHEMA_STMTS:
            self._conn.execute(stmt)
        # Seed fencing counter if missing
        self._conn.execute(
            "INSERT OR IGNORE INTO fencing_sequence(id, next_token) VALUES(1, 1)"
        )

    def close(self) -> None:
        if self._conn is not None:
            self._conn.close()
            self._conn = None

    @contextmanager
    def transaction(self) -> Generator[sqlite3.Connection, None, None]:
        """Context manager that runs statements inside BEGIN IMMEDIATE."""
        assert self._conn is not None, "Store not open"
        self._conn.execute("BEGIN IMMEDIATE")
        try:
            yield self._conn
            self._conn.execute("COMMIT")
        except Exception:
            try:
                self._conn.execute("ROLLBACK")
            except Exception:
                pass
            raise

    # ------------------------------------------------------------------ #
    # Fencing sequence                                                     #
    # ------------------------------------------------------------------ #

    def next_fencing_token(self) -> int:
        """Consume and return next fencing token. Must be called inside transaction."""
        assert self._conn is not None
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
