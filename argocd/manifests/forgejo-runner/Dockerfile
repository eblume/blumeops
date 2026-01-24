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
    # For container builds
    ca-certificates \
    docker-cli

# Verify tools are available
RUN node --version && npm --version && docker --version

# Switch back to non-root user
USER 1000
