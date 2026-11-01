"""Voca smoke probe — read-only identity/capability check of local CLIs.

Requires --execute to actually spawn the CLI. Without --execute, prints
the command that would be run (dry-run).

Handles the JSON envelope from --output-format json (Claude) and
--json (Codex). No API billing fallback: auth failure is reported and stops.

Actual local probe of BOTH CLIs is performed when --adapter=both or
when called separately with --adapter=claude / --adapter=codex.
"""
from __future__ import annotations

import os
import tempfile
from pathlib import Path
from typing import IO

from .errors import AuthFailureError, AdapterError
from .runner import ClaudeAdapter, CodexAdapter, RunResult

_PROBE_PROMPT = """\
[PROBE] This is a read-only smoke test. Please respond with a single sentence
describing what you are (your model identity) and confirm you received this prompt.
Do not take any actions, call any tools, or make any network requests.
"""

_PROBE_TIMEOUT = 60  # seconds


def _write_prompt(text: str) -> Path:
    tmp = tempfile.mkdtemp()
    p = Path(tmp) / "probe_prompt.txt"
    p.write_text(text)
    return p


def probe_claude(execute: bool = False, working_dir: Path | None = None) -> dict:
    """Probe the Claude CLI. Returns result dict."""
    adapter = ClaudeAdapter()
    prompt_file = _write_prompt(_PROBE_PROMPT)
    wd = working_dir or Path.cwd()

    cmd = f"{adapter._BINARY} --tools '' {' '.join(['...flags...'])} -p < {prompt_file}"
    if not execute:
        return {"adapter": "claude", "dry_run": True, "would_run": cmd}

    if not os.path.exists(adapter._BINARY):
        return {"adapter": "claude", "error": f"Binary not found: {adapter._BINARY}"}

    handle = adapter.launch(
        op_id="probe-claude",
        role="probe",
        prompt_file=prompt_file,
        working_dir=wd,
        timeout_secs=_PROBE_TIMEOUT,
    )
    result = adapter.wait(handle)
    return _format_probe_result("claude", result)


def probe_codex(execute: bool = False, working_dir: Path | None = None) -> dict:
    """Probe the Codex CLI. Returns result dict."""
    adapter = CodexAdapter()
    prompt_file = _write_prompt(_PROBE_PROMPT)
    wd = working_dir or Path.cwd()

    if not execute:
        return {
            "adapter": "codex",
            "dry_run": True,
            "would_run": f"{adapter._BINARY} exec --sandbox read-only ...",
        }

    if not os.path.exists(adapter._BINARY):
        return {"adapter": "codex", "error": f"Binary not found: {adapter._BINARY}"}

    handle = adapter.launch(
        op_id="probe-codex",
        role="probe",
        prompt_file=prompt_file,
        working_dir=wd,
        timeout_secs=_PROBE_TIMEOUT,
    )
    result = adapter.wait(handle)
    return _format_probe_result("codex", result)


def _format_probe_result(adapter: str, result: RunResult) -> dict:
    if result.is_auth_failure:
        return {
            "adapter": adapter,
            "error": "auth-failure",
            "exit_code": result.exit_code,
            "stderr": result.stderr[:500],
        }
    if result.timed_out:
        return {"adapter": adapter, "error": "timed-out"}
    if result.exit_code != 0:
        return {
            "adapter": adapter,
            "error": "non-zero-exit",
            "exit_code": result.exit_code,
            "stderr": result.stderr[:500],
        }
    return {
        "adapter": adapter,
        "ok": True,
        "exit_code": result.exit_code,
        "output": result.stdout[:1000],
    }
