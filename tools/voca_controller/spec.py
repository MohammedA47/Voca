"""Approved local specifications; issue content never grants authority."""
from __future__ import annotations
import hashlib
import json
import re
from pathlib import Path
from .errors import InvalidApprovalError
from .paths import validate_scope_prefix


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True)


def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def read_json(path):
    p = Path(path)
    if p.stat().st_size > 262144:
        raise InvalidApprovalError('Configuration exceeds 256 KiB')
    return json.loads(p.read_text())


def validate_projects(data):
    if not isinstance(data, dict) or set(data) - {'voca', 'arena'} or 'voca' not in data:
        raise InvalidApprovalError('Only the approved voca and arena project keys are supported')
    seen = set()
    for key, p in data.items():
        if set(p) != {'repo_name', 'repo_id', 'private', 'execution_enabled', 'hold_reason'}:
            raise InvalidApprovalError('Project configuration fields are invalid')
        if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', p['repo_name']):
            raise InvalidApprovalError('Invalid repository name')
        if type(p['repo_id']) is not int or p['repo_id'] <= 0:
            raise InvalidApprovalError('Invalid repository ID')
        if type(p['private']) is not bool or type(p['execution_enabled']) is not bool:
            raise InvalidApprovalError('Project switches must be booleans')
        if p['repo_id'] in seen:
            raise InvalidApprovalError('Projects cannot share a repository ID')
        seen.add(p['repo_id'])
        if key == 'voca' and (p['repo_name'], p['repo_id'], p['private']) != ('MohammedA47/Voca', 1219099434, False):
            raise InvalidApprovalError('Voca identity mismatch')
        # Arena identity is pinned by the local operator's acknowledged registry,
        # never embedded in Voca's public source or supplied by an issue.
        if key == 'arena' and (not p['private'] or p['execution_enabled'] or not p['hold_reason']):
            raise InvalidApprovalError('Arena must remain private and held in this release')
    return data


def validate_spec(s, projects):
    fields = {'task_id', 'project', 'repo_name', 'repo_id', 'issue_number', 'base_sha',
              'branch', 'checkout', 'review_path', 'scope_prefixes', 'spec_text',
              'acceptance_text', 'complexity', 'purpose', 'routing_reason',
              'decisions_approved', 'claude_authorized', 'same_provider_review_approved',
              'ci_workflow', 'ci_job'}
    if not isinstance(s, dict) or set(s) != fields:
        raise InvalidApprovalError('Spec fields must match the documented schema exactly')
    if s['project'] not in projects:
        raise InvalidApprovalError('Project is not in the approved registry')
    p = projects[s['project']]
    if (s['repo_name'], s['repo_id']) != (p['repo_name'], p['repo_id']):
        raise InvalidApprovalError('Spec repository identity does not match its project')
    if type(s['repo_id']) is not int or type(s['issue_number']) is not int or s['issue_number'] <= 0:
        raise InvalidApprovalError('Invalid issue or repository ID')
    if not re.fullmatch(r'[a-z0-9][a-z0-9_-]{0,63}', s['task_id']):
        raise InvalidApprovalError('Use a short lowercase task ID')
    prefix = f"automation/{s['project']}-"
    if not s['branch'].startswith(prefix) or not re.fullmatch(r'[a-zA-Z0-9_/-]+', s['branch']):
        raise InvalidApprovalError(f'Task branch must start with {prefix}')
    if not re.fullmatch('[a-f0-9]{40}', s['base_sha']):
        raise InvalidApprovalError('base_sha must be a full lowercase SHA')
    if s['complexity'] not in ('routine', 'complex') or s['purpose'] not in ('product', 'controller'):
        raise InvalidApprovalError('Invalid complexity or purpose')
    for k in ('decisions_approved', 'claude_authorized', 'same_provider_review_approved'):
        if type(s[k]) is not bool:
            raise InvalidApprovalError(f'{k} must be boolean')
    if s['purpose'] != 'controller' and s['same_provider_review_approved']:
        raise InvalidApprovalError('Same-provider exception is for controller setup only')
    if s['purpose'] == 'controller' and s['claude_authorized']:
        raise InvalidApprovalError('Claude is not authorized for controller setup')
    for k in ('spec_text', 'acceptance_text', 'routing_reason', 'ci_job'):
        if not isinstance(s[k], str) or not s[k].strip():
            raise InvalidApprovalError(f'{k} must not be empty')
    if not re.fullmatch(r'\.github/workflows/[a-zA-Z0-9_-]+\.ya?ml', s['ci_workflow']):
        raise InvalidApprovalError('Expected CI workflow must be a repository workflow path')
    if not isinstance(s['scope_prefixes'], list) or not s['scope_prefixes']:
        raise InvalidApprovalError('Scope must not be empty')
    s = dict(s)
    s['scope_prefixes'] = [validate_scope_prefix(x) for x in s['scope_prefixes']]
    for k in ('checkout', 'review_path'):
        if not Path(s[k]).is_absolute():
            raise InvalidApprovalError(f'{k} must be an absolute path')
        s[k] = str(Path(s[k]).resolve())
    return s
