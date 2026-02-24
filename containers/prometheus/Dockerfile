# Prometheus monitoring system
# Three-stage build: Web UI (Node), binaries (Go), runtime (Alpine)

ARG CONTAINER_APP_VERSION=v3.9.1
ARG PROMETHEUS_VERSION=${CONTAINER_APP_VERSION}

FROM node:22-alpine AS ui-build

ARG PROMETHEUS_VERSION
RUN apk add --no-cache git bash

RUN git clone --depth 1 --branch ${PROMETHEUS_VERSION} \
    https://github.com/prometheus/prometheus.git /app

WORKDIR /app/web/ui

# Install workspace dependencies (mantine-ui, modules)
RUN npm ci

# Install legacy React app dependencies (separated from workspaces upstream)
RUN cd react-app && npm ci

# Build all UI components: modules, react-app, mantine-ui → static/
RUN npm run build

FROM golang:alpine3.22 AS build

ARG PROMETHEUS_VERSION
RUN apk add --no-cache build-base git bash

RUN git clone --depth 1 --branch ${PROMETHEUS_VERSION} \
    https://github.com/prometheus/prometheus.git /app

WORKDIR /app

# Copy pre-built UI assets
COPY --from=ui-build /app/web/ui/static /app/web/ui/static

# Generate embed.go with //go:embed directives for gzipped assets
RUN scripts/compress_assets.sh

ENV CGO_ENABLED=0

RUN go build -tags netgo,builtinassets \
    -ldflags="-w -s -X github.com/prometheus/common/version.Version=${PROMETHEUS_VERSION} \
    -X github.com/prometheus/common/version.Branch=HEAD \
    -X github.com/prometheus/common/version.BuildUser=blumeops \
    -X github.com/prometheus/common/version.Revision=blumeops-build" \
    -o /bin/prometheus ./cmd/prometheus

RUN go build -tags netgo,builtinassets \
    -ldflags="-w -s -X github.com/prometheus/common/version.Version=${PROMETHEUS_VERSION}" \
    -o /bin/promtool ./cmd/promtool

FROM alpine:3.22

LABEL org.opencontainers.image.title=Prometheus
LABEL org.opencontainers.image.description="Prometheus monitoring system and time series database"
LABEL org.opencontainers.image.source=https://github.com/prometheus/prometheus

RUN apk add --no-cache ca-certificates tzdata

RUN mkdir -p /prometheus /etc/prometheus \
 && chown -R 65534:65534 /prometheus /etc/prometheus

COPY --from=build /bin/prometheus /usr/bin/prometheus
COPY --from=build /bin/promtool /usr/bin/promtool
COPY --from=build /app/documentation/examples/prometheus.yml /etc/prometheus/prometheus.yml

EXPOSE 9090
VOLUME ["/prometheus"]

USER 65534
ENTRYPOINT ["/usr/bin/prometheus"]
CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus"]
