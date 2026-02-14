# Minimal kubectl container
# Multi-arch build: downloads correct binary for target platform

FROM alpine:3.22 AS downloader

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.34.4

RUN apk add --no-cache curl && \
    # Detect architecture - use TARGETARCH if set, otherwise detect from uname
    if [ -n "$TARGETARCH" ]; then \
        ARCH="$TARGETARCH"; \
    else \
        UNAME_ARCH=$(uname -m); \
        case "$UNAME_ARCH" in \
            aarch64|arm64) ARCH="arm64" ;; \
            x86_64) ARCH="amd64" ;; \
            *) echo "Unsupported architecture: $UNAME_ARCH"; exit 1 ;; \
        esac; \
    fi && \
    echo "Downloading kubectl for $ARCH..." && \
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" && \
    chmod +x kubectl

FROM alpine:3.22

COPY --from=downloader /kubectl /usr/local/bin/kubectl

# Add ca-certificates for HTTPS connections and bash for scripts
RUN apk add --no-cache ca-certificates bash

# Run as non-root
RUN adduser -D -u 1000 kubectl
USER kubectl

ENTRYPOINT ["kubectl"]
