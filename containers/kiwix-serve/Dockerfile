# kiwix-serve container
# Downloads pre-built binary from kiwix mirror

FROM alpine:3.21

ARG TARGETPLATFORM
ARG KIWIX_VERSION=3.8.1

RUN set -e && \
    apk --no-cache add dumb-init curl && \
    # Detect architecture - use TARGETPLATFORM if set, otherwise detect from uname
    if [ -n "$TARGETPLATFORM" ]; then \
        echo "TARGETPLATFORM: $TARGETPLATFORM"; \
        case "$TARGETPLATFORM" in \
            linux/arm64*) ARCH="aarch64" ;; \
            linux/amd64*) ARCH="x86_64" ;; \
            *) ARCH="" ;; \
        esac; \
    else \
        echo "TARGETPLATFORM not set, detecting from uname..."; \
        UNAME_ARCH=$(uname -m); \
        echo "uname -m: $UNAME_ARCH"; \
        case "$UNAME_ARCH" in \
            aarch64|arm64) ARCH="aarch64" ;; \
            x86_64) ARCH="x86_64" ;; \
            *) ARCH="" ;; \
        esac; \
    fi && \
    if [ -z "$ARCH" ]; then \
        echo "ERROR: Unsupported architecture"; \
        exit 1; \
    fi && \
    url="http://mirror.download.kiwix.org/release/kiwix-tools/kiwix-tools_linux-$ARCH-$KIWIX_VERSION.tar.gz" && \
    echo "URL: $url" && \
    curl -k -L $url | tar -xz -C /usr/local/bin/ --strip-components 1 && \
    apk del curl

EXPOSE 80

# Run as non-root
RUN adduser -D -u 1000 kiwix
USER kiwix

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/bin/sh", "-c", "echo 'Use: kiwix-serve [options] <zim-files>' && kiwix-serve --help"]
