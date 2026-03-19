# Grafana Alloy telemetry collector
# Three-stage build: Web UI (Node), server (Go), runtime (Alpine)

ARG CONTAINER_APP_VERSION=1.14.0
ARG ALLOY_VERSION=v${CONTAINER_APP_VERSION}
ARG ALLOY_COMMIT=626a738319812d58ebc25ca6d71651f4925b8b18

FROM node:22-alpine AS ui-build

ARG ALLOY_COMMIT
RUN apk add --no-cache git

RUN mkdir /app && cd /app \
    && git init \
    && git remote add origin https://forge.ops.eblu.me/mirrors/alloy.git \
    && git fetch --depth 1 origin ${ALLOY_COMMIT} \
    && git checkout FETCH_HEAD

WORKDIR /app/internal/web/ui
RUN npm ci
RUN npx tsc -b && npx vite build

FROM golang:1.25-alpine3.22 AS build

ARG ALLOY_VERSION
ARG ALLOY_COMMIT
RUN apk add --no-cache build-base git

RUN mkdir /app && cd /app \
    && git init \
    && git remote add origin https://forge.ops.eblu.me/mirrors/alloy.git \
    && git fetch --depth 1 origin ${ALLOY_COMMIT} \
    && git checkout FETCH_HEAD

WORKDIR /app

# Copy pre-built web UI assets
COPY --from=ui-build /app/internal/web/ui/dist /app/internal/web/ui/dist

ENV CGO_ENABLED=1

# promtail_journal_enabled omitted: requires systemd headers (libsystemd-dev)
# and our k8s deployments read pod logs from the filesystem, not journald
RUN RELEASE_BUILD=1 VERSION=${ALLOY_VERSION} \
    GO_TAGS="netgo embedalloyui" \
    SKIP_UI_BUILD=1 \
    make alloy

FROM alpine:3.22

ARG CONTAINER_APP_VERSION
LABEL org.opencontainers.image.title="Alloy"
LABEL org.opencontainers.image.description="Grafana Alloy is an OpenTelemetry Collector distribution"
LABEL org.opencontainers.image.version="${CONTAINER_APP_VERSION}"
LABEL org.opencontainers.image.source="https://forge.eblu.me/eblume/blumeops"
LABEL org.opencontainers.image.vendor="blumeops"

RUN apk --no-cache add ca-certificates tzdata \
    && addgroup -g 473 alloy \
    && adduser -D -u 473 -G alloy alloy \
    && mkdir -p /var/lib/alloy/data \
    && chown -R alloy:alloy /var/lib/alloy

COPY --from=build --chown=473:473 /app/build/alloy /bin/alloy

ENTRYPOINT ["/bin/alloy"]
ENV ALLOY_DEPLOY_MODE=docker
CMD ["run", "/etc/alloy/config.alloy", "--storage.path=/var/lib/alloy/data"]
