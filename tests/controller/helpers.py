"""Shared test helpers for voca_controller tests (stdlib only, no pytest)."""
from __future__ import annotations

import os
import tempfile
from pathlib import Path

from voca_controller.db import SQLiteStore


def make_store(tmp_dir: Path | None = None) -> tuple[SQLiteStore, Path]:
    """Create and open a fresh SQLiteStore in a temp directory."""
    if tmp_dir is None:
        tmp_dir = Path(tempfile.mkdtemp())
    db_path = tmp_dir / "test_controller.db"
    store = SQLiteStore(db_path)
    store.open()
    return store, tmp_dir


def make_git_repo(tmp_dir: Path) -> Path:
    """Create a minimal local git repo for scope/git tests. Uses fixed user config."""
    import subprocess
    repo = tmp_dir / "repo"
    repo.mkdir()
    subprocess.run(
        ["git", "-c", "user.email=test@test", "-c", "user.name=Test", "init", str(repo)],
        check=True, capture_output=True,
    )
    subprocess.run(
        ["git", "-c", "user.email=test@test", "-c", "user.name=Test",
         "-C", str(repo), "commit", "--allow-empty", "-m", "init"],
        check=True, capture_output=True,
    )
    return repo


SAMPLE_TASK = dict(
    task_id="task-001",
    repo_name="MohammedA47/Voca",
    repo_id="1219099434",
    issue_number=3,
    base_sha="abc123",
    branch="automation/voca-local-controller",
    spec_digest="a" * 64,
    accept_digest="b" * 64,
    authorized_scope="tools/voca_controller\ntests/controller",
    authorized_roles="implementer,reviewer",
)
