# kube-state-metrics — Kubernetes state metrics exporter
# Two-stage build: Go binary, Alpine runtime

ARG CONTAINER_APP_VERSION=2.18.0
ARG KSM_VERSION=v${CONTAINER_APP_VERSION}
ARG KSM_COMMIT=ab562f78ebf4cb97cc2f87c1235e457076035d16

FROM golang:alpine3.22 AS build

ARG KSM_VERSION
ARG KSM_COMMIT
RUN apk add --no-cache build-base git

RUN mkdir /app && cd /app \
    && git init \
    && git remote add origin https://forge.ops.eblu.me/mirrors/kube-state-metrics.git \
    && git fetch --depth 1 origin ${KSM_COMMIT} \
    && git checkout FETCH_HEAD

WORKDIR /app

ENV CGO_ENABLED=0

RUN go build \
    -o /kube-state-metrics \
    -ldflags "-s -w -X k8s.io/kube-state-metrics/v2/pkg/version.Version=${KSM_VERSION}"

FROM alpine:3.22

ARG CONTAINER_APP_VERSION
LABEL org.opencontainers.image.title="kube-state-metrics"
LABEL org.opencontainers.image.description="Generates metrics about the state of Kubernetes objects"
LABEL org.opencontainers.image.version="${CONTAINER_APP_VERSION}"
LABEL org.opencontainers.image.source="https://forge.eblu.me/eblume/blumeops"
LABEL org.opencontainers.image.vendor="blumeops"

RUN apk --no-cache add ca-certificates tzdata

COPY --from=build /kube-state-metrics /usr/bin/kube-state-metrics

EXPOSE 8080 8081

USER 65534
ENTRYPOINT ["/usr/bin/kube-state-metrics"]
