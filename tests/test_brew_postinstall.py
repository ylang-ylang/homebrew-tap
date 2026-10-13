import fcntl
import importlib.util
import json
import os
from pathlib import Path
import pty
import signal
import subprocess
import sys
import termios
import unittest


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


if __name__ == "__main__":
    if "--terminal-probe" in sys.argv:
        terminal_probe()
    else:
        unittest.main()
