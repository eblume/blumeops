"""Navidrome music server — native Dagger build.

Three-stage build: Node (UI), Go (backend with taglib + FTS5), Alpine (runtime).
Source cloned from forge mirror.
"""

import dagger

from blumeops.containers import (
    alpine_runtime,
    clone_from_forge,
    go_build,
    node_build,
    oci_labels,
)

VERSION = "v0.61.1"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("navidrome", VERSION)

    # Stage 1: Build UI assets
    ui = node_build(source, "ui")

    # Stage 2: Build Go backend with CGO (taglib) and FTS5
    backend = go_build(
        source.with_directory("ui/build", ui.directory("/app/ui/build")),
        "/navidrome",
        tags="netgo,sqlite_fts5",
        ldflags=f"-w -s -X github.com/navidrome/navidrome/consts.gitTag={VERSION}",
        cgo_enabled=True,
        extra_apk=["taglib-dev", "zlib-dev"],
    )

    # Stage 3: Runtime
    runtime = alpine_runtime(
        extra_apk=["ca-certificates", "tzdata", "taglib", "ffmpeg"],
        uid=1000,
        gid=1000,
        username="navidrome",
    )
    runtime = oci_labels(
        runtime,
        title="Navidrome",
        description="Navidrome is a self-hosted music server and streamer",
        version=VERSION,
    )
    return (
        runtime.with_file("/usr/bin/navidrome", backend.file("/navidrome"))
        .with_exposed_port(4533)
        .with_user("1000")
        .with_default_args(args=["/usr/bin/navidrome"])
    )
