# Build forgejo-runner from source
# Source: https://forge.tail8d86e.ts.net/eblume/forgejo-runner (mirror of code.forgejo.org/forgejo/runner)

FROM golang:1.24-alpine AS builder

ARG FORGEJO_RUNNER_VERSION=v3.5.1

RUN apk add --no-cache git make build-base

WORKDIR /src
RUN git clone --depth 1 --branch ${FORGEJO_RUNNER_VERSION} \
    https://forge.tail8d86e.ts.net/eblume/forgejo-runner.git .

RUN make clean && make build

# Runtime image
FROM alpine:3.21

# Create runner user with proper passwd entry (required by buildah)
RUN addgroup -g 1000 runner && \
    adduser -D -u 1000 -G runner -h /data runner

# Install runtime dependencies
RUN apk add --no-cache \
    # Required for actions/checkout and other Node-based actions
    nodejs \
    npm \
    # Core tools
    git \
    bash \
    curl \
    wget \
    jq \
    # Build essentials
    make \
    gcc \
    g++ \
    musl-dev \
    # For container builds (daemonless, no Docker socket needed)
    buildah \
    podman \
    fuse-overlayfs \
    ca-certificates

# Copy runner binary from builder
COPY --from=builder /src/forgejo-runner /bin/forgejo-runner

# Configure buildah for rootless operation
RUN mkdir -p /etc/containers && \
    printf '[storage]\ndriver = "overlay"\nrunroot = "/tmp/containers-run"\ngraphroot = "/tmp/containers-storage"\n[storage.options.overlay]\nmount_program = "/usr/bin/fuse-overlayfs"\n' \
    > /etc/containers/storage.conf

# Configure registries (allow insecure for local registry)
RUN printf 'unqualified-search-registries = ["docker.io"]\n[[registry]]\nlocation = "registry.tail8d86e.ts.net"\ninsecure = true\n' \
    > /etc/containers/registries.conf

# Verify tools are available
RUN node --version && npm --version && buildah --version && /bin/forgejo-runner --version

ENV HOME=/data
WORKDIR /data
USER runner

CMD ["/bin/forgejo-runner"]
