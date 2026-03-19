# Network connectivity test container for blumeops CI/CD debugging
#
# This container tests connectivity to tailnet services from various environments:
# - Docker on indri (during CI build)
# - Minikube pods (manual testing)

ARG CONTAINER_APP_VERSION=0.1.0

FROM alpine:3.22

ARG CONTAINER_APP_VERSION
LABEL org.opencontainers.image.title="nettest"
LABEL org.opencontainers.image.description="Network connectivity test container for CI/CD debugging"
LABEL org.opencontainers.image.version="${CONTAINER_APP_VERSION}"
LABEL org.opencontainers.image.source="https://forge.eblu.me/eblume/blumeops"
LABEL org.opencontainers.image.vendor="blumeops"

RUN apk add --no-cache \
    curl \
    ca-certificates \
    jq \
    bind-tools

COPY test-connectivity.sh /test-connectivity.sh
RUN chmod +x /test-connectivity.sh

ENTRYPOINT ["/test-connectivity.sh"]
