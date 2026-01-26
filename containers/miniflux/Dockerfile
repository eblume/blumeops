# Miniflux RSS feed reader
# Based on upstream packaging/docker/alpine/Dockerfile

ARG MINIFLUX_VERSION=2.2.16

FROM golang:alpine3.21 AS build

ARG MINIFLUX_VERSION
RUN apk add --no-cache build-base git make

# Clone specific version
RUN git clone --depth 1 --branch ${MINIFLUX_VERSION} \
    https://github.com/miniflux/v2.git /go/src/app

WORKDIR /go/src/app
RUN make miniflux

FROM alpine:3.21

LABEL org.opencontainers.image.title=Miniflux
LABEL org.opencontainers.image.description="Miniflux is a minimalist and opinionated feed reader"
LABEL org.opencontainers.image.source=https://github.com/miniflux/v2

EXPOSE 8080
ENV LISTEN_ADDR=0.0.0.0:8080

RUN apk --no-cache add ca-certificates tzdata
COPY --from=build /go/src/app/miniflux /usr/bin/miniflux

USER 65534
CMD ["/usr/bin/miniflux"]
