"""UnPoller — UniFi metrics exporter for Prometheus.

Two-stage build: Go backend, Alpine runtime.
Source cloned from forge mirror.
"""

import dagger

from blumeops.containers import (
    alpine_runtime,
    clone_from_forge,
    go_build,
    oci_labels,
)

VERSION = "v3.2.0"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("unpoller", VERSION)

    backend = go_build(
        source,
        "/unpoller",
        ldflags=(
            f"-s -w "
            f"-X main.version={VERSION} "
            f"-X main.builtBy=blumeops "
            f"-X golift.io/version.Version={VERSION} "
            f"-X golift.io/version.Branch=HEAD "
            f"-X golift.io/version.BuildUser=blumeops "
            f"-X golift.io/version.Revision=blumeops-build"
        ),
    )

    runtime = alpine_runtime(
        extra_apk=["ca-certificates", "tzdata"],
        create_user=False,
    )
    runtime = oci_labels(
        runtime,
        title="UnPoller",
        description="UniFi metrics exporter for Prometheus",
        version=VERSION,
    )
    return (
        runtime.with_file("/usr/bin/unpoller", backend.file("/unpoller"))
        .with_exposed_port(9130)
        .with_user("65534")
        .with_default_args(
            args=["/usr/bin/unpoller", "--config", "/etc/unpoller/up.conf"]
        )
    )
