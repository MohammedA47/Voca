"""Local operator attestations, never GitHub authentication."""
import getpass
from .spec import canonical, digest
from .errors import ApprovalGateError


def acknowledge(expected, supplied):
    if supplied != expected:
        raise ApprovalGateError('Explicit acknowledgement must equal the displayed SHA-256 digest')


def record(store, task_id, step, spec):
    store.execute('INSERT OR REPLACE INTO approvals VALUES(?,?,?,?,?,?,?)',
                  (task_id, step, 'local', getpass.getuser(), digest(spec),
                   digest(spec['acceptance_text']), canonical(spec)))


def require(store, task_id, spec):
    for step in ('spec', 'execution'):
        row = store.fetchone('SELECT * FROM approvals WHERE task_id=? AND step=?', (task_id, step))
        if not row or row['spec_digest'] != digest(spec):
            raise ApprovalGateError(f'Current {step} approval is required')
