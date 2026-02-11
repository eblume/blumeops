# Network connectivity test container for blumeops CI/CD debugging
#
# This container tests connectivity to tailnet services from various environments:
# - Docker on indri (during CI build)
# - Minikube pods (manual testing)

FROM alpine:3.21

RUN apk add --no-cache \
    curl \
    ca-certificates \
    jq \
    bind-tools

COPY test-connectivity.sh /test-connectivity.sh
RUN chmod +x /test-connectivity.sh

ENTRYPOINT ["/test-connectivity.sh"]
