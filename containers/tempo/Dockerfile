# Grafana Tempo distributed tracing backend
# Two-stage build: Go binary, Alpine runtime

ARG CONTAINER_APP_VERSION=2.10.3
ARG TEMPO_VERSION=v${CONTAINER_APP_VERSION}

FROM golang:alpine3.22 AS build

ARG TEMPO_VERSION
RUN apk add --no-cache build-base git

RUN git clone --depth 1 --branch ${TEMPO_VERSION} \
    https://forge.ops.eblu.me/mirrors/tempo.git /go/src/app

WORKDIR /go/src/app
ENV CGO_ENABLED=0

RUN go build -mod vendor \
    -ldflags="-w -s \
      -X main.Version=${TEMPO_VERSION} \
      -X main.Branch=HEAD \
      -X main.Revision=blumeops-build" \
    -o /bin/tempo ./cmd/tempo

FROM alpine:3.22

ARG CONTAINER_APP_VERSION
LABEL org.opencontainers.image.title="Tempo"
LABEL org.opencontainers.image.description="Grafana Tempo distributed tracing backend"
LABEL org.opencontainers.image.version="${CONTAINER_APP_VERSION}"
LABEL org.opencontainers.image.source="https://forge.eblu.me/eblume/blumeops"
LABEL org.opencontainers.image.vendor="blumeops"

RUN apk add --no-cache ca-certificates tzdata
RUN mkdir -p /var/tempo && chown 10001:10001 /var/tempo

USER 10001
COPY --from=build /bin/tempo /usr/bin/tempo
EXPOSE 3200 4317 4318 9095
ENTRYPOINT ["/usr/bin/tempo"]
