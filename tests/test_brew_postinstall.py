import fcntl
import importlib.util
import io
import contextlib
import json
import os
from pathlib import Path
import pty
import signal
import socket
import tempfile
import subprocess
import sys
import termios
import unittest
from unittest.mock import patch


HELPER = Path(__file__).resolve().parents[1] / "libexec/portmap_brew_postinstall.py"
SPEC = importlib.util.spec_from_file_location("portmap_brew_postinstall", HELPER)
bootstrap = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bootstrap)


def terminal_probe():
    # A private session/PTY reproduces Homebrew's foreground parent and
    # background structured-step process group without touching the real TTY.
    master, slave = pty.openpty()
    os.setsid()
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
    reader, writer = os.pipe()
    child = os.fork()
    if child == 0:
        os.close(reader)
        os.setpgid(0, 0)
        before = os.tcgetpgrp(slave)
        try:
            code = bootstrap.run_activation([
                sys.executable, "-c",
                "import os,sys;sys.exit(0 if os.tcgetpgrp(0)==os.getpgrp() else 19)",
            ], dict(os.environ), slave)
            report = {
                "caller_was_background": before != os.getpgrp(),
                "command_exit": code,
                "foreground_restored": os.tcgetpgrp(slave) == before,
            }
        except BaseException as exc:
            report = {"error": repr(exc)}
        os.write(writer, json.dumps(report).encode())
        os._exit(0)
    os.close(writer)
    data = os.read(reader, 8192)
    os.waitpid(child, 0)
    os.close(reader)
    os.close(slave)
    os.close(master)
    print(data.decode())


class PostinstallTerminalTests(unittest.TestCase):
    def test_background_step_hands_off_and_restores_real_terminal(self):
        result = subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), "--terminal-probe"],
            text=True, capture_output=True, timeout=10, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertNotIn("error", report)
        self.assertTrue(report["caller_was_background"])
        self.assertEqual(report["command_exit"], 0)
        self.assertTrue(report["foreground_restored"])


class ActivationDecisionTests(unittest.TestCase):
    def detected_manager(self, *, with_run: bool, with_bus: bool, manager_status: int = 0) -> bool:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            systemd_run = root / "systemd-run"
            user_bus = root / "bus"
            if with_run:
                systemd_run.write_text("#!/bin/sh\nexit 0\n")
                systemd_run.chmod(0o755)
                systemctl = root / "systemctl"
                systemctl.write_text("#!/bin/sh\nexit 0\n")
                systemctl.chmod(0o755)
            listener = None
            if with_bus:
                listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                listener.bind(str(user_bus))
            try:
                with patch.object(bootstrap.subprocess, "run", return_value=subprocess.CompletedProcess([], manager_status)):
                    return bootstrap.user_service_manager(systemd_run=systemd_run, user_bus=user_bus)
            finally:
                if listener is not None:
                    listener.close()

    def test_activation_requires_both_systemd_run_and_the_user_bus(self):
        self.assertTrue(self.detected_manager(with_run=True, with_bus=True))
        self.assertFalse(self.detected_manager(with_run=False, with_bus=True))
        self.assertFalse(self.detected_manager(with_run=True, with_bus=False))

    def test_user_bus_without_a_running_systemd_manager_does_not_activate(self):
        self.assertFalse(self.detected_manager(with_run=True, with_bus=True, manager_status=1))


    def test_main_reports_not_started_without_activation_when_systemd_is_absent(self):
        output = io.StringIO()
        argv = sys.argv
        sys.argv = ["portmap_brew_postinstall.py", "--brew-prefix", "/brew", "--formula-prefix", "/opt/portmap"]
        try:
            with patch.object(bootstrap, "user_service_manager", return_value=False), \
                    patch.object(bootstrap, "run_activation") as activation, contextlib.redirect_stdout(output):
                code = bootstrap.main()
        finally:
            sys.argv = argv
        self.assertEqual(code, 0)
        activation.assert_not_called()



if __name__ == "__main__":
    if "--terminal-probe" in sys.argv:
        terminal_probe()
    else:
        unittest.main()
