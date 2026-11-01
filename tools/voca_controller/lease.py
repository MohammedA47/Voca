"""Host-local exclusive gate plus durable SQLite fencing. No timeout takeover."""
import fcntl
import os
import socket
import stat
import tempfile
from pathlib import Path
from .errors import LeaseHeldError, LeaseTokenMismatchError, UncertainOpBlocksError


class MachineLock:
    def __init__(self, state, path=None):
        self.state = str(Path(state).resolve())
        self.path = Path(path) if path else Path(tempfile.gettempdir()) / f'voca-controller-{os.getuid()}.lock'
        self.fd = None

    def __enter__(self):
        fd = os.open(self.path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        try:
            st = os.fstat(fd)
            if not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid():
                raise LeaseHeldError('Invalid controller machine-lock owner/type')
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            registered = os.read(fd, 16384).decode()
            if registered and registered != self.state:
                raise LeaseHeldError('This Mac is bound to a different controller state root; use that root')
            if not registered:
                os.write(fd, self.state.encode()); os.fsync(fd)
            self.fd = fd
            return self
        except BaseException:
            os.close(fd)
            raise

    def __exit__(self, *args):
        if self.fd is not None:
            fcntl.flock(self.fd, fcntl.LOCK_UN)
            os.close(self.fd); self.fd = None


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


class WriteLease:
    def __init__(self, store):
        self.store = store

    def acquire(self):
        from .runner import process_identity
        with self.store.transaction():
            if self.store.fetchone("SELECT 1 FROM op_ledger WHERE outcome='uncertain'"):
                raise UncertainOpBlocksError('Uncertain agent launch requires reconciliation')
            old = self.current()
            if old and (old['holder_host'] != socket.gethostname() or alive(old['holder_pid'])):
                raise LeaseHeldError('Existing lease holder is live or on an unknown host')
            token = self.store.next_fencing_token()
            self.store.execute('DELETE FROM leases')
            self.store.execute("INSERT INTO leases VALUES(1,?,?,?,?,?,?,?)", (
                os.getpid(), os.getpgrp(), socket.gethostname(), 'voca-controller',
                process_identity(os.getpid()), 'local', token))
            return token

    def assert_token(self, token):
        row = self.current()
        if not row or row['fencing_token'] != token:
            raise LeaseTokenMismatchError('Stale controller lease')

    def current(self):
        return self.store.fetchone('SELECT * FROM leases WHERE id=1')

    def release(self, token):
        with self.store.transaction():
            self.assert_token(token)
            self.store.execute('DELETE FROM leases WHERE id=1')
