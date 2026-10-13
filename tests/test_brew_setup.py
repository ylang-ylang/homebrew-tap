import importlib.util
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch


MODULE_PATH = Path(__file__).resolve().parents[1] / "libexec" / "portmap_brew_setup.py"
SPEC = importlib.util.spec_from_file_location("portmap_brew_setup", MODULE_PATH)
setup = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = setup
SPEC.loader.exec_module(setup)


class InstallerOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.data = self.home / ".local" / "share"
        self.launcher = self.home / ".local" / "bin" / "portmap"
        self.launcher.parent.mkdir(parents=True)
        self.paths = SimpleNamespace(launcher=self.launcher)
        self.identity = setup.Identity(
            os.getuid(), "installer-test", self.home, self.home / ".config",
            self.data, self.home / "runtime",
        )

    def owned_bundle(self):
        bundle = self.data / "portmap" / "0.12.0"
        bundle.mkdir(parents=True)
        executable = bundle / "portmap"
        executable.write_bytes(b"old bundle executable\n")
        executable.chmod(0o755)
        (bundle / ".portmap-install").write_bytes(b"installed by install.sh\n")
        self.launcher.symlink_to(executable)
        return executable

    def test_brew_virtualenv_entrypoint_can_be_a_symlink(self):
        executable = self.home / "venv-portmap"
        executable.write_bytes(b"#!/bin/sh\nexit 0\n")
        executable.chmod(0o755)
        self.launcher.symlink_to(executable)
        self.assertTrue(setup._executable(self.launcher))
        executable.chmod(0o644)
        self.assertFalse(setup._executable(self.launcher))

    def test_owned_cutover_retains_bundle_and_restores_launcher_on_failure(self):
        executable = self.owned_bundle()
        target = setup.remove_owned_launcher(self.paths, self.identity)
        self.assertFalse(self.launcher.is_symlink())
        self.assertEqual(executable.read_bytes(), b"old bundle executable\n")
        setup.restore_launcher(self.paths, target)
        self.assertEqual(os.readlink(self.launcher), str(executable))

    def test_foreign_executable_is_not_retired(self):
        executable = self.home / "foreign-portmap"
        executable.write_bytes(b"user-owned command\n")
        executable.chmod(0o755)
        self.launcher.symlink_to(executable)
        with self.assertRaises(setup.SetupError):
            setup.remove_owned_launcher(self.paths, self.identity)
        self.assertEqual(os.readlink(self.launcher), str(executable))
        self.assertEqual(executable.read_bytes(), b"user-owned command\n")

    def test_wrong_installer_marker_is_not_owned(self):
        executable = self.owned_bundle()
        (executable.parent / ".portmap-install").write_text("another installer\n")
        with self.assertRaises(setup.SetupError):
            setup.remove_owned_launcher(self.paths, self.identity)
        self.assertEqual(os.readlink(self.launcher), str(executable))

    def test_rollback_does_not_replace_a_concurrent_user_file(self):
        # Insert a user file after the rollback's absence check, immediately
        # before its attempted symlink creation. This caught the old
        # temporary-symlink + os.replace implementation losing user data.
        symlink = os.symlink

        def concurrent_creation(target, destination, *args, **kwargs):
            self.launcher.write_bytes(b"concurrent user command\n")
            return symlink(target, destination, *args, **kwargs)

        with patch.object(setup.os, "symlink", side_effect=concurrent_creation):
            setup.restore_launcher(self.paths, "/old/bundle/portmap")
        self.assertFalse(self.launcher.is_symlink())
        self.assertEqual(self.launcher.read_bytes(), b"concurrent user command\n")


if __name__ == "__main__":
    unittest.main()
