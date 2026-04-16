"""Forgejo Runner — native Dagger build.

Two-stage build: Go (static binary with CGO for SQLite), Alpine (runtime).
Source cloned from forge mirror.
"""

import dagger

from blumeops.containers import (
    alpine_runtime,
    clone_from_forge,
    go_build,
    oci_labels,
)

VERSION = "12.7.3"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("forgejo-runner", f"v{VERSION}")

    # Stage 1: Build Go binary (static, CGO enabled for SQLite)
    backend = go_build(
        source,
        "/forgejo-runner",
        tags="netgo osusergo",
        ldflags=(
            '-extldflags "-static" -s -w'
            f' -X "code.forgejo.org/forgejo/runner/v12/internal/pkg/ver.version=v{VERSION}"'
        ),
        cgo_enabled=True,
        extra_env={"CGO_CFLAGS": "-DSQLITE_MAX_VARIABLE_NUMBER=32766"},
    )

    # Stage 2: Runtime
    runtime = alpine_runtime(
        extra_apk=["git", "bash", "ca-certificates"],
        uid=1000,
        gid=1000,
        username="runner",
    )
    runtime = oci_labels(
        runtime,
        title="Forgejo Runner",
        description="A runner for Forgejo Actions",
        version=VERSION,
    )
    return (
        runtime.with_file("/bin/forgejo-runner", backend.file("/forgejo-runner"))
        .with_env_variable("HOME", "/data")
        .with_user("1000:1000")
        .with_workdir("/data")
        .with_default_args(args=["/bin/forgejo-runner"])
    )
