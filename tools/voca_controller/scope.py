"""ScopeValidator — post-run file change enforcement.

After each adapter run we validate ALL changed files:
  • tracked changes: git diff HEAD --name-only (staged + unstaged)
  • untracked files: git ls-files --others --exclude-standard

Both sets must be within authorized_scope. Out-of-scope files trigger a
correcting transition; user's work is never deleted.

Symlink escapes are also detected by resolving paths relative to checkout root.
"""
from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Sequence

from .errors import ScopeViolationError
from .paths import assert_no_symlink_escape, is_within_scope


def _run_git(args: Sequence[str], cwd: Path) -> list[str]:
    """Run git with fixed argv (shell=False) and return non-empty output lines."""
    result = subprocess.run(
        ["git"] + list(args),
        cwd=str(cwd),
        capture_output=True,
        text=True,
        shell=False,
    )
    return [l.strip() for l in result.stdout.splitlines() if l.strip()]


def changed_files(checkout_root: Path) -> list[str]:
    """Return all changed (tracked dirty + untracked) file paths relative to checkout."""
    tracked = _run_git(["diff", "HEAD", "--name-only"], checkout_root)
    staged = _run_git(["diff", "--cached", "--name-only"], checkout_root)
    untracked = _run_git(
        ["ls-files", "--others", "--exclude-standard"], checkout_root
    )
    seen: set[str] = set()
    combined: list[str] = []
    for path in tracked + staged + untracked:
        if path not in seen:
            seen.add(path)
            combined.append(path)
    return combined


def validate_scope(
    checkout_root: Path,
    scope_prefixes: list[str],
    *,
    raise_on_violation: bool = True,
) -> list[str]:
    """Return list of out-of-scope file paths (empty means clean).

    If raise_on_violation=True and any violations exist, raises ScopeViolationError.
    Never deletes any files.
    """
    files = changed_files(checkout_root)
    violations: list[str] = []

    for path in files:
        if not is_within_scope(path, scope_prefixes):
            violations.append(path)
            continue
        # Symlink escape check for in-scope files
        try:
            assert_no_symlink_escape(path, checkout_root)
        except Exception as exc:
            violations.append(f"{path} [symlink-escape: {exc}]")

    if violations and raise_on_violation:
        raise ScopeViolationError(
            f"Out-of-scope changes detected:\n" + "\n".join(f"  {v}" for v in violations)
        )
    return violations


def parse_scope_prefixes(scope_str: str) -> list[str]:
    """Parse newline-separated scope prefix string into validated list."""
    from .paths import validate_scope_prefix
    prefixes = []
    for line in scope_str.splitlines():
        line = line.strip()
        if line:
            prefixes.append(validate_scope_prefix(line))
    return prefixes
