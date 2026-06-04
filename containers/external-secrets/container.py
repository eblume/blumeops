"""External Secrets Operator — native Dagger build.

Two-stage build: Go binary (all providers), Alpine runtime.
Source cloned from forge mirror.

A single binary serves as the controller, webhook, and cert-controller; the
Deployments select the role via a subcommand passed in `args:`, so the image
ENTRYPOINT must be the binary itself (matching upstream's distroless image).
"""

import dagger

from blumeops.containers import (
    alpine_runtime,
    clone_from_forge,
    go_build,
    oci_labels,
)

VERSION = "v2.2.0"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("external-secrets", VERSION)

    # Upstream `make build` compiles every secret provider into a single
    # static binary (`-tags all_providers`, CGO disabled). Mirror that so the
    # local image is functionally identical to ghcr.io/.../external-secrets.
    backend = go_build(
        source,
        "/external-secrets",
        tags="all_providers",
    )

    runtime = alpine_runtime(
        extra_apk=["ca-certificates"],
        create_user=False,
    )
    runtime = oci_labels(
        runtime,
        title="External Secrets Operator",
        description=(
            "Kubernetes operator that integrates external secret management systems"
        ),
        version=VERSION,
    )
    return (
        runtime.with_file("/bin/external-secrets", backend.file("/external-secrets"))
        .with_user("65534")
        .with_entrypoint(["/bin/external-secrets"])
    )
