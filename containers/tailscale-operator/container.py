"""Tailscale Kubernetes operator — native Dagger build.

Single Go binary (cmd/k8s-operator) from the forge mirror, mirroring
upstream's build_docker.sh mkctr recipe: binary at /usr/local/bin/operator,
go tags ts_kube + ts_package_container, version stamps in ldflags.

Consumed by the tailscale-operator app on indri's minikube (arm64); the
ringtail app uses the -nix tag from default.nix instead.
"""

import dagger

from blumeops.containers import (
    alpine_runtime,
    clone_from_forge,
    go_build,
    oci_labels,
)

VERSION = "v1.94.2"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("tailscale", VERSION)
    semver = VERSION.removeprefix("v")

    builder = go_build(
        source,
        "/out/operator",
        cmd_path="./cmd/k8s-operator",
        tags="ts_kube,ts_package_container",
        ldflags=(
            "-w -s"
            f" -X tailscale.com/version.longStamp={semver}"
            f" -X tailscale.com/version.shortStamp={semver}"
        ),
    )

    # Upstream runs the operator as root on a minimal base; only CA certs
    # are needed at runtime (operator talks to the k8s API and Tailscale
    # control plane over HTTPS).
    runtime = alpine_runtime(extra_apk=["ca-certificates"], create_user=False)
    runtime = oci_labels(
        runtime,
        title="Tailscale Kubernetes Operator",
        description="Tailscale operator for Kubernetes Ingress/egress proxies",
        version=VERSION,
    )
    return runtime.with_file(
        "/usr/local/bin/operator",
        builder.file("/out/operator"),
        permissions=0o555,
    ).with_entrypoint(["/usr/local/bin/operator"])
