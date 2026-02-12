# Forgejo Actions Job Execution Image
#
# This image is used as the job execution environment for Forgejo Actions.
# The host runner daemon creates containers from this image to run workflow steps.
#
# Build logic (container images, docs site) runs inside Dagger containers,
# so this image only needs: git, Dagger CLI, ArgoCD CLI, uv, and basic tools.
#
# Usage: Configure runner with label like:
#   docker:docker://registry.ops.eblu.me/blumeops/forgejo-runner:latest

FROM debian:bookworm-slim

ARG TARGETARCH

# Install base dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Python package runner for towncrier)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    && mv /root/.local/bin/uvx /usr/local/bin/uvx

# Install argocd CLI (for syncing apps from workflows)
RUN ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && curl -fsSL -o /usr/local/bin/argocd \
    "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${ARCH}" \
    && chmod +x /usr/local/bin/argocd \
    && argocd version --client

# Install Dagger CLI (for running Dagger CI pipelines)
ARG DAGGER_VERSION=0.19.11
RUN ARCH="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && curl -fsSL -o /tmp/dagger.tar.gz \
    "https://dl.dagger.io/dagger/releases/${DAGGER_VERSION}/dagger_v${DAGGER_VERSION}_linux_${ARCH}.tar.gz" \
    && tar -xzf /tmp/dagger.tar.gz -C /usr/local/bin dagger \
    && rm /tmp/dagger.tar.gz \
    && dagger version

# Install flyctl (for Fly.io cache purge after docs deploy)
RUN curl -L https://fly.io/install.sh | sh \
    && mv /root/.fly/bin/flyctl /usr/local/bin/fly \
    && rm -rf /root/.fly

# Default to bash
CMD ["/bin/bash"]
