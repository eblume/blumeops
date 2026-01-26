# Forgejo Actions Runner - Containerized
#
# A containerized runner capable of building containers via Docker socket mount.
# Part of the runner ratcheting plan (Phase 1+).
#
# Build:
#   docker build -t registry.ops.eblu.me/blumeops/forgejo-runner:v1.0.0 .
#
# Run (Phase 1 - Docker on indri):
#   docker run -d \
#     --name forgejo-runner \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     -e FORGEJO_URL=https://forge.ops.eblu.me \
#     -e RUNNER_TOKEN=<token> \
#     -e RUNNER_NAME=indri-docker-runner \
#     registry.ops.eblu.me/blumeops/forgejo-runner:v1.0.0
#
# The runner registers itself on first start and persists state in /data.

FROM debian:bookworm-slim

# Forgejo runner version - check https://code.forgejo.org/forgejo/runner/releases
ARG RUNNER_VERSION=6.3.1
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

# Install Docker CLI (not daemon - we mount the socket)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Install forgejo-runner
RUN ARCH=$(case "${TARGETARCH}" in "amd64") echo "amd64";; "arm64") echo "arm64";; *) echo "amd64";; esac) \
    && curl -fsSL "https://code.forgejo.org/forgejo/runner/releases/download/v${RUNNER_VERSION}/forgejo-runner-${RUNNER_VERSION}-linux-${ARCH}.xz" -o /tmp/runner.xz \
    && xz -d /tmp/runner.xz \
    && mv /tmp/runner /usr/local/bin/forgejo-runner \
    && chmod +x /usr/local/bin/forgejo-runner

# Create data directory for runner state
RUN mkdir -p /data
WORKDIR /data

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy runner config template
COPY config.yaml /etc/forgejo-runner/config.yaml

ENTRYPOINT ["/entrypoint.sh"]
