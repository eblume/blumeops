# Forgejo Actions Job Execution Image
#
# This image is used as the job execution environment for Forgejo Actions.
# The host runner daemon creates containers from this image to run workflow steps.
#
# Includes: Node.js (for GitHub Actions), Docker CLI, git, and common CI tools.
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
    gnupg \
    lsb-release \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 24.x LTS (required for actions/checkout@v4 and Quartz builds)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for container builds - daemon accessed via socket mount)
# and skopeo (for pushing images to zot registry - Docker 27 manifest compat issues)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin skopeo \
    && rm -rf /var/lib/apt/lists/*

# Install uv (Python package runner for towncrier)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && mv /root/.local/bin/uv /usr/local/bin/uv \
    && mv /root/.local/bin/uvx /usr/local/bin/uvx

# Install argocd CLI (for syncing apps from workflows)
# Use dpkg --print-architecture as fallback since TARGETARCH may be empty in single-platform builds
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

# Default to bash
CMD ["/bin/bash"]
