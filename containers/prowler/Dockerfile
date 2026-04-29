# Prowler CIS scanner — slim build for Kubernetes, image, and IaC providers
# Strips PowerShell (M365) and dashboard dependencies from upstream
# Includes Trivy for image vulnerability and IaC scanning
ARG CONTAINER_APP_VERSION=5.23.0

FROM python:3.12-slim-bookworm AS build

ARG CONTAINER_APP_VERSION

RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 --branch ${CONTAINER_APP_VERSION} \
        https://forge.ops.eblu.me/mirrors/prowler.git .

# Install prowler into a virtualenv so we can copy it cleanly
RUN python -m venv /opt/prowler \
    && /opt/prowler/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/prowler/bin/pip install --no-cache-dir .

# ---

FROM python:3.12-slim-bookworm

ARG CONTAINER_APP_VERSION

LABEL org.opencontainers.image.title="prowler"
LABEL org.opencontainers.image.version="${CONTAINER_APP_VERSION}"
LABEL org.opencontainers.image.source="https://forge.eblu.me/eblume/blumeops"
LABEL org.opencontainers.image.vendor="blumeops"
LABEL org.opencontainers.image.description="Prowler scanner (Kubernetes, image, IaC providers)"

ARG TRIVY_VERSION=0.69.2

RUN ARCH=$(dpkg --print-architecture) \
    && case "$ARCH" in \
        amd64) TRIVY_ARCH="Linux-64bit" ;; \
        arm64) TRIVY_ARCH="Linux-ARM64" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac \
    && apt-get update && apt-get install -y --no-install-recommends wget ca-certificates \
    && wget -q "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_${TRIVY_ARCH}.tar.gz" -O /tmp/trivy.tar.gz \
    && tar xzf /tmp/trivy.tar.gz -C /usr/local/bin trivy \
    && mv /usr/local/bin/trivy /usr/local/bin/trivy.real \
    && chmod +x /usr/local/bin/trivy.real \
    && rm /tmp/trivy.tar.gz \
    && apt-get purge -y wget && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

# Shim: Prowler's IaC provider invokes `trivy fs` directly with no
# --ignorefile flag, so any TRIVY_IGNOREFILE the user sets is ignored.
# This wrapper injects --ignorefile when the env var points at a real
# file and the invocation is `trivy fs ...`. Other subcommands and
# global-only invocations (--version, --help) pass through unchanged.
# TODO(upstream): contribute --ignorefile plumbing to prowler-cloud/prowler
# iac_provider.py so this shim isn't necessary.
RUN printf '%s\n' \
        '#!/bin/sh' \
        'if [ "${1:-}" = "fs" ] && [ -n "${TRIVY_IGNOREFILE:-}" ] && [ -f "${TRIVY_IGNOREFILE}" ]; then' \
        '    shift' \
        '    exec /usr/local/bin/trivy.real fs --ignorefile "${TRIVY_IGNOREFILE}" "$@"' \
        'fi' \
        'exec /usr/local/bin/trivy.real "$@"' \
        > /usr/local/bin/trivy \
    && chmod +x /usr/local/bin/trivy

RUN addgroup --gid 1000 prowler \
    && adduser --uid 1000 --gid 1000 --disabled-password --gecos "" prowler \
    && mkdir -p /tmp/.cache/trivy && chown prowler:prowler /tmp/.cache/trivy

COPY --from=build /opt/prowler /opt/prowler

ENV PATH="/opt/prowler/bin:${PATH}"
ENV TRIVY_CACHE_DIR="/tmp/.cache/trivy"

USER prowler
WORKDIR /home/prowler

ENTRYPOINT ["prowler"]
