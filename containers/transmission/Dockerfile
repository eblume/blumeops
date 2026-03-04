# Transmission BitTorrent daemon
# Simpler alternative to linuxserver image

ARG CONTAINER_APP_VERSION=4.1.1-r1

FROM alpine:3.22

ARG CONTAINER_APP_VERSION
ARG TRANSMISSION_VERSION=${CONTAINER_APP_VERSION}

# Transmission 4.1.x is only in edge; base OS stays on stable 3.22
RUN apk add --no-cache \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
    transmission-daemon=${TRANSMISSION_VERSION} \
    transmission-cli=${TRANSMISSION_VERSION} \
    transmission-remote=${TRANSMISSION_VERSION} \
    && apk add --no-cache \
    bash \
    curl \
    tzdata \
    su-exec

# Create directories (user is created dynamically by start.sh based on PUID/PGID)
RUN mkdir -p /config /downloads/complete /downloads/incomplete

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 9091 51413/tcp 51413/udp

VOLUME ["/config", "/downloads"]

ENTRYPOINT ["/start.sh"]
