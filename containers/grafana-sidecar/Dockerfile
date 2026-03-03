# Grafana dashboard sidecar - watches ConfigMaps and syncs into Grafana
# Two-stage build: Python venv (builder), runtime (Alpine)

ARG CONTAINER_APP_VERSION=1.28.0

FROM python:3.12-alpine3.22 AS base

FROM base AS builder
ARG CONTAINER_APP_VERSION
WORKDIR /app
RUN apk add --no-cache git gcc musl-dev
RUN git clone --depth 1 --branch ${CONTAINER_APP_VERSION} \
    https://forge.ops.eblu.me/mirrors/kiwigrid-grafana-sidecar.git /tmp/k8s-sidecar
RUN python -m venv .venv && \
    .venv/bin/pip install --no-cache-dir -U pip setuptools && \
    .venv/bin/pip install --no-cache-dir -r /tmp/k8s-sidecar/src/requirements.txt && \
    cp /tmp/k8s-sidecar/src/*.py /app/ && \
    find /app/.venv \( -type d -a -name test -o -name tests \) \
      -o \( -type f -a -name '*.pyc' -o -name '*.pyo' \) -exec rm -rf '{}' \+

FROM base

LABEL org.opencontainers.image.title="Grafana Sidecar"
LABEL org.opencontainers.image.description="K8s sidecar to sync ConfigMap dashboards into Grafana"
LABEL org.opencontainers.image.source="https://github.com/kiwigrid/k8s-sidecar"

ENV PYTHONUNBUFFERED=1
WORKDIR /app
COPY --from=builder /app /app
ENV PATH="/app/.venv/bin:$PATH"

USER 65534:65534
CMD ["python", "-u", "/app/sidecar.py"]
