"""Forgejo Runner — native Dagger build.

Two-stage build: Go (static binary with CGO for SQLite), Alpine (runtime).
Source cloned from forge mirror.
"""

import dagger
from dagger import dag

from blumeops.containers import (
    alpine_runtime,
    clone_from_forge,
    oci_labels,
)

VERSION = "12.7.3"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("forgejo-runner", f"v{VERSION}")

    # Stage 1: Build Go binary (static, CGO enabled for SQLite)
    ldflags = (
        '-extldflags "-static" -s -w'
        f' -X "code.forgejo.org/forgejo/runner/v12/internal/pkg/ver.version=v{VERSION}"'
    )
    backend = (
        dag.container()
        .from_("golang:alpine3.22")
        .with_exec(["apk", "add", "--no-cache", "build-base", "git"])
        .with_directory("/app", source)
        .with_workdir("/app")
        .with_env_variable("CGO_ENABLED", "1")
        .with_env_variable("CGO_CFLAGS", "-DSQLITE_MAX_VARIABLE_NUMBER=32766")
        .with_exec(
            [
                "go",
                "build",
                "-tags=netgo osusergo",
                f"-ldflags={ldflags}",
                "-o",
                "/forgejo-runner",
                ".",
            ]
        )
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
