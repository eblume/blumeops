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

# Install Node.js 20.x (required for actions/checkout@v4 and other GitHub Actions)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for container builds - daemon accessed via socket mount)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Default to bash
CMD ["/bin/bash"]
