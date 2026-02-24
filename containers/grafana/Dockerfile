ARG CONTAINER_APP_VERSION=12.3.3

FROM alpine:3.22

ARG TARGETPLATFORM
ARG CONTAINER_APP_VERSION
ARG GRAFANA_VERSION=${CONTAINER_APP_VERSION}

RUN set -e && \
    apk --no-cache add dumb-init curl && \
    # Detect architecture
    if [ -n "$TARGETPLATFORM" ]; then \
        echo "TARGETPLATFORM: $TARGETPLATFORM"; \
        case "$TARGETPLATFORM" in \
            linux/arm64*) ARCH="arm64" ;; \
            linux/amd64*) ARCH="amd64" ;; \
            *) ARCH="" ;; \
        esac; \
    else \
        echo "TARGETPLATFORM not set, detecting from uname..."; \
        UNAME_ARCH=$(uname -m); \
        echo "uname -m: $UNAME_ARCH"; \
        case "$UNAME_ARCH" in \
            aarch64|arm64) ARCH="arm64" ;; \
            x86_64) ARCH="amd64" ;; \
            *) ARCH="" ;; \
        esac; \
    fi && \
    if [ -z "$ARCH" ]; then \
        echo "ERROR: Unsupported architecture"; \
        exit 1; \
    fi && \
    url="https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-${ARCH}.tar.gz" && \
    echo "URL: $url" && \
    curl -fSL "$url" | tar -xz -C /tmp && \
    mv /tmp/grafana-${GRAFANA_VERSION} /usr/share/grafana && \
    apk del curl

# Standard Grafana paths
RUN mkdir -p /etc/grafana /var/lib/grafana /var/log/grafana && \
    cp /usr/share/grafana/conf/defaults.ini /etc/grafana/grafana.ini && \
    cp /usr/share/grafana/conf/defaults.ini /etc/grafana/defaults.ini

# UID 472 matches official Grafana image for PVC compatibility
RUN adduser -D -u 472 -h /usr/share/grafana grafana && \
    chown -R grafana:grafana /usr/share/grafana /etc/grafana /var/lib/grafana /var/log/grafana

ENV PATH="/usr/share/grafana/bin:$PATH"

USER grafana
WORKDIR /usr/share/grafana
EXPOSE 3000

LABEL org.opencontainers.image.title="Grafana"
LABEL org.opencontainers.image.description="Grafana OSS observability platform"
LABEL org.opencontainers.image.source="https://github.com/grafana/grafana"

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["grafana", "server", \
     "--homepath=/usr/share/grafana", \
     "--config=/etc/grafana/grafana.ini", \
     "cfg:default.paths.data=/var/lib/grafana", \
     "cfg:default.paths.logs=/var/log/grafana", \
     "cfg:default.paths.plugins=/var/lib/grafana/plugins", \
     "cfg:default.paths.provisioning=/etc/grafana/provisioning"]
