"""Kiwix content server — native Dagger build.

Downloads pre-built kiwix-tools binary from the Kiwix mirror.
Multi-arch support (aarch64, x86_64) via platform detection.
"""

import dagger

from blumeops.containers import alpine_runtime, oci_labels

VERSION = "3.8.2"

MIRROR = "http://mirror.download.kiwix.org/release/kiwix-tools"


async def build(src: dagger.Directory) -> dagger.Container:
    runtime = alpine_runtime(
        extra_apk=["dumb-init", "curl"],
        uid=1000,
        gid=1000,
        username="kiwix",
    )

    # Download and install the pre-built binary for the target platform
    runtime = runtime.with_exec(
        [
            "sh",
            "-c",
            f"ARCH=$(uname -m) && "
            f'case "$ARCH" in aarch64|arm64) ARCH=aarch64;; x86_64) ARCH=x86_64;; *) echo "Unsupported: $ARCH"; exit 1;; esac && '
            f'curl -fsSL "{MIRROR}/kiwix-tools_linux-$ARCH-{VERSION}.tar.gz" | tar -xz -C /usr/local/bin/ --strip-components 1',
        ]
    ).with_exec(["apk", "del", "curl"])

    runtime = oci_labels(
        runtime,
        title="kiwix-serve",
        description="Kiwix content server for offline ZIM files",
        version=VERSION,
    )

    return (
        runtime.with_exposed_port(80)
        .with_user("1000")
        .with_entrypoint(["/usr/bin/dumb-init", "--"])
        .with_default_args(
            args=[
                "/bin/sh",
                "-c",
                "echo 'Use: kiwix-serve [options] <zim-files>' && kiwix-serve --help",
            ]
        )
    )
