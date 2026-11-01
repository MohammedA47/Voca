"""Git local origin verification and GitHub public API confirmation.

The controller verifies two things before real work:
  1. Local git remote 'origin' matches a known Voca URL form.
  2. GitHub public API confirms repo full_name and numeric ID.

The transport function is injectable for testing (no network in tests).
"""
from __future__ import annotations

import json
import subprocess
import urllib.request
from typing import Callable

from .errors import RepoVerificationError

VOCA_REPO_NAME = "MohammedA47/Voca"
VOCA_REPO_ID = "1219099434"

_VOCA_REMOTE_URLS = frozenset(
    {
        "https://github.com/MohammedA47/Voca",
        "https://github.com/MohammedA47/Voca.git",
        "git@github.com:MohammedA47/Voca.git",
        "git@github.com:MohammedA47/Voca",
        "ssh://git@github.com/MohammedA47/Voca.git",
    }
)

_GITHUB_API_URL = "https://api.github.com/repos/MohammedA47/Voca"


def _default_transport(url: str) -> dict:
    req = urllib.request.Request(
        url,
        headers={"Accept": "application/vnd.github+json", "User-Agent": "voca-controller/1"},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:  # noqa: S310
        return json.loads(resp.read().decode())


def verify_git_remote(checkout_root: str) -> str:
    """Return origin URL if it matches a known Voca remote; raise otherwise."""
    result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=checkout_root,
        capture_output=True,
        text=True,
        shell=False,
    )
    if result.returncode != 0:
        raise RepoVerificationError(
            f"git remote get-url origin failed: {result.stderr.strip()}"
        )
    url = result.stdout.strip()
    if url not in _VOCA_REMOTE_URLS:
        raise RepoVerificationError(
            f"Remote origin {url!r} is not a recognised Voca URL"
        )
    return url


def verify_working_tree_clean(checkout_root: str) -> None:
    """Raise RepoVerificationError if working tree is not clean."""
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=checkout_root,
        capture_output=True,
        text=True,
        shell=False,
    )
    if result.returncode != 0:
        raise RepoVerificationError(
            f"git status failed: {result.stderr.strip()}"
        )
    if result.stdout.strip():
        raise RepoVerificationError(
            "Working tree is not clean before dispatch:\n" + result.stdout
        )


def verify_github_public(
    transport: Callable[[str], dict] | None = None,
) -> dict:
    """Verify Voca repo via GitHub public API. Returns parsed response.

    transport is injectable for tests — signature: (url: str) -> dict.
    No credentials are passed; this is a public unauthenticated call.
    """
    if transport is None:
        transport = _default_transport
    try:
        data = transport(_GITHUB_API_URL)
    except Exception as exc:
        raise RepoVerificationError(f"GitHub API call failed: {exc}") from exc

    if not isinstance(data, dict):
        raise RepoVerificationError("GitHub API returned non-dict response")

    got_name = data.get("full_name", "")
    got_id = str(data.get("id", ""))

    if got_name != VOCA_REPO_NAME:
        raise RepoVerificationError(
            f"GitHub full_name mismatch: expected {VOCA_REPO_NAME!r}, got {got_name!r}"
        )
    if got_id != VOCA_REPO_ID:
        raise RepoVerificationError(
            f"GitHub repo ID mismatch: expected {VOCA_REPO_ID!r}, got {got_id!r}"
        )
    if data.get("private", True):
        raise RepoVerificationError("Repo is private; expected public")
    return data
