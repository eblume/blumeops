"""Forgejo Actions job execution image — native Dagger build.

The forgejo-runner daemon creates containers from this image to run
workflow steps. Contains the tools workflows reach for: git, Docker CLI,
Node.js (for JavaScript Actions), Dagger CLI, ArgoCD CLI, uv, yq, flyctl.

VERSION tracks the Dagger CLI version, the primary build tool.
"""

import dagger

from blumeops.containers import alpine_runtime, oci_labels

VERSION = "0.20.6"


async def build(src: dagger.Directory) -> dagger.Container:
    # Map `uname -m` to the arch suffix each upstream uses.
    arch_setup = (
        'ARCH_UNAME="$(uname -m)"; '
        'case "$ARCH_UNAME" in '
        "  x86_64) ARCH=amd64 ;; "
        "  aarch64) ARCH=arm64 ;; "
        '  *) echo "unsupported arch: $ARCH_UNAME" >&2; exit 1 ;; '
        "esac; "
    )

    runtime = alpine_runtime(
        extra_apk=[
            "bash",
            "ca-certificates",
            "curl",
            "docker-cli",
            "git",
            "gnupg",
            "jq",
            "nodejs",
            "npm",
            "tzdata",
        ],
        create_user=False,
    )
    runtime = oci_labels(
        runtime,
        title="Runner Job Image",
        description="Forgejo Actions job execution environment",
        version=VERSION,
    )

    install_tools = (
        arch_setup
        + "set -eux; "
        # Dagger CLI (pinned)
        + f'curl -fsSL -o /tmp/dagger.tar.gz "https://dl.dagger.io/dagger/releases/{VERSION}/dagger_v{VERSION}_linux_${{ARCH}}.tar.gz"; '
        + "tar -xzf /tmp/dagger.tar.gz -C /usr/local/bin dagger; "
        + "rm /tmp/dagger.tar.gz; "
        + "dagger version; "
        # ArgoCD CLI (latest — matches cluster server version over time)
        + 'curl -fsSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}"; '
        + "chmod +x /usr/local/bin/argocd; "
        + "argocd version --client; "
        # yq (latest)
        + 'curl -fsSL -o /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}"; '
        + "chmod +x /usr/local/bin/yq; "
        + "yq --version; "
        # uv / uvx (latest; musl target auto-selected by installer)
        + "curl -LsSf https://astral.sh/uv/install.sh "
        + '| env UV_INSTALL_DIR=/usr/local/bin UV_UNMANAGED_INSTALL="/usr/local/bin" sh; '
        + "uv --version; "
        # flyctl (latest)
        + "curl -L https://fly.io/install.sh | sh; "
        + "mv /root/.fly/bin/flyctl /usr/local/bin/fly; "
        + "rm -rf /root/.fly; "
        + "fly version"
    )

    return runtime.with_exec(["sh", "-c", install_tools]).with_default_args(
        args=["/bin/bash"]
    )
