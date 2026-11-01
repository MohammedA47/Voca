"""Path validation for state directory, scope prefixes, and path isolation."""
from __future__ import annotations

import os
from pathlib import Path

from .errors import StatePathError

_SENSITIVE_PARTS = frozenset(
    {"secrets", ".env", "credentials", ".ssh", ".gnupg", ".aws", ".netrc"}
)


def resolve_state_dir(raw: str) -> Path:
    """Resolve and validate a state directory path.

    Must not reside inside any git checkout (no .git ancestor) and must not
    be a symlink that escapes to a checkout root.
    """
    p = Path(raw).absolute()
    if p.is_symlink():
        raise StatePathError(f"state-dir {raw} is a symlink; use a real path")
    p = p.resolve()
    _assert_outside_checkout(p, "state-dir")
    for name in ("controller.db", "controller.db-journal", "controller.db-wal", "controller.db-shm"):
        if (p / name).is_symlink():
            raise StatePathError("State database sidecars must not be symlinks")
    return p


def validate_state_dir_exists(raw: str) -> Path:
    """Resolve state-dir; raise if it does not exist or is inside a checkout."""
    p = resolve_state_dir(raw)
    if not p.is_dir():
        raise StatePathError(f"state-dir does not exist: {p}")
    return p


def validate_path_isolation(
    state_dir: Path, writer_dir: Path, review_dir: Path | None = None
) -> None:
    """Ensure state, writer checkout, and review checkout are isolated.

    No directory may be a parent/child of any other.
    """
    dirs: list[tuple[str, Path]] = [
        ("state", state_dir.resolve()),
        ("writer", writer_dir.resolve()),
    ]
    if review_dir is not None:
        dirs.append(("review", review_dir.resolve()))

    for i, (name_a, path_a) in enumerate(dirs):
        for name_b, path_b in dirs[i + 1:]:
            try:
                path_a.relative_to(path_b)
                raise StatePathError(
                    f"{name_a} ({path_a}) is inside {name_b} ({path_b})"
                )
            except ValueError:
                pass
            try:
                path_b.relative_to(path_a)
                raise StatePathError(
                    f"{name_b} ({path_b}) is inside {name_a} ({path_a})"
                )
            except ValueError:
                pass


def _assert_outside_checkout(path: Path, label: str) -> None:
    check = path
    while True:
        if (check / ".git").exists():
            raise StatePathError(
                f"{label} {path} is inside a git checkout rooted at {check}"
            )
        parent = check.parent
        if parent == check:
            break
        check = parent


def validate_scope_prefix(prefix: str) -> str:
    """Validate and return a canonical relative scope prefix."""
    if not isinstance(prefix, str) or not prefix or not prefix.strip():
        raise StatePathError("Scope prefix must not be empty")
    if os.path.isabs(prefix):
        raise StatePathError(f"Scope prefix must be relative, got: {prefix!r}")
    if "\\" in prefix or "\x00" in prefix or prefix in (".", "./") or prefix.startswith("-"):
        raise StatePathError("Noncanonical scope prefix")
    parts = Path(prefix).parts
    if ".." in parts:
        raise StatePathError(f"Scope prefix must not traverse up: {prefix!r}")
    if any(part.lower() in (".git", ".codex", ".claude") or part.lower().startswith(".env") for part in parts):
        raise StatePathError(f"Scope prefix must not start with .git: {prefix!r}")
    for part in parts:
        if part.lower() in _SENSITIVE_PARTS or part.lower().startswith(".env") or part.lower() in (".git", ".codex", ".claude"):
            raise StatePathError(
                f"Scope prefix references credential path {part!r}: {prefix!r}"
            )
    return "/".join(parts)


def is_within_scope(path: str, scope_prefixes: list[str]) -> bool:
    """Return True if *path* is within any of the scope prefixes."""
    if not path:
        return False
    normed = path.replace("\\", "/").strip("/")
    if not normed:
        return False
    parts = Path(normed).parts
    if ".." in parts:
        return False
    if os.path.isabs(path):
        return False
    for part in parts:
        if part.lower() in _SENSITIVE_PARTS or part.lower().startswith(".env") or part.lower() in (".git", ".codex", ".claude"):
            return False
    for pfx in scope_prefixes:
        pfx = pfx.rstrip("/")
        if normed == pfx or normed.startswith(pfx + "/"):
            return True
    return False


def assert_no_symlink_escape(file_path: str, checkout_root: Path) -> None:
    """Raise StatePathError if resolving *file_path* inside *checkout_root* escapes."""
    target = (checkout_root / file_path).resolve()
    try:
        target.relative_to(checkout_root.resolve())
    except ValueError:
        raise StatePathError(
            f"Path {file_path!r} resolves outside checkout root via symlink"
        )
