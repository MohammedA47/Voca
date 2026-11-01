"""Tests for paths.py — path validation and scope prefix enforcement."""
import os
import tempfile
import unittest
from pathlib import Path

from voca_controller.paths import (
    assert_no_symlink_escape,
    is_within_scope,
    resolve_state_dir,
    validate_scope_prefix,
)
from voca_controller.errors import StatePathError


class TestValidateScopePrefix(unittest.TestCase):
    def test_valid_relative_prefix(self):
        self.assertEqual(validate_scope_prefix("tools/voca_controller"), "tools/voca_controller")

    def test_trailing_slash_stripped(self):
        self.assertEqual(validate_scope_prefix("tools/voca_controller/"), "tools/voca_controller")

    def test_absolute_rejected(self):
        with self.assertRaises(StatePathError):
            validate_scope_prefix("/absolute/path")

    def test_traversal_rejected(self):
        with self.assertRaises(StatePathError):
            validate_scope_prefix("../escape")

    def test_git_prefix_rejected(self):
        with self.assertRaises(StatePathError):
            validate_scope_prefix(".git/hooks")

    def test_secrets_rejected(self):
        with self.assertRaises(StatePathError):
            validate_scope_prefix("config/secrets")

    def test_dotenv_rejected(self):
        with self.assertRaises(StatePathError):
            validate_scope_prefix(".env")

    def test_empty_rejected(self):
        with self.assertRaises(StatePathError):
            validate_scope_prefix("")


class TestIsWithinScope(unittest.TestCase):
    def _scope(self):
        return ["tools/voca_controller", "tests/controller"]

    def test_exact_match(self):
        self.assertTrue(is_within_scope("tools/voca_controller", self._scope()))

    def test_subpath_match(self):
        self.assertTrue(is_within_scope("tools/voca_controller/cli.py", self._scope()))

    def test_out_of_scope(self):
        self.assertFalse(is_within_scope("ios/App/App.swift", self._scope()))

    def test_prefix_not_substring(self):
        # tools/voca_controller_extra should NOT match tools/voca_controller
        self.assertFalse(is_within_scope("tools/voca_controller_extra/foo.py", self._scope()))

    def test_traversal_rejected(self):
        self.assertFalse(is_within_scope("tools/../etc/passwd", self._scope()))

    def test_absolute_rejected(self):
        self.assertFalse(is_within_scope("/etc/passwd", self._scope()))

    def test_credential_path_rejected(self):
        self.assertFalse(is_within_scope("tools/.env", self._scope()))

    def test_empty_path_false(self):
        self.assertFalse(is_within_scope("", self._scope()))


class TestResolveStateDir(unittest.TestCase):
    def test_valid_path_outside_checkout(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = resolve_state_dir(tmp)
            self.assertIsInstance(p, Path)

    def test_inside_checkout_rejected(self):
        # We can't guarantee a git repo ancestor for /tmp, but we can create one
        with tempfile.TemporaryDirectory() as tmp:
            import subprocess
            repo = Path(tmp) / "repo"
            repo.mkdir()
            subprocess.run(["git", "init", str(repo)], capture_output=True)
            state_inside = repo / "subdir"
            state_inside.mkdir()
            with self.assertRaises(StatePathError):
                resolve_state_dir(str(state_inside))


class TestNoSymlinkEscape(unittest.TestCase):
    def test_normal_path_ok(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "sub").mkdir()
            assert_no_symlink_escape("sub/file.py", root)

    def test_symlink_escape_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "repo"
            root.mkdir()
            outside = Path(tmp) / "outside"
            outside.mkdir()
            link = root / "escape"
            link.symlink_to(outside)
            with self.assertRaises(StatePathError):
                assert_no_symlink_escape("escape", root)


if __name__ == "__main__":
    unittest.main()
