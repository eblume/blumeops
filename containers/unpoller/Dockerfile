# UnPoller — UniFi metrics exporter for Prometheus
# Two-stage build: Go compilation, then minimal Alpine runtime

ARG CONTAINER_APP_VERSION=v2.34.0

FROM golang:alpine3.22 AS build

ARG CONTAINER_APP_VERSION
RUN apk add --no-cache git

RUN git clone --depth 1 --branch ${CONTAINER_APP_VERSION} \
    https://forge.ops.eblu.me/mirrors/unpoller.git /app

WORKDIR /app

ENV CGO_ENABLED=0

RUN go build -ldflags="-s -w \
    -X main.version=${CONTAINER_APP_VERSION} \
    -X main.builtBy=blumeops \
    -X golift.io/version.Version=${CONTAINER_APP_VERSION} \
    -X golift.io/version.Branch=HEAD \
    -X golift.io/version.BuildUser=blumeops \
    -X golift.io/version.Revision=blumeops-build" \
    -o /bin/unpoller .

FROM alpine:3.22

ARG CONTAINER_APP_VERSION
LABEL org.opencontainers.image.title="UnPoller"
LABEL org.opencontainers.image.description="UniFi metrics exporter for Prometheus"
LABEL org.opencontainers.image.version="${CONTAINER_APP_VERSION}"
LABEL org.opencontainers.image.source="https://forge.eblu.me/eblume/blumeops"
LABEL org.opencontainers.image.vendor="blumeops"

RUN apk add --no-cache ca-certificates tzdata

COPY --from=build /bin/unpoller /usr/bin/unpoller

EXPOSE 9130
USER 65534:65534
ENTRYPOINT ["/usr/bin/unpoller"]
CMD ["--config", "/etc/unpoller/up.conf"]
