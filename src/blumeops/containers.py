"""Container build discovery and reusable helpers.

Discovers native Dagger builds from containers/<name>/container.py files.
Each container.py must define a top-level `build(src)` async function that
returns a dagger.Container, and a `VERSION` string constant.
"""

import importlib.util
from pathlib import Path
from types import ModuleType

import dagger
from dagger import dag

FORGE_MIRROR = "https://forge.ops.eblu.me/mirrors"


# --- Discovery ---


def _discover_modules(containers_dir: Path) -> dict[str, Path]:
    """Find all containers/<name>/container.py files."""
    result = {}
    if not containers_dir.is_dir():
        return result
    for child in sorted(containers_dir.iterdir()):
        container_py = child / "container.py"
        if child.is_dir() and container_py.exists():
            result[child.name] = container_py
    return result


def _load_module(name: str, path: Path) -> ModuleType:
    """Dynamically load a container.py as a Python module."""
    spec = importlib.util.spec_from_file_location(f"containers.{name}", path)
    if spec is None or spec.loader is None:
        msg = f"Cannot load {path}"
        raise ImportError(msg)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def discover(containers_dir: Path) -> dict[str, ModuleType]:
    """Discover and load all container.py modules.

    Returns a dict mapping container name to loaded module.
    Each module must define:
      - VERSION: str — the upstream application version
      - async def build(src: dagger.Directory) -> dagger.Container
    """
    modules = {}
    for name, path in _discover_modules(containers_dir).items():
        modules[name] = _load_module(name, path)
    return modules


# --- Reusable Helpers ---


def clone_from_forge(mirror: str, tag: str) -> dagger.Directory:
    """Git clone from forge mirror at a given tag. Returns the repo tree."""
    return dag.git(f"{FORGE_MIRROR}/{mirror}.git").tag(tag).tree()


def go_build(
    source: dagger.Directory,
    output: str,
    *,
    cmd_path: str = ".",
    tags: str = "netgo",
    ldflags: str = "-w -s",
    cgo_enabled: bool = False,
    extra_apk: list[str] | None = None,
) -> dagger.Container:
    """Go build stage on golang:alpine3.22.

    Returns a container with the built binary at `output`.
    """
    apk_packages = ["build-base", "git"] + (extra_apk or [])
    return (
        dag.container()
        .from_("golang:alpine3.22")
        .with_exec(["apk", "add", "--no-cache", *apk_packages])
        .with_directory("/app", source)
        .with_workdir("/app")
        .with_env_variable("CGO_ENABLED", "1" if cgo_enabled else "0")
        .with_exec(
            [
                "go",
                "build",
                f"-tags={tags}",
                f"-ldflags={ldflags}",
                "-o",
                output,
                cmd_path,
            ]
        )
    )


def node_build(
    source: dagger.Directory,
    workdir: str,
    *,
    install_cmd: list[str] | None = None,
    build_cmd: list[str] | None = None,
) -> dagger.Container:
    """Node.js build stage on node:22-alpine.

    Returns a container with built assets in the workdir.
    """
    if install_cmd is None:
        install_cmd = ["npm", "ci"]
    if build_cmd is None:
        build_cmd = ["npm", "run", "build"]

    return (
        dag.container()
        .from_("node:22-alpine")
        .with_directory("/app", source)
        .with_workdir(f"/app/{workdir}" if workdir != "." else "/app")
        .with_exec(install_cmd)
        .with_exec(build_cmd)
    )


def alpine_runtime(
    *,
    extra_apk: list[str] | None = None,
    uid: int = 65534,
    gid: int = 65534,
    username: str = "app",
    create_user: bool = True,
) -> dagger.Container:
    """Standard Alpine 3.22 runtime base.

    When create_user is True (default), creates a non-root user with the given
    uid/gid/username. Set create_user=False to use an existing user (e.g.
    Alpine's built-in nobody:65534).
    """
    packages = extra_apk or []
    setup_cmds = []
    if packages:
        setup_cmds.append(f"apk add --no-cache {' '.join(packages)}")
    if create_user:
        setup_cmds.append(f"addgroup -g {gid} {username}")
        setup_cmds.append(f"adduser -u {uid} -G {username} -D {username}")

    ctr = dag.container().from_("alpine:3.22")
    if setup_cmds:
        ctr = ctr.with_exec(["sh", "-c", " && ".join(setup_cmds)])
    return ctr


def oci_labels(
    ctr: dagger.Container,
    *,
    title: str,
    description: str,
    version: str,
) -> dagger.Container:
    """Apply standard BlumeOps OCI labels."""
    return (
        ctr.with_label("org.opencontainers.image.title", title)
        .with_label("org.opencontainers.image.description", description)
        .with_label("org.opencontainers.image.version", version)
        .with_label(
            "org.opencontainers.image.source",
            "https://forge.eblu.me/eblume/blumeops",
        )
        .with_label("org.opencontainers.image.vendor", "blumeops")
    )
