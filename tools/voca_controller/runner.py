"""AdapterBase, FakeAdapter, ClaudeAdapter, CodexAdapter.

Key safety rules:
- Prompts are delivered via stdin (piped from file), NEVER in the shell command string.
- Process group: os.setsid() on child; kill via os.killpg(pgid, SIGKILL) on timeout.
- Only the exact recorded PGID is killed — never an unknown reused PID.
- Auth failure detection pauses task; no retry.
- JSON envelope from --output-format json is parsed; raw text is extracted.
- Writer: file-only tools (Read, Write, Edit, Glob, Grep), no Bash/network/MCP.
- Reviewer/probe: --tools '' (no tools).
"""
from __future__ import annotations

import abc
import json
import os
import signal
import subprocess
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import IO, Any

from .errors import AdapterError, AuthFailureError

# Canonical Claude CLI flags (reviewer / probe — no tools)
_CLAUDE_COMMON_FLAGS = [
    "--setting-sources", "",
    "--settings", '{"disableAllHooks":true}',
    "--strict-mcp-config",
    "--mcp-config", '{"mcpServers":{}}',
    "--no-session-persistence",
    "--permission-mode", "dontAsk",
    "--output-format", "json",
    "-p",
]

_CLAUDE_REVIEWER_TOOLS_FLAGS = ["--tools", ""]
_CLAUDE_WRITER_TOOLS_FLAGS = ["--allowedTools", "Read,Write,Edit,Glob,Grep"]

# Codex CLI flags
_CODEX_COMMON_FLAGS = ["--ignore-user-config", "--ephemeral", "--json"]

_AUTH_STDERR_PATTERNS = (
    "authentication",
    "unauthorized",
    "unauthenticated",
    "login required",
    "api key",
    "not logged in",
    "auth",
)


@dataclass
class RunHandle:
    op_id: str
    adapter_name: str
    proc: subprocess.Popen | None  # None for FakeAdapter
    pgid: int
    pid: int
    stdout_path: Path
    stderr_path: Path
    timeout_secs: int
    _fake_result: "RunResult | None" = field(default=None, repr=False)


@dataclass
class RunResult:
    op_id: str
    exit_code: int
    stdout: str
    stderr: str
    timed_out: bool = False
    is_auth_failure: bool = False


def _detect_auth_failure(exit_code: int, stderr: str) -> bool:
    if exit_code == 0:
        return False
    low = stderr.lower()
    return any(p in low for p in _AUTH_STDERR_PATTERNS)


def _extract_claude_text(raw_stdout: str) -> str:
    """Parse Claude --output-format json envelope; return text content."""
    try:
        data = json.loads(raw_stdout)
        if isinstance(data, dict):
            # envelope: {"result": "...", ...} or {"type":"result","result":"..."}
            if "result" in data:
                return str(data["result"])
            # list of message parts
            if "content" in data:
                parts = data["content"]
                if isinstance(parts, list):
                    return "".join(
                        p.get("text", "") for p in parts if isinstance(p, dict)
                    )
    except (json.JSONDecodeError, TypeError):
        pass
    return raw_stdout


class AdapterBase(abc.ABC):
    name: str

    @abc.abstractmethod
    def launch(
        self,
        *,
        op_id: str,
        role: str,
        prompt_file: Path,
        working_dir: Path,
        timeout_secs: int,
    ) -> RunHandle:
        """Spawn the adapter. Returns a RunHandle immediately."""

    @abc.abstractmethod
    def wait(self, handle: RunHandle) -> RunResult:
        """Wait for the process and return result."""

    def kill_group(self, handle: RunHandle) -> None:
        """SIGKILL the exact recorded process group. Fail closed if unsure."""
        if handle.proc is None:
            return
        try:
            current_pgid = os.getpgid(handle.pid)
            if current_pgid != handle.pgid:
                # PID reused — do not kill unknown group
                return
            os.killpg(handle.pgid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass


class FakeAdapter(AdapterBase):
    """Deterministic adapter for tests. No subprocess spawned."""

    name = "fake"

    def __init__(
        self,
        exit_code: int = 0,
        stdout: str = '{"result":"LGTM"}',
        stderr: str = "",
        delay_secs: float = 0.0,
        auth_fail: bool = False,
    ) -> None:
        self._exit_code = exit_code
        self._stdout = stdout
        self._stderr = stderr
        self._delay = delay_secs
        self._auth_fail = auth_fail

    def launch(self, *, op_id, role, prompt_file, working_dir, timeout_secs) -> RunHandle:
        if self._delay > 0:
            time.sleep(min(self._delay, 0.01))  # capped for test speed
        tmp = tempfile.mkdtemp()
        out_p = Path(tmp) / "stdout.txt"
        err_p = Path(tmp) / "stderr.txt"
        out_p.write_text(self._stdout)
        err_p.write_text(self._stderr)
        result = RunResult(
            op_id=op_id,
            exit_code=self._exit_code,
            stdout=self._stdout,
            stderr=self._stderr,
            is_auth_failure=self._auth_fail,
        )
        return RunHandle(
            op_id=op_id,
            adapter_name=self.name,
            proc=None,
            pgid=os.getpgrp(),
            pid=os.getpid(),
            stdout_path=out_p,
            stderr_path=err_p,
            timeout_secs=timeout_secs,
            _fake_result=result,
        )

    def wait(self, handle: RunHandle) -> RunResult:
        assert handle._fake_result is not None
        return handle._fake_result


class ClaudeAdapter(AdapterBase):
    """Real Claude CLI adapter.

    Binary path: /opt/homebrew/bin/claude (checked at load time on real runs).
    Prompts delivered via stdin pipe — never in the command line.
    """

    name = "claude"
    _BINARY = "/opt/homebrew/bin/claude"

    def launch(self, *, op_id, role, prompt_file, working_dir, timeout_secs) -> RunHandle:
        if not os.path.exists(self._BINARY):
            raise AdapterError(f"Claude binary not found at {self._BINARY}")

        if role == "reviewer" or role == "probe":
            tool_flags = _CLAUDE_REVIEWER_TOOLS_FLAGS
        else:
            tool_flags = _CLAUDE_WRITER_TOOLS_FLAGS

        args = [self._BINARY] + tool_flags + _CLAUDE_COMMON_FLAGS

        tmp = tempfile.mkdtemp()
        out_p = Path(tmp) / "stdout.txt"
        err_p = Path(tmp) / "stderr.txt"

        with open(str(prompt_file), "rb") as stdin_f, \
             open(str(out_p), "wb") as out_f, \
             open(str(err_p), "wb") as err_f:
            proc = subprocess.Popen(
                args,
                stdin=stdin_f,
                stdout=out_f,
                stderr=err_f,
                cwd=str(working_dir),
                shell=False,
                start_new_session=True,
            )
        pgid = proc.pid  # setsid makes child its own pg leader

        return RunHandle(
            op_id=op_id,
            adapter_name=self.name,
            proc=proc,
            pgid=pgid,
            pid=proc.pid,
            stdout_path=out_p,
            stderr_path=err_p,
            timeout_secs=timeout_secs,
        )

    def wait(self, handle: RunHandle) -> RunResult:
        assert handle.proc is not None
        timed_out = False
        try:
            handle.proc.wait(timeout=handle.timeout_secs)
        except subprocess.TimeoutExpired:
            self.kill_group(handle)
            timed_out = True

        exit_code = handle.proc.returncode or (1 if timed_out else 0)
        stdout = handle.stdout_path.read_text(errors="replace")
        stderr = handle.stderr_path.read_text(errors="replace")
        text = _extract_claude_text(stdout)
        auth_fail = _detect_auth_failure(exit_code, stderr)

        return RunResult(
            op_id=handle.op_id,
            exit_code=exit_code,
            stdout=text,
            stderr=stderr,
            timed_out=timed_out,
            is_auth_failure=auth_fail,
        )


class CodexAdapter(AdapterBase):
    """Real Codex CLI adapter.

    Binary path: /Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex
    Uses: exec --sandbox read-only|workspace-write --ignore-user-config --ephemeral --json
    Prompts delivered via stdin.
    """

    name = "codex"
    _BINARY = "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"

    def launch(self, *, op_id, role, prompt_file, working_dir, timeout_secs) -> RunHandle:
        if not os.path.exists(self._BINARY):
            raise AdapterError(f"Codex binary not found at {self._BINARY}")

        sandbox = "read-only" if role in ("reviewer", "probe") else "workspace-write"
        args = (
            [self._BINARY, "exec", "--sandbox", sandbox]
            + _CODEX_COMMON_FLAGS
            + ["-C", str(working_dir)]
        )

        tmp = tempfile.mkdtemp()
        out_p = Path(tmp) / "stdout.txt"
        err_p = Path(tmp) / "stderr.txt"

        with open(str(prompt_file), "rb") as stdin_f, \
             open(str(out_p), "wb") as out_f, \
             open(str(err_p), "wb") as err_f:
            proc = subprocess.Popen(
                args,
                stdin=stdin_f,
                stdout=out_f,
                stderr=err_f,
                cwd=str(working_dir),
                shell=False,
                start_new_session=True,
            )
        pgid = proc.pid

        return RunHandle(
            op_id=op_id,
            adapter_name=self.name,
            proc=proc,
            pgid=pgid,
            pid=proc.pid,
            stdout_path=out_p,
            stderr_path=err_p,
            timeout_secs=timeout_secs,
        )

    def wait(self, handle: RunHandle) -> RunResult:
        assert handle.proc is not None
        timed_out = False
        try:
            handle.proc.wait(timeout=handle.timeout_secs)
        except subprocess.TimeoutExpired:
            self.kill_group(handle)
            timed_out = True

        exit_code = handle.proc.returncode or (1 if timed_out else 0)
        stdout = handle.stdout_path.read_text(errors="replace")
        stderr = handle.stderr_path.read_text(errors="replace")
        auth_fail = _detect_auth_failure(exit_code, stderr)

        return RunResult(
            op_id=handle.op_id,
            exit_code=exit_code,
            stdout=stdout,
            stderr=stderr,
            timed_out=timed_out,
            is_auth_failure=auth_fail,
        )


def get_adapter(name: str) -> AdapterBase:
    registry: dict[str, type[AdapterBase]] = {
        "claude": ClaudeAdapter,
        "codex": CodexAdapter,
        "fake": FakeAdapter,
    }
    if name not in registry:
        raise ValueError(f"Unknown adapter {name!r}; choose from {sorted(registry)}")
    return registry[name]()
