# Transmission BitTorrent daemon
# Simpler alternative to linuxserver image

FROM alpine:3.21

ARG TRANSMISSION_VERSION=4.0.6-r0

RUN apk add --no-cache \
    transmission-daemon=${TRANSMISSION_VERSION} \
    transmission-cli=${TRANSMISSION_VERSION} \
    transmission-remote=${TRANSMISSION_VERSION} \
    bash \
    tzdata \
    su-exec

# Create transmission user
RUN addgroup -g 1000 transmission && \
    adduser -D -u 1000 -G transmission transmission && \
    mkdir -p /config /downloads/complete /downloads/incomplete && \
    chown -R transmission:transmission /config /downloads

COPY --chmod=755 start.sh /start.sh

EXPOSE 9091 51413/tcp 51413/udp

VOLUME ["/config", "/downloads"]

ENTRYPOINT ["/start.sh"]
