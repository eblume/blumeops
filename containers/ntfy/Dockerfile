# ntfy push notification server
# Three-stage build: Web UI (Node), server (Go+SQLite), runtime (Alpine)

ARG CONTAINER_APP_VERSION=v2.17.0
ARG NTFY_VERSION=${CONTAINER_APP_VERSION}
ARG NTFY_COMMIT=a03a37feb1869e84e3af0dd6190bdc7183f211ec

FROM node:22-alpine AS web-build

ARG NTFY_COMMIT
RUN apk add --no-cache git

RUN mkdir /app && cd /app \
    && git init \
    && git remote add origin https://forge.ops.eblu.me/eblume/ntfy.git \
    && git fetch --depth 1 origin ${NTFY_COMMIT} \
    && git checkout FETCH_HEAD

WORKDIR /app/web
RUN npm ci
RUN npm run build

FROM golang:alpine3.22 AS build

ARG NTFY_VERSION
ARG NTFY_COMMIT
RUN apk add --no-cache build-base git

RUN mkdir /app && cd /app \
    && git init \
    && git remote add origin https://forge.ops.eblu.me/eblume/ntfy.git \
    && git fetch --depth 1 origin ${NTFY_COMMIT} \
    && git checkout FETCH_HEAD

WORKDIR /app

# Copy pre-built web UI assets
COPY --from=web-build /app/web/build /app/server/site

# Create docs placeholder with dummy file (go:embed requires non-empty dir)
RUN mkdir -p server/docs && touch server/docs/placeholder

ENV CGO_ENABLED=1

RUN go build \
    -o /ntfy \
    -tags sqlite_omit_load_extension,osusergo,netgo \
    -ldflags "-linkmode=external -extldflags=-static -s -w -X main.version=${NTFY_VERSION}"

FROM alpine:3.22

LABEL org.opencontainers.image.title=ntfy
LABEL org.opencontainers.image.description="ntfy is a simple HTTP-based pub-sub notification service"
LABEL org.opencontainers.image.source=https://github.com/binwiederhier/ntfy

RUN apk --no-cache add tzdata

COPY --from=build /ntfy /usr/bin/ntfy

EXPOSE 80

USER 65534
ENTRYPOINT ["/usr/bin/ntfy"]
