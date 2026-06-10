"""Tailscale proxy image (containerboot) — native Dagger build.

Builds cmd/tailscale, cmd/tailscaled, and cmd/containerboot from the forge
mirror, mirroring the upstream Dockerfile: Alpine runtime with iptables
(legacy symlinked over the default, per upstream issue #17854), iproute2,
and the /tailscale/run.sh compat symlink.

Consumed by the tailscale-operator ProxyClass on indri's minikube (arm64);
ringtail's ProxyClass uses the -nix tag from default.nix instead.
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

    ldflags = (
        "-w -s"
        f" -X tailscale.com/version.longStamp={semver}"
        f" -X tailscale.com/version.shortStamp={semver}"
    )
    builder = go_build(
        source,
        "/out/tailscale",
        cmd_path="./cmd/tailscale",
        ldflags=ldflags,
    )
    builder = builder.with_exec(
        [
            "go",
            "build",
            f"-ldflags={ldflags}",
            "-o",
            "/out/tailscaled",
            "./cmd/tailscaled",
        ]
    ).with_exec(
        [
            "go",
            "build",
            f"-ldflags={ldflags}",
            "-o",
            "/out/containerboot",
            "./cmd/containerboot",
        ]
    )

    runtime = alpine_runtime(
        extra_apk=["ca-certificates", "iptables", "iproute2", "ip6tables"],
        create_user=False,
    )
    runtime = oci_labels(
        runtime,
        title="Tailscale",
        description="Tailscale containerboot proxy image for the k8s operator",
        version=VERSION,
    )
    return (
        runtime
        # Match upstream Dockerfile: nftables-backed iptables misbehaves in
        # some environments, force the legacy backend (tailscale/tailscale#17854).
        .with_exec(
            [
                "sh",
                "-c",
                "rm /usr/sbin/iptables && ln -s /usr/sbin/iptables-legacy /usr/sbin/iptables"
                " && rm /usr/sbin/ip6tables && ln -s /usr/sbin/ip6tables-legacy /usr/sbin/ip6tables",
            ]
        )
        .with_file(
            "/usr/local/bin/tailscale",
            builder.file("/out/tailscale"),
            permissions=0o555,
        )
        .with_file(
            "/usr/local/bin/tailscaled",
            builder.file("/out/tailscaled"),
            permissions=0o555,
        )
        .with_file(
            "/usr/local/bin/containerboot",
            builder.file("/out/containerboot"),
            permissions=0o555,
        )
        .with_exec(
            [
                "sh",
                "-c",
                "mkdir /tailscale && ln -s /usr/local/bin/containerboot /tailscale/run.sh",
            ]
        )
        .with_entrypoint(["/usr/local/bin/containerboot"])
    )
