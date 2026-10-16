#!/usr/bin/env python3
"""Initialize portmap against an existing Docker or Podman API.

The installer invokes this outside its build sandbox, directly or through a
usable user service manager. It never installs, starts, enables or reconfigures
a container engine, and never publishes a business project.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import grp
from html.parser import HTMLParser
import http.client
import json
import os
from pathlib import Path
import pwd
import shlex
import stat
import subprocess
import sys
from types import SimpleNamespace


class SetupError(Exception):
    pass


@dataclass(frozen=True)
class Identity:
    uid: int
    user: str
    home: Path
    config_home: Path
    data_home: Path
    runtime_dir: Path


def note(message: str) -> None:
    print(message, flush=True)


def _executable(path: Path) -> bool:
    return path.is_file() and os.access(path, os.X_OK)


def identity() -> Identity:
    if os.getuid() == 0 or os.geteuid() == 0:
        raise SetupError("run portmap installation as your ordinary user, not root")
    user = pwd.getpwuid(os.getuid())
    home = Path(user.pw_dir)
    data = Path(os.environ.get("XDG_DATA_HOME") or home / ".local/share")
    if not data.is_absolute():
        raise SetupError("XDG_DATA_HOME must be absolute")
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{user.pw_uid}")
    if not runtime.is_absolute():
        raise SetupError("XDG_RUNTIME_DIR must be absolute")
    return Identity(user.pw_uid, user.pw_name, home, home / ".config", data, runtime)


def adopt_configured_docker_group(user: Identity) -> None:
    """A long-lived user manager may predate already-granted group membership."""
    try:
        group = grp.getgrnam("docker")
        endpoint = Path("/var/run/docker.sock").stat()
    except (KeyError, OSError):
        return
    if (group.gr_gid == 0 or group.gr_gid in {*os.getgroups(), os.getegid()}
            or user.user not in group.gr_mem or endpoint.st_gid != group.gr_gid
            or not stat.S_ISSOCK(endpoint.st_mode)):
        return
    note("Using the Docker group access already granted to this user")
    command = shlex.join([sys.executable, str(Path(__file__).resolve()), *sys.argv[1:]])
    # Debian-family systems ship sg; util-linux on Arch/Manjaro provides
    # newgrp with -c instead. Never pick an unrelated user-PATH "sg" command.
    program = Path("/usr/bin/sg")
    if not _executable(program):
        program = Path("/usr/bin/newgrp")
    if not _executable(program):
        raise SetupError("the user manager needs refreshed Docker group access, but sg/newgrp is unavailable")
    os.execv(program, [str(program), "docker", "-c", command])


def classify_launcher(paths, user: Identity) -> str | None:
    launcher = paths.launcher
    if not os.path.lexists(launcher):
        return None
    metadata = launcher.lstat()
    if not stat.S_ISLNK(metadata.st_mode) or metadata.st_uid != user.uid:
        raise SetupError(f"refusing to remove unmanaged launcher {launcher}")
    target = os.readlink(launcher)
    executable = Path(target)
    if not executable.is_absolute():
        executable = launcher.parent / executable
    managed = (user.data_home / "portmap").resolve()
    resolved = executable.resolve(strict=True)
    try:
        relative = resolved.relative_to(managed)
    except ValueError:
        raise SetupError(f"refusing to remove unmanaged launcher {launcher} -> {target}") from None
    bundle = executable.parent
    executable_stat = executable.lstat()
    bundle_stat = bundle.lstat()
    marker = bundle / ".portmap-install"
    if (len(relative.parts) != 2 or resolved.name != "portmap"
            or not stat.S_ISREG(executable_stat.st_mode) or not os.access(executable, os.X_OK)
            or executable_stat.st_uid != user.uid or not stat.S_ISDIR(bundle_stat.st_mode)
            or bundle_stat.st_uid != user.uid or bundle.resolve() != resolved.parent):
        raise SetupError(f"refusing to remove unowned standalone launcher {launcher}")
    marker_stat = marker.lstat()
    if (not stat.S_ISREG(marker_stat.st_mode) or marker_stat.st_uid != user.uid
            or marker.read_bytes() != b"installed by install.sh\n"):
        raise SetupError(f"standalone installer marker does not match: {marker}")
    return target


def remove_owned_launcher(paths, user: Identity) -> str | None:
    target = classify_launcher(paths, user)
    if target is not None:
        if classify_launcher(paths, user) != target:
            raise SetupError(f"launcher changed during migration: {paths.launcher}")
        paths.launcher.unlink()
        note(f"Retired standalone launcher; bundle retained: {target}")
    return target


def restore_launcher(paths, target: str) -> None:
    try:
        os.symlink(target, paths.launcher)
        note(f"Restored standalone launcher {paths.launcher}")
    except FileExistsError:
        note(f"Not restoring {paths.launcher}: another file now occupies that path")
    except OSError as exc:
        note(f"Could not restore {paths.launcher}: {exc}")


class PageAssets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.scripts: list[str] = []

    def handle_starttag(self, tag, attrs):
        if tag == "script":
            source = dict(attrs).get("src")
            if source:
                self.scripts.append(source)


def get(port: int, path: str) -> tuple[str, bytes]:
    # Direct HTTPConnection deliberately ignores proxy environment variables.
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=15)
    try:
        connection.request("GET", path, headers={"Host": "127.0.0.1", "Connection": "close"})
        response = connection.getresponse()
        if response.status != 200:
            raise SetupError(f"homepage readiness failed: GET {path} returned HTTP {response.status}")
        return response.getheader("Content-Type", ""), response.read()
    finally:
        connection.close()


def verify_homepage(port: int) -> None:
    content_type, body = get(port, "/")
    if "text/html" not in content_type:
        raise SetupError("the loopback homepage did not return HTML")
    page = PageAssets()
    page.feed(body.decode("utf-8"))
    if not page.scripts:
        raise SetupError("the homepage has no application script")
    for script in page.scripts:
        if not script.startswith("/assets/"):
            raise SetupError(f"unexpected homepage application asset: {script}")
        kind, _ = get(port, script)
        if "javascript" not in kind:
            raise SetupError(f"homepage application asset is not JavaScript: {script}")
    _, raw = get(port, "/registry.json")
    catalog = json.loads(raw)
    if (not isinstance(catalog, dict) or not isinstance(catalog.get("dns_domain"), str)
            or not isinstance(catalog.get("services"), list)):
        raise SetupError("the loopback catalog API did not return a portmap catalog")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--brew-prefix", type=Path, required=True)
    parser.add_argument("--formula-prefix", type=Path, required=True)
    args = parser.parse_args()
    user = identity()
    os.environ["HOME"] = str(user.home)
    os.environ["USER"] = user.user
    os.environ["XDG_RUNTIME_DIR"] = str(user.runtime_dir)
    os.environ["PATH"] = f"{args.brew_prefix}/bin:{args.brew_prefix}/sbin:{os.environ.get('PATH', '')}:{user.home}/.local/bin:/usr/bin:/bin"
    adopt_configured_docker_group(user)
    env = dict(os.environ)
    cli = args.formula_prefix / "bin/portmap"
    if not _executable(cli):
        raise SetupError(f"Brew portmap entrypoint is unavailable: {cli}")
    paths = SimpleNamespace(launcher=user.home / ".local/bin/portmap")
    classify_launcher(paths, user)

    # Keep one runtime-selection convention: explicit portmap configuration,
    # then the existing CLI auto-detection (Docker before Podman).
    from portmap.container_runtime import ContainerRuntime
    from portmap.errors import PortmapError
    from portmap.settings import load_portmap_settings
    settings = load_portmap_settings(environ=env)
    try:
        runtime = ContainerRuntime.connect(settings)
    except PortmapError as exc:
        raise SetupError(
            f"No usable configured Docker/Podman API: {exc}. "
            "Install/start your chosen runtime and grant this user access; "
            "portmap does not install or start a container engine."
        ) from exc
    note(f"Using existing {runtime.backend} at {runtime.socket_path}")
    env.update(PORTMAP_RUNTIME=runtime.backend, PORTMAP_RUNTIME_SOCKET=runtime.socket_path,
               DOCKER_HOST=f"unix://{runtime.socket_path}")
    for key in ("DOCKER_CONTEXT", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH"):
        env.pop(key, None)

    target = remove_owned_launcher(paths, user)
    try:
        # Core setup owns worker lifetimes and requests sudo only where needed.
        result = subprocess.run(
            [str(cli), "setup"], env=env, text=True, stdout=subprocess.PIPE, check=True,
        )
        print(result.stdout, end="", flush=True)
        state = json.loads(result.stdout)
        port = state["gateway"]["http_port"]
        if type(port) is not int or not 1 <= port <= 65535:
            raise SetupError("setup returned an invalid HTTP port")
        verify_homepage(port)
    except BaseException:
        if target is not None:
            restore_launcher(paths, target)
        raise
    url = "http://127.0.0.1/" if port == 80 else f"http://127.0.0.1:{port}/"
    note(f"portmap is ready: {url}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (SetupError, OSError, ValueError, KeyError, http.client.HTTPException, subprocess.CalledProcessError) as exc:
        print(f"portmap installation failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from None
