"""Model / effort routing catalog and selection logic.

Versioned built-in catalog of tested provider+model+effort pairs.
The trusted local lead selects routing per task; selections are persisted
with rationale.  Escalation from routine to deep is allowed at most once
per role per task.
"""
from __future__ import annotations

import datetime
from dataclasses import dataclass
from typing import Any

from .db import SQLiteStore
from .errors import RoutingError

CATALOG_VERSION = 1

PROFILE_CATALOG: dict[str, dict[str, str]] = {
    "claude-routine": {
        "provider": "claude",
        "model": "claude-sonnet-4-6",
        "effort": "low",
    },
    "claude-deep": {
        "provider": "claude",
        "model": "claude-opus-4-6",
        "effort": "high",
    },
    "codex-routine": {
        "provider": "codex",
        "model": "gpt-6.1-sol",
        "effort": "low",
    },
    "codex-deep": {
        "provider": "codex",
        "model": "gpt-6-astra",
        "effort": "high",
    },
}

DEFAULT_ROUTES: dict[str, dict[str, str]] = {
    "routine": {"writer": "codex-routine", "reviewer": "claude-routine"},
    "complex": {"writer": "claude-deep",   "reviewer": "codex-deep"},
}

_ESCALATION_MAP: dict[str, str] = {
    "claude-routine": "claude-deep",
    "codex-routine": "codex-deep",
}


def _iso_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


@dataclass(frozen=True)
class RouteSelection:
    profile_name: str
    provider: str
    model: str
    effort: str
    catalog_version: int
    rationale: str
    escalated_from: str | None = None


def resolve_profile(profile_name: str) -> dict[str, str]:
    """Look up a profile; raise RoutingError if unknown."""
    if profile_name not in PROFILE_CATALOG:
        raise RoutingError(
            f"Unknown profile {profile_name!r}; "
            f"available: {sorted(PROFILE_CATALOG)}"
        )
    return PROFILE_CATALOG[profile_name]


def select_route(
    complexity: str,
    role: str,
    *,
    override_profile: str | None = None,
    rationale: str = "",
) -> RouteSelection:
    """Compute a RouteSelection for the given complexity and role.

    *override_profile* allows the lead to choose an explicit profile
    (requires non-empty rationale).
    """
    if override_profile:
        if not rationale:
            raise RoutingError(
                "Explicit profile override requires a non-empty rationale"
            )
        profile_name = override_profile
    else:
        route = DEFAULT_ROUTES.get(complexity)
        if route is None:
            raise RoutingError(
                f"Unknown complexity {complexity!r}; use 'routine' or 'complex'"
            )
        profile_name = route[role]
        if not rationale:
            rationale = f"default-{complexity}"

    info = resolve_profile(profile_name)
    return RouteSelection(
        profile_name=profile_name,
        provider=info["provider"],
        model=info["model"],
        effort=info["effort"],
        catalog_version=CATALOG_VERSION,
        rationale=rationale,
    )


def validate_reciprocal_providers(
    writer: RouteSelection, reviewer: RouteSelection
) -> None:
    """Writer and reviewer must use different providers."""
    if writer.provider == reviewer.provider:
        raise RoutingError(
            f"Writer ({writer.profile_name}) and reviewer ({reviewer.profile_name}) "
            f"must use different providers; both are {writer.provider!r}"
        )


def escalate_profile(
    current: RouteSelection,
    rationale: str,
) -> RouteSelection:
    """Escalate from routine to deep.  Returns a new RouteSelection.

    Raises RoutingError if already deep or escalation not supported.
    """
    if not rationale:
        raise RoutingError("Escalation requires a non-empty rationale")
    if current.escalated_from is not None:
        raise RoutingError(
            f"Profile {current.profile_name!r} was already escalated "
            f"from {current.escalated_from!r}; only one escalation allowed"
        )
    target = _ESCALATION_MAP.get(current.profile_name)
    if target is None:
        raise RoutingError(
            f"No escalation path from {current.profile_name!r}; "
            f"it may already be a deep profile"
        )
    info = resolve_profile(target)
    return RouteSelection(
        profile_name=target,
        provider=info["provider"],
        model=info["model"],
        effort=info["effort"],
        catalog_version=CATALOG_VERSION,
        rationale=rationale,
        escalated_from=current.profile_name,
    )


def persist_selection(
    store: SQLiteStore,
    task_id: str,
    role: str,
    run_ordinal: int,
    selection: RouteSelection,
) -> None:
    """Write a routing selection row (inside a transaction held by caller)."""
    store.execute(
        """INSERT INTO routing_selections
           (task_id, role, run_ordinal, profile_name, provider, model,
            effort, catalog_version, rationale, escalated_from, created_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (
            task_id, role, run_ordinal,
            selection.profile_name, selection.provider,
            selection.model, selection.effort,
            selection.catalog_version, selection.rationale,
            selection.escalated_from, _iso_now(),
        ),
    )


def get_latest_selection(
    store: SQLiteStore, task_id: str, role: str
) -> dict[str, Any] | None:
    """Return the most recent routing selection for task+role."""
    return store.fetchone(
        "SELECT * FROM routing_selections "
        "WHERE task_id=? AND role=? ORDER BY run_ordinal DESC LIMIT 1",
        (task_id, role),
    )


def count_escalations(store: SQLiteStore, task_id: str, role: str) -> int:
    """Count how many times this role has been escalated for the task."""
    row = store.fetchone(
        "SELECT COUNT(*) AS c FROM routing_selections "
        "WHERE task_id=? AND role=? AND escalated_from IS NOT NULL",
        (task_id, role),
    )
    return row["c"] if row else 0
