"""TeslaMate — Tesla data logger.

Two-stage build: Elixir+Node (builder), Debian slim (runtime).
Source cloned from forge mirror.
"""

import dagger
from dagger import dag

from blumeops.containers import clone_from_forge, oci_labels

VERSION = "v3.0.0"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("teslamate", VERSION)

    # Stage 1: Build Elixir release with Node.js assets
    builder = (
        dag.container()
        .from_("elixir:1.19.5-otp-26")
        .with_exec(
            [
                "bash",
                "-c",
                "apt-get update"
                " && apt-get install -y ca-certificates curl gnupg git zstd brotli"
                " && mkdir -p /etc/apt/keyrings"
                " && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key"
                "  | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg"
                ' && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg]'
                ' https://deb.nodesource.com/node_22.x nodistro main"'
                "  > /etc/apt/sources.list.d/nodesource.list"
                " && apt-get update"
                " && apt-get install -y nodejs"
                " && apt-get clean"
                " && rm -rf /var/lib/apt/lists/*",
            ]
        )
        .with_exec(["mix", "local.rebar", "--force"])
        .with_exec(["mix", "local.hex", "--force"])
        .with_directory("/opt/app", source)
        .with_workdir("/opt/app")
        .with_env_variable("MIX_ENV", "prod")
        .with_exec(["mix", "deps.get", "--only", "prod"])
        .with_exec(["mix", "deps.compile"])
        .with_exec(
            [
                "npm",
                "ci",
                "--prefix",
                "./assets",
                "--progress=false",
                "--no-audit",
                "--loglevel=error",
            ]
        )
        .with_exec(["mix", "assets.deploy"])
        .with_exec(["mix", "compile"])
        .with_exec(
            ["bash", "-c", "SKIP_LOCALE_DOWNLOAD=true mix release --path /opt/built"]
        )
    )

    # Stage 2: Debian slim runtime
    entrypoint = src.file("containers/teslamate/entrypoint.sh")

    runtime = (
        dag.container()
        .from_("debian:trixie-slim")
        .with_exec(
            [
                "bash",
                "-c",
                "apt-get update && apt-get install -y --no-install-recommends"
                " libodbc2 libsctp1 libssl3t64 libstdc++6"
                " netcat-openbsd tini tzdata"
                " && apt-get clean"
                " && rm -rf /var/lib/apt/lists/*"
                " && groupadd --gid 10001 --system nonroot"
                " && useradd --uid 10000 --system --gid nonroot"
                "    --home-dir /home/nonroot --shell /sbin/nologin nonroot",
            ]
        )
    )
    runtime = oci_labels(
        runtime,
        title="TeslaMate",
        description="Tesla data logger and visualization",
        version=VERSION,
    )
    return (
        runtime.with_env_variable("LANG", "C.UTF-8")
        .with_env_variable("SRTM_CACHE", "/opt/app/.srtm_cache")
        .with_env_variable("HOME", "/opt/app")
        .with_workdir("/opt/app")
        .with_directory("/opt/app", builder.directory("/opt/built"), owner="nonroot")
        .with_exec(["mkdir", "-p", "/opt/app/.srtm_cache"])
        .with_file("/entrypoint.sh", entrypoint, permissions=0o555, owner="nonroot")
        .with_user("nonroot")
        .with_exposed_port(4000)
        .with_entrypoint(["tini", "--", "/bin/dash", "/entrypoint.sh"])
        .with_default_args(args=["bin/teslamate", "start"])
    )
