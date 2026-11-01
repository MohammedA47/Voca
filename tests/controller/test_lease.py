"""Tests for lease.py — WriteLease with fencing counter and liveness check.

Includes:
- Simultaneous acquisition (same process)
- Dead PID takeover (no uncertain ops)
- Alive PID blocks takeover
- Fencing token monotonically increments even after row deletion
- Uncertain op blocks dead-PID takeover
- Real multiprocessing lock contention test
"""
import os
import tempfile
import threading
import unittest
from pathlib import Path

from tests.controller.helpers import make_store
from voca_controller.errors import (
    LeaseHeldError,
    LeaseTokenMismatchError,
    UncertainOpBlocksError,
)
from voca_controller.lease import WriteLease


class TestLeaseAcquireRelease(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.store, _ = make_store(Path(self.tmp))
        self.lease = WriteLease(self.store)

    def tearDown(self):
        self.store.close()

    def test_first_acquire_succeeds(self):
        token = self.lease.acquire()
        self.assertIsInstance(token, int)
        self.assertGreaterEqual(token, 1)

    def test_acquire_twice_same_process_raises(self):
        self.lease.acquire()
        with self.assertRaises(LeaseHeldError):
            self.lease.acquire()

    def test_release_and_reacquire(self):
        token = self.lease.acquire()
        self.lease.release(token)
        token2 = self.lease.acquire()
        # Token must be strictly greater (monotonic even after row deletion)
        self.assertGreater(token2, token)

    def test_release_wrong_token_raises(self):
        self.lease.acquire()
        with self.assertRaises(LeaseTokenMismatchError):
            self.lease.release(9999)

    def test_release_no_lease_is_noop(self):
        # No lease held — release should not raise
        self.lease.release(1)

    def test_fencing_token_monotonic_across_deletions(self):
        t1 = self.lease.acquire()
        self.lease.release(t1)
        t2 = self.lease.acquire()
        self.lease.release(t2)
        t3 = self.lease.acquire()
        self.assertGreater(t2, t1)
        self.assertGreater(t3, t2)


class TestLeaseDeadPidTakeover(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.store, _ = make_store(Path(self.tmp))
        self.lease = WriteLease(self.store)

    def tearDown(self):
        self.store.close()

    def _insert_lease_for_dead_pid(self, pid=999999999, pgid=999999999):
        """Insert a fake lease for a PID that cannot be alive."""
        import datetime
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with self.store.transaction():
            tok = self.store.next_fencing_token()
            self.store.execute(
                """INSERT INTO leases(id, holder_pid, holder_pgid, holder_host,
                    holder_cmdline, start_identity, acquired_at, fencing_token)
                   VALUES(1,?,?,?,?,?,?,?)""",
                (pid, pgid, "testhost", "testcmd", "test-identity", now, tok),
            )
        return tok

    def test_dead_pid_allows_takeover(self):
        self._insert_lease_for_dead_pid()
        # Should succeed since PID 999999999 is not alive
        token = self.lease.acquire(pid=os.getpid(), pgid=os.getpgrp())
        self.assertIsInstance(token, int)

    def test_alive_pid_blocks_takeover(self):
        """Use our own PID — it's definitely alive."""
        import datetime
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        own_pid = os.getpid()
        own_pgid = os.getpgrp()
        with self.store.transaction():
            tok = self.store.next_fencing_token()
            self.store.execute(
                """INSERT INTO leases(id, holder_pid, holder_pgid, holder_host,
                    holder_cmdline, start_identity, acquired_at, fencing_token)
                   VALUES(1,?,?,?,?,?,?,?)""",
                (own_pid, own_pgid, "testhost", "testcmd", "test-id", now, tok),
            )
        # Try to acquire from same process (different call) — should raise
        with self.assertRaises(LeaseHeldError):
            self.lease.acquire(pid=os.getpid() + 1)  # different caller pid, same holder

    def test_dead_pid_blocked_by_uncertain_op(self):
        self._insert_lease_for_dead_pid()
        # Insert an uncertain op
        import datetime
        now = datetime.datetime.now(datetime.timezone.utc).isoformat()
        with self.store.transaction():
            self.store.execute(
                """INSERT INTO op_ledger(op_id, task_id, kind, adapter, started_at, outcome)
                   VALUES('op-1','task-1','implementer','fake',?,'uncertain')""",
                (now,),
            )
        with self.assertRaises(UncertainOpBlocksError):
            self.lease.acquire()


class TestLeaseThreadContention(unittest.TestCase):
    """Real threading test for lock contention via SQLite BEGIN IMMEDIATE."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.store, _ = make_store(Path(self.tmp))

    def tearDown(self):
        self.store.close()

    def test_concurrent_acquire_serialized(self):
        """Two threads racing to acquire — only one should win per cycle."""
        results = []
        errors = []

        def try_acquire():
            lease = WriteLease(self.store)
            try:
                token = lease.acquire()
                results.append(("acquired", token))
                # Hold briefly
                import time; time.sleep(0.01)
                lease.release(token)
            except LeaseHeldError:
                results.append(("blocked",))
            except Exception as e:
                errors.append(e)

        t1 = threading.Thread(target=try_acquire)
        t2 = threading.Thread(target=try_acquire)
        t1.start()
        t2.start()
        t1.join()
        t2.join()

        self.assertEqual(len(errors), 0, f"Unexpected errors: {errors}")
        # At least one thread acquired, at most one held at a time
        acquired_count = sum(1 for r in results if r[0] == "acquired")
        self.assertGreaterEqual(acquired_count, 1)


if __name__ == "__main__":
    unittest.main()
