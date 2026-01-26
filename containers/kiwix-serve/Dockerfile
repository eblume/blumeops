# kiwix-serve container
# Downloads pre-built binary from kiwix mirror

FROM alpine:3.21

ARG TARGETPLATFORM
ARG KIWIX_VERSION=3.8.1

RUN set -e && \
    apk --no-cache add dumb-init curl && \
    echo "TARGETPLATFORM: $TARGETPLATFORM" && \
    if [ "$TARGETPLATFORM" = "linux/arm64/v8" -o "$TARGETPLATFORM" = "linux/arm64" ]; then \
        ARCH="aarch64"; \
    elif [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
        ARCH="x86_64"; \
    else \
        ARCH="unknown"; \
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
