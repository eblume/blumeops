"""Miniflux RSS feed reader — native Dagger build.

Two-stage build: Go (backend with PIE), Alpine (runtime).
Source cloned from forge mirror.
"""

import dagger
from dagger import dag

from blumeops.containers import (
    alpine_runtime,
    clone_from_forge,
    oci_labels,
)

VERSION = "2.2.19"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("miniflux", VERSION)

    # Stage 1: Build Go backend (PIE mode, matching upstream Makefile)
    ldflags = f"-s -w -X 'miniflux.app/v2/internal/version.Version={VERSION}'"
    backend = (
        dag.container()
        .from_("golang:alpine3.22")
        .with_exec(["apk", "add", "--no-cache", "build-base", "git"])
        .with_directory("/app", source)
        .with_workdir("/app")
        .with_env_variable("CGO_ENABLED", "1")
        .with_exec(
            [
                "go",
                "build",
                "-buildmode=pie",
                f"-ldflags={ldflags}",
                "-o",
                "/miniflux",
                ".",
            ]
        )
    )

    # Stage 2: Runtime (uses Alpine's built-in nobody:65534)
    runtime = alpine_runtime(
        extra_apk=["ca-certificates", "tzdata"],
        create_user=False,
    )
    runtime = oci_labels(
        runtime,
        title="Miniflux",
        description="Miniflux is a minimalist and opinionated feed reader",
        version=VERSION,
    )
    return (
        runtime.with_file("/usr/bin/miniflux", backend.file("/miniflux"))
        .with_exposed_port(8080)
        .with_env_variable("LISTEN_ADDR", "0.0.0.0:8080")
        .with_user("65534")
        .with_default_args(args=["/usr/bin/miniflux"])
    )
