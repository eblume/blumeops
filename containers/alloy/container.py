"""Grafana Alloy — telemetry collector, native Dagger build.

Three-stage build: Node (UI), Go (server via upstream Makefile with embedded
UI assets), Alpine (runtime). Source cloned from forge mirror.

Notes:
  - Builds via `make alloy` rather than plain `go build` so version stamping,
    release flags, and the netgo+embedalloyui tags match upstream releases.
  - promtail_journal_enabled is intentionally omitted: it requires
    libsystemd-dev and our k8s deployments read pod logs from the filesystem,
    not journald.
  - Uses golang:alpine3.23 (currently Go 1.26.2 — matches alloy v1.16.0's
    go.mod toolchain requirement and the go_build helper's image choice).
"""

import dagger
from dagger import dag

from blumeops.containers import (
    alpine_runtime,
    clone_from_forge,
    node_build,
    oci_labels,
)

VERSION = "v1.16.0"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("alloy", VERSION)

    # Stage 1: Build the web UI (tsc + vite, not the package.json default).
    ui = node_build(
        source,
        "internal/web/ui",
        build_cmd=["sh", "-c", "npx tsc -b && npx vite build"],
    )

    # Stage 2: Build alloy via the upstream Makefile with embedded UI assets.
    builder = (
        dag.container()
        .from_("golang:alpine3.23")
        .with_exec(["apk", "add", "--no-cache", "build-base", "git", "make"])
        .with_directory("/app", source)
        .with_directory(
            "/app/internal/web/ui/dist",
            ui.directory("/app/internal/web/ui/dist"),
        )
        .with_workdir("/app")
        .with_env_variable("CGO_ENABLED", "1")
        .with_env_variable("RELEASE_BUILD", "1")
        .with_env_variable("VERSION", VERSION)
        .with_env_variable("GO_TAGS", "netgo embedalloyui")
        .with_env_variable("SKIP_UI_BUILD", "1")
        .with_exec(["make", "alloy"])
    )

    # Stage 3: Runtime as uid/gid 473 alloy.
    runtime = alpine_runtime(
        extra_apk=["ca-certificates", "tzdata"],
        uid=473,
        gid=473,
        username="alloy",
    )
    runtime = oci_labels(
        runtime,
        title="Alloy",
        description="Grafana Alloy is an OpenTelemetry Collector distribution",
        version=VERSION,
    )
    return (
        runtime.with_file(
            "/bin/alloy",
            builder.file("/app/build/alloy"),
            permissions=0o555,
        )
        .with_exec(
            [
                "sh",
                "-c",
                "mkdir -p /var/lib/alloy/data && chown -R alloy:alloy /var/lib/alloy",
            ]
        )
        .with_env_variable("ALLOY_DEPLOY_MODE", "docker")
        .with_exposed_port(12345)
        .with_user("alloy")
        .with_entrypoint(["/bin/alloy"])
        .with_default_args(
            args=[
                "run",
                "/etc/alloy/config.alloy",
                "--storage.path=/var/lib/alloy/data",
            ]
        )
    )
