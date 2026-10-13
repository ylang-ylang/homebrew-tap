#!/usr/bin/env python3
"""Activate the installed app through the real user's service manager.

Homebrew keeps its package-install sandbox. User setup runs as a waited,
transient user service, not inside the build sandbox or as root. Its result
is the post-install result; a failed setup cannot become a successful install.
"""
from __future__ import annotations

import argparse
import errno
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--brew-prefix", required=True)
    parser.add_argument("--formula-prefix", required=True)
    args = parser.parse_args()
    if os.getuid() == 0 or os.geteuid() == 0:
        parser.error("install portmap as your ordinary login user, not with sudo")

    runtime = f"/run/user/{os.getuid()}"
    environment = dict(os.environ)
    environment["XDG_RUNTIME_DIR"] = runtime
    environment["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={runtime}/bus"
    command = [
        "/usr/bin/systemd-run", "--user", "--wait", "--collect",
        "--unit=portmap-brew-setup", "--property=Type=exec",
    ]
    # The service manager has its own environment. Carry user selections
    # across explicitly, never Homebrew's temporary HOME/config directory.
    forwarded = {
        "PATH", "XDG_DATA_HOME", "XDG_STATE_HOME", "DOCKER_HOST",
        "DOCKER_CONTEXT", "DOCKER_CONFIG", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH",
        "SSH_AUTH_SOCK", "SSH_ASKPASS", "DISPLAY", "WAYLAND_DISPLAY",
        "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy",
    }
    sandbox_home = os.environ.get("HOME", "").rstrip("/")
    for key, value in os.environ.items():
        if key not in forwarded and not key.startswith("PORTMAP_"):
            continue
        if key.startswith("XDG_") and sandbox_home and (
            value == sandbox_home or value.startswith(sandbox_home + "/")
        ):
            continue
        command.append(f"--setenv={key}={value}")
    # Homebrew captures a step's stdin. Use the controlling terminal directly
    # when present so systemd-run's PTY can carry the normal sudo prompt.
    terminal = None
    try:
        terminal = os.open("/dev/tty", os.O_RDWR | os.O_CLOEXEC)
    except OSError as exc:
        if exc.errno not in (errno.ENXIO, errno.ENODEV, errno.ENOENT):
            raise
    command.append("--pty" if terminal is not None else "--pipe")
    command.extend([
        "--", sys.executable,
        str(Path(__file__).with_name("portmap_brew_setup.py")),
        "--brew-prefix", args.brew_prefix,
        "--formula-prefix", args.formula_prefix,
    ])
    try:
        result = subprocess.run(
            command, env=environment, check=False,
            stdin=terminal if terminal is not None else subprocess.DEVNULL,
            stdout=terminal, stderr=terminal,
        )
        return result.returncode if result.returncode >= 0 else 128 - result.returncode
    finally:
        if terminal is not None:
            os.close(terminal)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except OSError as exc:
        print(f"portmap installation failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from None
