"""Transmission BitTorrent daemon — native Dagger build.

Alpine-based container with transmission-daemon from edge repo.
Includes start.sh for dynamic PUID/PGID user creation at runtime.
"""

import dagger
from dagger import dag

from blumeops.containers import oci_labels

VERSION = "4.1.1-r1"

ALPINE_BASE = "alpine:3.23"


async def build(src: dagger.Directory) -> dagger.Container:
    ctr = (
        dag.container()
        .from_(ALPINE_BASE)
        # Transmission 4.1.x is only in edge community
        .with_exec(
            [
                "apk",
                "add",
                "--no-cache",
                "--repository=https://dl-cdn.alpinelinux.org/alpine/edge/community",
                f"transmission-daemon={VERSION}",
                f"transmission-cli={VERSION}",
                f"transmission-remote={VERSION}",
            ]
        )
        .with_exec(["apk", "add", "--no-cache", "bash", "curl", "tzdata", "su-exec"])
        .with_exec(
            ["mkdir", "-p", "/config", "/downloads/complete", "/downloads/incomplete"]
        )
        .with_file("/start.sh", src.file("containers/transmission/start.sh"))
        .with_exec(["chmod", "+x", "/start.sh"])
        .with_exposed_port(9091)
        .with_exposed_port(51413, protocol=dagger.NetworkProtocol.TCP)
        .with_exposed_port(51413, protocol=dagger.NetworkProtocol.UDP)
        .with_default_args(args=["/start.sh"])
    )
    return oci_labels(
        ctr,
        title="Transmission",
        description="Transmission BitTorrent daemon",
        version=VERSION,
    )
