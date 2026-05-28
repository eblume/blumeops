"""Valkey — native Dagger build (arm64, indri).

Alpine 3.22 base with the `valkey` apk package (8.1.x — Redis-compatible).
Used by paperless (sidecar) on indri. immich on ringtail uses the
nix-built amd64 variant from `default.nix` in this directory.
"""

import dagger
from dagger import dag

from blumeops.containers import oci_labels

# Alpine 3.22 currently ships valkey 8.1.7-r0. Alpine 3.23 jumps to 9.0 —
# hold on 3.22 to keep this aligned with the 8.1 line.
VERSION = "8.1.7"
ALPINE_PIN = "8.1.7-r0"

ALPINE_BASE = "alpine:3.22"


async def build(src: dagger.Directory) -> dagger.Container:
    ctr = (
        dag.container()
        .from_(ALPINE_BASE)
        .with_exec(["apk", "add", "--no-cache", f"valkey={ALPINE_PIN}"])
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
