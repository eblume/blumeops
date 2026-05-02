"""Valkey — native Dagger build.

Alpine 3.22 base with the `valkey` apk package (8.1.x — Redis-compatible).
Mirrors `docker.io/valkey/valkey:8.1-alpine`, used by paperless and immich
as a cache/queue sidecar.
"""

import dagger
from dagger import dag

from blumeops.containers import oci_labels

# Alpine 3.22 ships valkey 8.1.6-r0. Alpine 3.23 jumps to 9.0 — hold on 3.22
# to keep this a 1:1 swap for the upstream `valkey:8.1-alpine` image.
VERSION = "8.1.6-r0"

ALPINE_BASE = "alpine:3.22"


async def build(src: dagger.Directory) -> dagger.Container:
    ctr = (
        dag.container()
        .from_(ALPINE_BASE)
        .with_exec(["apk", "add", "--no-cache", f"valkey={VERSION}"])
        .with_exec(["mkdir", "-p", "/data"])
        .with_exec(["chown", "valkey:valkey", "/data"])
        .with_workdir("/data")
        .with_exposed_port(6379)
        .with_user("valkey")
        .with_default_args(
            args=[
                "valkey-server",
                "--bind",
                "0.0.0.0",
                "--protected-mode",
                "no",
                "--dir",
                "/data",
            ]
        )
    )
    return oci_labels(
        ctr,
        title="Valkey",
        description="Valkey high-performance key/value datastore (Redis-compatible)",
        version=VERSION,
    )
