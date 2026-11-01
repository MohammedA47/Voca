"""Fixed-argv local git and credential-free public GitHub observations."""
import json
import subprocess
import urllib.request
from pathlib import Path
from .errors import RepoVerificationError


def git(root, *args):
    r = subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false',
                        '-c', 'core.fsmonitor=false', *args], cwd=root, capture_output=True,
                       timeout=30, env=None)
    if r.returncode:
        raise RepoVerificationError(f'git {args[0]} failed: {r.stderr.decode(errors="replace")[:500]}')
    return r.stdout.decode('utf-8', errors='strict').strip('\n')


def remote_matches(root, name):
    actual = git(root, 'remote', 'get-url', 'origin')
    if actual not in {f'https://github.com/{name}', f'https://github.com/{name}.git',
                      f'git@github.com:{name}.git', f'ssh://git@github.com/{name}.git'}:
        raise RepoVerificationError('Checkout origin does not match its approved project')
    if Path(git(root, 'rev-parse', '--show-toplevel')).resolve() != Path(root).resolve():
        raise RepoVerificationError('Checkout must be the exact repository root')


def changed(root, base=None):
    paths = set()
    if base:
        paths.update(git(root, 'diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', base, 'HEAD').split('\0'))
    paths.update(git(root, 'diff', '--no-ext-diff', '--no-renames', '--name-only', '-z', 'HEAD').split('\0'))
    # Include ignored files: a new ignored script must not evade scope checks.
    paths.update(git(root, 'ls-files', '--others', '-z').split('\0'))
    return sorted(paths - {''})


def clean(root):
    if changed(root):
        raise RepoVerificationError('Checkout is dirty, including ignored/untracked files')


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise RepoVerificationError('GitHub redirect refused; repository identity must be rechecked')


def public_get(repo, suffix=''):
    url = f'https://api.github.com/repos/{repo}{suffix}'
    req = urllib.request.Request(url, headers={'Accept': 'application/vnd.github+json',
                                               'User-Agent': 'voca-controller'})
    try:
        with urllib.request.build_opener(NoRedirect).open(req, timeout=15) as response:
            raw = response.read(2_000_001)
            if len(raw) > 2_000_000:
                raise RepoVerificationError('GitHub response exceeds limit')
            return json.loads(raw)
    except Exception as exc:
        raise RepoVerificationError(f'Public GitHub observation failed: {type(exc).__name__}') from exc


def verify_remote(project, spec, get=public_get):
    if project['private'] or not project['execution_enabled']:
        raise RepoVerificationError('Project execution is held: ' + project['hold_reason'])
    repo = get(project['repo_name'])
    if (repo.get('full_name'), repo.get('id'), repo.get('private')) != (
            project['repo_name'], project['repo_id'], False):
        raise RepoVerificationError('GitHub repository identity changed')
    base = get(project['repo_name'], '/branches/main')['commit']['sha']
    if base != spec['base_sha']:
        raise RepoVerificationError('Remote main changed; specification and evidence require renewed review')


def ci_observation(project, spec, sha, run_id, get=public_get):
    if type(run_id) is not int or run_id <= 0:
        raise RepoVerificationError('Invalid run ID')
    run = get(project['repo_name'], f'/actions/runs/{run_id}')
    if not (run.get('repository', {}).get('id') == project['repo_id']
            and run.get('head_repository', {}).get('id') == project['repo_id']
            and run.get('head_sha') == sha and run.get('head_branch') == spec['branch']
            and run.get('status') == 'completed' and run.get('conclusion') == 'success'
            and run.get('event') in ('push', 'pull_request')
            and run.get('path', '').split('@')[0] == spec['ci_workflow']):
        raise RepoVerificationError('CI run does not validate this project, branch, SHA and workflow')
    jobs = get(project['repo_name'], f'/actions/runs/{run_id}/jobs?filter=latest&per_page=100')
    if jobs.get('total_count', 0) > 100:
        raise RepoVerificationError('CI job result requires pagination; no partial validation accepted')
    selected = [j for j in jobs.get('jobs', []) if j.get('name') == spec['ci_job']]
    if len(selected) != 1 or selected[0].get('conclusion') != 'success':
        raise RepoVerificationError('Required CI job is missing or unsuccessful')
    return {'run_id': run_id, 'sha': sha, 'source': 'github-api-observed',
            'url': f"https://github.com/{project['repo_name']}/actions/runs/{run_id}"}
