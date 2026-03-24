# Prowler CIS scanner — slim build for Kubernetes provider only
# Strips PowerShell (M365), Trivy (IaC), and dashboard dependencies from upstream
ARG CONTAINER_APP_VERSION=5.22.0

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
LABEL org.opencontainers.image.description="Prowler CIS scanner (Kubernetes provider)"

RUN addgroup --gid 1000 prowler \
    && adduser --uid 1000 --gid 1000 --disabled-password --gecos "" prowler

COPY --from=build /opt/prowler /opt/prowler

ENV PATH="/opt/prowler/bin:${PATH}"

USER prowler
WORKDIR /home/prowler

ENTRYPOINT ["prowler"]
