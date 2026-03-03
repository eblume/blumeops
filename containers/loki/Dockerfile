# Grafana Loki log aggregation system
# Two-stage build: Go binary, Alpine runtime

ARG CONTAINER_APP_VERSION=3.6.5
ARG LOKI_VERSION=v${CONTAINER_APP_VERSION}

FROM golang:alpine3.22 AS build

ARG LOKI_VERSION
RUN apk add --no-cache build-base git

RUN git clone --depth 1 --branch ${LOKI_VERSION} \
    https://forge.ops.eblu.me/mirrors/loki.git /go/src/app

WORKDIR /go/src/app
ENV CGO_ENABLED=0

RUN go build -tags netgo \
    -ldflags="-w -s \
      -X github.com/grafana/loki/v3/pkg/util/build.Version=${LOKI_VERSION} \
      -X github.com/grafana/loki/v3/pkg/util/build.Branch=HEAD \
      -X github.com/grafana/loki/v3/pkg/util/build.BuildUser=blumeops \
      -X github.com/grafana/loki/v3/pkg/util/build.Revision=blumeops-build" \
    -o /bin/loki ./cmd/loki

FROM alpine:3.22

LABEL org.opencontainers.image.title=Loki
LABEL org.opencontainers.image.description="Grafana Loki log aggregation system"
LABEL org.opencontainers.image.source=https://github.com/grafana/loki

RUN apk add --no-cache ca-certificates tzdata
RUN mkdir -p /loki && chown 10001:10001 /loki

USER 10001
COPY --from=build /bin/loki /usr/bin/loki
EXPOSE 3100
ENTRYPOINT ["/usr/bin/loki"]
