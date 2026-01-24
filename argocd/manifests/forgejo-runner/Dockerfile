FROM code.forgejo.org/forgejo/runner:3.5.1

# Switch to root to install packages
USER root

# The base image is Alpine Linux
# Install tools needed for GitHub Actions and builds
RUN apk add --no-cache \
    # Required for actions/checkout and other Node-based actions
    nodejs \
    npm \
    # Build essentials
    git \
    curl \
    wget \
    jq \
    make \
    gcc \
    g++ \
    musl-dev \
    # For container builds (daemonless, no Docker socket needed)
    buildah \
    podman \
    fuse-overlayfs \
    shadow \
    ca-certificates

# Configure buildah for rootless operation
RUN mkdir -p /etc/containers && \
    echo '[storage]' > /etc/containers/storage.conf && \
    echo 'driver = "overlay"' >> /etc/containers/storage.conf && \
    echo 'runroot = "/tmp/containers-run"' >> /etc/containers/storage.conf && \
    echo 'graphroot = "/tmp/containers-storage"' >> /etc/containers/storage.conf && \
    echo '[storage.options.overlay]' >> /etc/containers/storage.conf && \
    echo 'mount_program = "/usr/bin/fuse-overlayfs"' >> /etc/containers/storage.conf

# Configure registries (allow insecure for local registry)
RUN mkdir -p /etc/containers && \
    echo 'unqualified-search-registries = ["docker.io"]' > /etc/containers/registries.conf && \
    echo '[[registry]]' >> /etc/containers/registries.conf && \
    echo 'location = "registry.tail8d86e.ts.net"' >> /etc/containers/registries.conf && \
    echo 'insecure = true' >> /etc/containers/registries.conf

# Verify tools are available
RUN node --version && npm --version && buildah --version

# Switch back to non-root user
USER 1000
# Built with Buildah
