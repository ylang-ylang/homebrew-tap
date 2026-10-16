#!/usr/bin/env python3
"""Activate the installed app through the real user's service manager.

Homebrew keeps its package-install sandbox. User setup runs as a waited,
transient user service, not inside the build sandbox or as root. Its result
is the post-install result; a failed setup cannot become a successful install.
Without a systemd user service manager there is no honest way to run that
activation from the sandbox, so the install reports itself as not started
with the concrete manual commands instead of failing or pretending.
"""
from __future__ import annotations

import argparse
import errno
import os
from pathlib import Path
import signal
import subprocess
import sys


def set_terminal_group(terminal: int, group: int) -> None:
    blocked = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGTTOU})
    try:
        os.tcsetpgrp(terminal, group)
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, blocked)


def run_activation(command: list[str], environment: dict[str, str], terminal: int | None) -> int:
    # Homebrew launches a structured step in a background process group.
    # Hand it the sandbox terminal while systemd-run forwards its PTY;
    # otherwise terminal reads/ioctls stop it with SIGTTIN/SIGTTOU.
    previous = os.tcgetpgrp(terminal) if terminal is not None else None
    try:
        if terminal is not None:
            set_terminal_group(terminal, os.getpgrp())
        result = subprocess.run(
            command, env=environment, check=False,
            stdin=terminal if terminal is not None else subprocess.DEVNULL,
            stdout=terminal, stderr=terminal,
        )
        return result.returncode if result.returncode >= 0 else 128 - result.returncode
    finally:
        if terminal is not None:
            set_terminal_group(terminal, previous)


SYSTEMD_RUN = Path("/usr/bin/systemd-run")


def user_service_manager(*, systemd_run: Path = SYSTEMD_RUN, user_bus: Path | None = None) -> bool:
    """Require a live user manager, not just a client binary or D-Bus socket."""
    if user_bus is None:
        user_bus = Path(f"/run/user/{os.getuid()}/bus")
    systemctl = systemd_run.with_name("systemctl")
    if not (
        systemd_run.is_file() and os.access(systemd_run, os.X_OK)
        and systemctl.is_file() and os.access(systemctl, os.X_OK)
        and user_bus.is_socket()
    ):
        return False
    environment = dict(os.environ)
    environment["XDG_RUNTIME_DIR"] = str(user_bus.parent)
    environment["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={user_bus}"
    try:
        result = subprocess.run(
            [str(systemctl), "--user", "show-environment"],
            env=environment, stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=3, check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return result.returncode == 0


def not_started_notice() -> str:
    return (
        "portmap is installed; automatic setup was not run because a usable\n"
        "systemd user service manager is unavailable. Existing services and\n"
        "configuration were left unchanged. Start or initialize portmap with:\n"
        "  portmap run      foreground session\n"
        "  portmap setup    background operation\n"
        "Readiness has not been checked; use portmap status --check."
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--brew-prefix", required=True)
    parser.add_argument("--formula-prefix", required=True)
    args = parser.parse_args()
    if os.getuid() == 0 or os.geteuid() == 0:
        parser.error("install portmap as your ordinary login user, not with sudo")

    if not user_service_manager():
        print(not_started_notice(), flush=True)
        return 0
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
        return run_activation(command, environment, terminal)
    finally:
        if terminal is not None:
            os.close(terminal)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except OSError as exc:
        print(f"portmap installation failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from None
