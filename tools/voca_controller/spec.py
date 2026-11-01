"""Canonical structured specification for controller tasks.

The spec file is a JSON document created by the trusted local operator.
It contains all task parameters.  When approved, the full canonical JSON
and its SHA-256 digest are persisted -- the original file can then be
discarded without loss of the approved content.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .errors import InvalidApprovalError, RepoVerificationError
from .paths import validate_scope_prefix

VOCA_REPO_NAME = "MohammedA47/Voca"
VOCA_REPO_ID = "1219099434"


@dataclass(frozen=True)
class CanonicalSpec:
    task_id: str
    repo_name: str
    repo_id: str
    issue_number: int
    base_sha: str
    branch: str
    scope_prefixes: tuple[str, ...] = field(default_factory=tuple)
    spec_text: str = ""
    acceptance_text: str = ""
    complexity: str = "routine"

    def canonical_json(self) -> str:
        """Deterministic canonical JSON representation (sorted keys, no extra whitespace)."""
        d: dict[str, Any] = {
            "acceptance_text": self.acceptance_text,
            "base_sha": self.base_sha,
            "branch": self.branch,
            "complexity": self.complexity,
            "issue_number": self.issue_number,
            "repo_id": self.repo_id,
            "repo_name": self.repo_name,
            "scope_prefixes": list(self.scope_prefixes),
            "spec_text": self.spec_text,
            "task_id": self.task_id,
        }
        return json.dumps(d, sort_keys=True, ensure_ascii=True, separators=(",", ":"))

    def digest(self) -> str:
        return hashlib.sha256(self.canonical_json().encode("utf-8")).hexdigest()

    def scope_newline(self) -> str:
        return "\n".join(self.scope_prefixes)


def load_spec_file(path: Path) -> CanonicalSpec:
    """Load, validate, and return a CanonicalSpec from a JSON file."""
    try:
        raw = path.read_text()
        data = json.loads(raw)
    except (OSError, json.JSONDecodeError) as exc:
        raise InvalidApprovalError(f"Cannot read spec file {path}: {exc}") from exc

    if not isinstance(data, dict):
        raise InvalidApprovalError("Spec file must be a JSON object")

    required = [
        "task_id", "repo_name", "repo_id", "issue_number", "base_sha",
        "branch", "scope_prefixes", "spec_text", "acceptance_text", "complexity",
    ]
    missing = [k for k in required if k not in data]
    if missing:
        raise InvalidApprovalError(f"Spec file missing fields: {missing}")

    # -- repo validation --
    if data["repo_name"] != VOCA_REPO_NAME:
        raise RepoVerificationError(
            f"repo_name must be {VOCA_REPO_NAME!r}, got {data['repo_name']!r}"
        )
    if str(data["repo_id"]) != VOCA_REPO_ID:
        raise RepoVerificationError(
            f"repo_id must be {VOCA_REPO_ID!r}, got {str(data['repo_id'])!r}"
        )

    # -- branch validation --
    branch = data["branch"]
    if branch in ("main", "master"):
        raise InvalidApprovalError(
            f"branch must not be {branch!r}; use a task branch"
        )
    if not branch or not isinstance(branch, str):
        raise InvalidApprovalError("branch must be a non-empty string")

    # -- base SHA format --
    sha = str(data["base_sha"]).lower()
    if len(sha) != 40 or not all(c in "0123456789abcdef" for c in sha):
        raise InvalidApprovalError(
            f"base_sha must be 40 hex chars, got {data['base_sha']!r}"
        )

    # -- scope prefixes --
    raw_scope = data["scope_prefixes"]
    if not isinstance(raw_scope, list) or not raw_scope:
        raise InvalidApprovalError("scope_prefixes must be a non-empty list")
    validated_scope = tuple(validate_scope_prefix(str(p)) for p in raw_scope)

    # -- complexity --
    complexity = data["complexity"]
    if complexity not in ("routine", "complex"):
        raise InvalidApprovalError(
            f"complexity must be 'routine' or 'complex', got {complexity!r}"
        )

    # -- texts --
    spec_text = str(data.get("spec_text", ""))
    accept_text = str(data.get("acceptance_text", ""))
    if not spec_text.strip():
        raise InvalidApprovalError("spec_text must not be empty")
    if not accept_text.strip():
        raise InvalidApprovalError("acceptance_text must not be empty")

    return CanonicalSpec(
        task_id=str(data["task_id"]),
        repo_name=data["repo_name"],
        repo_id=str(data["repo_id"]),
        issue_number=int(data["issue_number"]),
        base_sha=sha,
        branch=branch,
        scope_prefixes=validated_scope,
        spec_text=spec_text,
        acceptance_text=accept_text,
        complexity=complexity,
    )


def spec_from_json(canonical_json: str) -> CanonicalSpec:
    """Reconstruct a CanonicalSpec from its canonical JSON representation."""
    data = json.loads(canonical_json)
    return CanonicalSpec(
        task_id=data["task_id"],
        repo_name=data["repo_name"],
        repo_id=data["repo_id"],
        issue_number=data["issue_number"],
        base_sha=data["base_sha"],
        branch=data["branch"],
        scope_prefixes=tuple(data["scope_prefixes"]),
        spec_text=data["spec_text"],
        acceptance_text=data["acceptance_text"],
        complexity=data["complexity"],
    )
