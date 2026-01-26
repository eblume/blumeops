# Minimal kubectl container
# Multi-arch build: downloads correct binary for target platform

FROM alpine:3.21 AS downloader

ARG TARGETARCH
ARG KUBECTL_VERSION=v1.34.1

RUN apk add --no-cache curl && \
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" && \
    chmod +x kubectl

FROM alpine:3.21

COPY --from=downloader /kubectl /usr/local/bin/kubectl

# Add ca-certificates for HTTPS connections and bash for scripts
RUN apk add --no-cache ca-certificates bash

# Run as non-root
RUN adduser -D -u 1000 kubectl
USER kubectl

ENTRYPOINT ["kubectl"]
