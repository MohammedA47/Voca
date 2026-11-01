"""Path validation for state directory and scope prefixes."""
from __future__ import annotations

import os
from pathlib import Path

from .errors import StatePathError

# Credential-adjacent names that must never appear in scope prefixes
_SENSITIVE_PARTS = frozenset(
    {"secrets", ".env", "credentials", ".ssh", ".gnupg", ".aws", ".netrc"}
)


def resolve_state_dir(raw: str) -> Path:
    """Resolve and validate a state directory path.

    The resolved path must not reside inside any git checkout (no .git ancestor),
    must not be a symlink that escapes to a checkout root, and must exist or be
    creatable (parent must exist).
    """
    p = Path(raw).resolve()  # follows symlinks
    _assert_outside_checkout(p, "state-dir")
    return p


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
    """Validate and return a canonical relative scope prefix.

    Rejects: absolute paths, '..' traversal, '.git' prefix, credential-
    adjacent names, and empty strings.
    """
    if not prefix or not prefix.strip():
        raise StatePathError("Scope prefix must not be empty")
    if os.path.isabs(prefix):
        raise StatePathError(f"Scope prefix must be relative, got: {prefix!r}")
    parts = Path(prefix).parts
    if ".." in parts:
        raise StatePathError(f"Scope prefix must not traverse up: {prefix!r}")
    if parts and parts[0] == ".git":
        raise StatePathError(f"Scope prefix must not start with .git: {prefix!r}")
    for part in parts:
        if part.lower() in _SENSITIVE_PARTS:
            raise StatePathError(
                f"Scope prefix references credential path {part!r}: {prefix!r}"
            )
    # Canonical: forward slashes, no trailing slash
    return "/".join(parts)


def is_within_scope(path: str, scope_prefixes: list[str]) -> bool:
    """Return True if *path* is within any of the scope prefixes.

    Also rejects paths with traversal, absolute paths, or credential parts.
    """
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
        if part.lower() in _SENSITIVE_PARTS:
            return False
    for prefix in scope_prefixes:
        prefix = prefix.rstrip("/")
        if normed == prefix or normed.startswith(prefix + "/"):
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
