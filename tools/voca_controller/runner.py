"""Bounded local CLI adapters; no credential extraction, publishing or fallback."""
from __future__ import annotations
import json
import os
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from .errors import AdapterError, AuthFailureError, UncertainOpBlocksError

LIMIT = 1_000_000
# The bundled bin/codex is a shell wrapper invoking dirname; use its existing
# native exec target so the wrapper does not need a fork under confinement.
CODEX = '/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex'
CLAUDE = '/opt/homebrew/bin/claude'


def process_identity(pid):
    r = subprocess.run(['ps', '-p', str(pid), '-o', 'lstart='], capture_output=True, text=True, timeout=5)
    if r.returncode or not r.stdout.strip():
        raise UncertainOpBlocksError('Cannot establish process start identity')
    return r.stdout.strip()


def group_live(pgid):
    # Zombies cannot write files; unknown process-list access fails closed.
    r = subprocess.run(['ps', '-axo', 'pgid=,stat='], capture_output=True, text=True, timeout=5)
    if r.returncode:
        raise UncertainOpBlocksError('Cannot inspect process group')
    for line in r.stdout.splitlines():
        fields = line.split()
        if len(fields) == 2 and fields[0] == str(pgid) and not fields[1].startswith('Z'):
            return True
    return False


def assert_subscription_environment():
    keys = ('OPENAI_API_KEY', 'OPENAI_BASE_URL', 'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN',
            'ANTHROPIC_BASE_URL', 'CLAUDE_CODE_OAUTH_TOKEN', 'CLAUDE_CODE_USE_BEDROCK',
            'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY')
    if any(os.environ.get(k) for k in keys):
        raise AuthFailureError('API/provider override present; subscription-only controller stopped')


def command(profile, role, root, scope):
    if profile.provider == 'codex':
        args = [CODEX, '--no-daemon', '-a', 'never', 'exec', '--ignore-user-config', '--ephemeral', '--json',
                '--sandbox', 'read-only',
                '--model', profile.model, '-c', f'model_reasoning_effort="{profile.effort}"',
                '-C', str(root)]
        for feature in ('apps', 'plugins', 'hooks', 'computer_use', 'browser_use', 'multi_agent'):
            args += ['--disable', feature]
        args += ['--disable', 'shell_tool']
        return args + ['-']
    args = [CLAUDE, '-p', '--model', profile.model, '--effort', profile.effort,
            '--setting-sources', '', '--settings', '{"disableAllHooks":true,"autoMemoryEnabled":false}',
            '--strict-mcp-config', '--mcp-config', '{"mcpServers":{}}', '--no-session-persistence',
            '--permission-mode', 'dontAsk', '--output-format', 'json']
    args += ['--tools', '']
    return args


@dataclass
class Result:
    text: str
    reported_model: str | None = None


def parse_output(provider, raw, requested, role):
    try:
        if provider == 'claude':
            d = json.loads(raw)
            if d.get('is_error') and any(w in str(d.get('result', '')).lower() for w in ('auth', 'login', 'quota', 'usage limit', 'permission')):
                raise AuthFailureError('Claude requires human authentication/quota/permission attention')
            if d.get('is_error') or d.get('subtype') != 'success' or not isinstance(d.get('result'), str):
                raise AdapterError('Claude returned an error or invalid envelope')
            models = set(d.get('modelUsage', {}))
            if models and models != {requested}:
                raise AdapterError('Claude reported an unexpected model; no substitution allowed')
            return Result(d['result'], requested if models else None)
        events = [json.loads(line) for line in raw.splitlines() if line.strip()]
        texts = []
        completed = False
        for e in events:
            if e.get('type') in ('error', 'turn.failed'):
                if any(w in json.dumps(e).lower() for w in ('unauthorized', 'authentication', 'login', 'quota', 'usage limit', 'permission')):
                    raise AuthFailureError('Codex requires human authentication/quota/permission attention')
                raise AdapterError('Codex reported a failed turn')
            if e.get('type') == 'turn.completed':
                completed = True
            item = e.get('item', {})
            if item.get('type') in ('command_execution', 'file_change', 'mcp_tool_call', 'web_search'):
                raise AdapterError('Read-only response attempted a tool action')
            if e.get('type') == 'item.completed' and item.get('type') == 'agent_message':
                texts.append(item['text'])
        if not completed or not texts:
            raise AdapterError('Codex response is incomplete')
        return Result(texts[-1])  # JSONL does not attest the resolved model identity.
    except (ValueError, KeyError, TypeError) as exc:
        raise AdapterError('Malformed agent output') from exc


class LocalAdapter:
    def auth_check(self, provider):
        assert_subscription_environment()
        cmd = [CODEX, '--no-daemon', 'login', 'status'] if provider == 'codex' else [CLAUDE, 'auth', 'status']
        r = subprocess.run(confined_command(cmd), capture_output=True, text=True, timeout=10)
        if provider == 'codex':
            valid = r.returncode == 0 and 'Logged in using ChatGPT' in (r.stdout + r.stderr)
        else:
            try:
                d = json.loads(r.stdout)
                valid = r.returncode == 0 and d.get('loggedIn') and d.get('authMethod') == 'claude.ai'
            except ValueError:
                valid = False
        if not valid:
            raise AuthFailureError('Existing subscription login not verified; manual login required')

    def run(self, profile, role, prompt, root, scope, logdir, on_spawn, timeout=180):
        self.auth_check(profile.provider)
        return run_process(command(profile, role, root, scope), prompt, root, logdir,
                           on_spawn, timeout, profile, role)


def run_process(args, prompt, root, logdir, on_spawn, timeout, profile, role):
    """Launch after durable intent; caller marks completion only when this returns."""
    args = confined_command(args)
    return _supervise_confined(args, prompt, root, logdir, on_spawn, timeout, profile, role)


def confined_command(args):
    # Real providers are supported only where the no-descendant guarantee exists.
    # This is a process-local seatbelt profile, not a system settings change.
    if sys.platform != 'darwin' or not Path('/usr/bin/sandbox-exec').is_file():
        raise AdapterError('Real agent execution is unavailable: macOS fork-denial sandbox required')
    return ['/usr/bin/sandbox-exec', '-p', '(version 1)(allow default)(deny process-fork)', *args]


def _supervise_confined(args, prompt, root, logdir, on_spawn, timeout, profile, role):
    # Internal process monitor; production callers must use run_process.
    logdir.mkdir(parents=True, exist_ok=False)
    inp, out, err = [logdir / x for x in ('prompt.txt', 'stdout.txt', 'stderr.txt')]
    inp.write_text(prompt)
    with inp.open('rb') as f, out.open('wb') as o, err.open('wb') as e:
        proc = subprocess.Popen(args, stdin=f, stdout=o, stderr=e, cwd=root,
                                start_new_session=True, shell=False)
    try:
        # The durable pending-spawn record remains blocking if this fails.
        identity = process_identity(proc.pid) if proc.poll() is None else 'exited-before-observation'
        on_spawn(proc.pid, proc.pid, identity)
        deadline = time.monotonic() + timeout
        stopped = False
        while proc.poll() is None:
            if time.monotonic() >= deadline or out.stat().st_size > LIMIT or err.stat().st_size > LIMIT:
                stopped = True
                if process_identity(proc.pid) != identity or os.getpgid(proc.pid) != proc.pid:
                    raise UncertainOpBlocksError('Process identity changed; will not signal an unknown process')
                os.killpg(proc.pid, signal.SIGTERM)
                try:
                    proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    if process_identity(proc.pid) != identity:
                        raise UncertainOpBlocksError('Process identity changed before cleanup')
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait(timeout=3)
                break
            time.sleep(0.05)
        proc.wait(timeout=3)
        # A dead parent with a live child must not release the task for another writer.
        if group_live(proc.pid):
            raise UncertainOpBlocksError('Agent descendants remain alive; operation remains uncertain')
        if stopped or out.stat().st_size > LIMIT or err.stat().st_size > LIMIT:
            raise AdapterError('Agent exceeded time/output budget; process group ended')
        raw, diagnostic = out.read_text(errors='replace'), err.read_text(errors='replace')
        if proc.returncode:
            low = (raw + diagnostic).lower()
            if any(x in low for x in ('unauthorized', 'authentication', 'login', 'quota', 'rate limit', 'usage limit', 'permission')):
                raise AuthFailureError('Agent requires authentication, quota or permission attention; no retry')
            raise AdapterError(f'Agent exited {proc.returncode}; no output accepted')
        return parse_output(profile.provider, raw, profile.model, role)
    except BaseException:
        # Unknown children/launch windows are deliberately left uncertain in SQLite.
        # No broad kill or automatic restart is performed by recovery.
        raise
