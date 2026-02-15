# Navidrome music server
# Three-stage build: UI (Node), backend (Go+taglib), runtime (Alpine)

ARG NAVIDROME_VERSION=v0.60.3

FROM node:22-alpine AS ui-build

ARG NAVIDROME_VERSION
RUN apk add --no-cache git

RUN git clone --depth 1 --branch ${NAVIDROME_VERSION} \
    https://forge.ops.eblu.me/eblume/navidrome.git /app

WORKDIR /app/ui
RUN npm ci
RUN npm run build

FROM golang:alpine3.22 AS build

ARG NAVIDROME_VERSION
RUN apk add --no-cache build-base git taglib-dev zlib-dev

RUN git clone --depth 1 --branch ${NAVIDROME_VERSION} \
    https://forge.ops.eblu.me/eblume/navidrome.git /app

WORKDIR /app

# Copy pre-built UI assets
COPY --from=ui-build /app/ui/build /app/ui/build

ENV CGO_ENABLED=1
ENV CGO_CFLAGS_ALLOW="--define-prefix"

RUN go build -tags=netgo \
    -ldflags="-w -s -X github.com/navidrome/navidrome/consts.gitTag=${NAVIDROME_VERSION}" \
    -o /navidrome .

FROM alpine:3.22

LABEL org.opencontainers.image.title=Navidrome
LABEL org.opencontainers.image.description="Navidrome is a self-hosted music server and streamer"
# Points to upstream canonical source, not the forge mirror used for builds
LABEL org.opencontainers.image.source=https://github.com/navidrome/navidrome

RUN apk add --no-cache ca-certificates tzdata taglib ffmpeg

COPY --from=build /navidrome /usr/bin/navidrome

EXPOSE 4533

USER 65534
CMD ["/usr/bin/navidrome"]
