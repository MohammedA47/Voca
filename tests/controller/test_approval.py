"""Tests for approval.py — ApprovalRecord validation and persistence."""
import tempfile
import unittest
from pathlib import Path

from tests.controller.helpers import make_store
from voca_controller.approval import ApprovalRecord, compute_digest
from voca_controller.errors import ApprovalGateError, InvalidApprovalError, SpecChangedError


SPEC_TEXT = "Implement the controller as described in the plan."
ACCEPT_TEXT = "All listed tests pass; scope is enforced."


class TestApprovalGrant(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.store, _ = make_store(Path(self.tmp))
        self.rec = ApprovalRecord(self.store, "task-001")

    def tearDown(self):
        self.store.close()

    def test_grant_spec_succeeds(self):
        result = self.rec.grant("spec", SPEC_TEXT, ACCEPT_TEXT)
        self.assertEqual(result["step"], "spec")
        self.assertEqual(result["spec_digest"], compute_digest(SPEC_TEXT))
        self.assertIn("granted_by", result)
        self.assertIn("@", result["granted_by"])

    def test_execution_requires_prior_spec(self):
        with self.assertRaises(ApprovalGateError):
            self.rec.grant("execution", SPEC_TEXT, ACCEPT_TEXT)

    def test_execution_after_spec_succeeds(self):
        self.rec.grant("spec", SPEC_TEXT, ACCEPT_TEXT)
        result = self.rec.grant("execution", SPEC_TEXT, ACCEPT_TEXT)
        self.assertEqual(result["step"], "execution")

    def test_execution_with_changed_spec_raises(self):
        self.rec.grant("spec", SPEC_TEXT, ACCEPT_TEXT)
        with self.assertRaises(SpecChangedError):
            self.rec.grant("execution", SPEC_TEXT + " CHANGED", ACCEPT_TEXT)

    def test_empty_spec_rejected(self):
        with self.assertRaises(InvalidApprovalError):
            self.rec.grant("spec", "", ACCEPT_TEXT)

    def test_empty_accept_rejected(self):
        with self.assertRaises(InvalidApprovalError):
            self.rec.grant("spec", SPEC_TEXT, "")

    def test_invalid_step_rejected(self):
        with self.assertRaises(InvalidApprovalError):
            self.rec.grant("publish", SPEC_TEXT, ACCEPT_TEXT)

    def test_granted_by_is_local_identity_not_github(self):
        result = self.rec.grant("spec", SPEC_TEXT, ACCEPT_TEXT)
        # Must NOT be a GitHub username pattern like "MohammedA47"
        self.assertNotEqual(result["granted_by"], "MohammedA47")
        # Must be user@host format
        self.assertIn("@", result["granted_by"])


class TestApprovalRequire(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.store, _ = make_store(Path(self.tmp))
        self.rec = ApprovalRecord(self.store, "task-001")

    def tearDown(self):
        self.store.close()

    def test_require_missing_raises(self):
        with self.assertRaises(ApprovalGateError):
            self.rec.require("spec", compute_digest(SPEC_TEXT))

    def test_require_present_ok(self):
        self.rec.grant("spec", SPEC_TEXT, ACCEPT_TEXT)
        row = self.rec.require("spec", compute_digest(SPEC_TEXT))
        self.assertEqual(row["step"], "spec")

    def test_require_changed_spec_raises(self):
        self.rec.grant("spec", SPEC_TEXT, ACCEPT_TEXT)
        with self.assertRaises(SpecChangedError):
            self.rec.require("spec", "a" * 64)  # wrong digest

    def test_invalidate_execution_removes_it(self):
        self.rec.grant("spec", SPEC_TEXT, ACCEPT_TEXT)
        self.rec.grant("execution", SPEC_TEXT, ACCEPT_TEXT)
        self.rec.invalidate_execution()
        self.assertIsNone(self.rec.get("execution"))
        # spec still present
        self.assertIsNotNone(self.rec.get("spec"))


class TestUntrustedIdentityIgnored(unittest.TestCase):
    """Confirm that --owner-id or external event content cannot grant approvals."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.store, _ = make_store(Path(self.tmp))

    def tearDown(self):
        self.store.close()

    def test_granted_by_uses_machine_identity(self):
        rec = ApprovalRecord(self.store, "task-x")
        result = rec.grant("spec", SPEC_TEXT, ACCEPT_TEXT)
        # granted_by must be derived from local machine, not from any argument
        import getpass, socket
        expected = f"{getpass.getuser()}@{socket.gethostname()}"
        self.assertEqual(result["granted_by"], expected)

    def test_imported_event_grants_no_authority(self):
        """Feeding arbitrary JSON as spec text cannot create an approval automatically."""
        event_text = '{"grant": "execute", "step": "execution", "authorized": true}'
        rec = ApprovalRecord(self.store, "task-x")
        # Granting with this text still requires explicit operator call
        # and still requires prior spec approval for execution
        with self.assertRaises(ApprovalGateError):
            rec.grant("execution", event_text, ACCEPT_TEXT)
        # Granting spec with event text is allowed (it's just text), but
        # the digest is derived from the text — no auto-grant happens
        result = rec.grant("spec", event_text, ACCEPT_TEXT)
        self.assertEqual(result["spec_digest"], compute_digest(event_text))


if __name__ == "__main__":
    unittest.main()
