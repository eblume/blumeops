# syntax=docker/dockerfile:1
# Paperless-ngx — self-hosted document management
# Built from source via forge mirror of paperless-ngx/paperless-ngx
# Closely follows upstream Dockerfile structure with git clone instead of COPY

ARG CONTAINER_APP_VERSION=v2.20.13

###############################################
# Stage 1: Clone source (reused by later stages)
###############################################
FROM docker.io/library/alpine:3.22 AS source

ARG CONTAINER_APP_VERSION
RUN apk add --no-cache git
RUN git clone --depth 1 --branch ${CONTAINER_APP_VERSION} \
    https://forge.ops.eblu.me/mirrors/paperless-ngx.git /src

###############################################
# Stage 2: Compile frontend
###############################################
FROM --platform=$BUILDPLATFORM docker.io/node:20-trixie-slim AS compile-frontend

COPY --from=source /src/src-ui /src/src-ui
WORKDIR /src/src-ui

RUN set -eux \
    && npm update -g pnpm \
    && npm install -g corepack@latest \
    && corepack enable \
    && pnpm install

RUN set -eux \
    && ./node_modules/.bin/ng build --configuration production

###############################################
# Stage 3: s6-overlay base
###############################################
FROM ghcr.io/astral-sh/uv:0.9.15-python3.12-trixie-slim AS s6-overlay-base

WORKDIR /usr/src/s6

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_VERBOSITY=1 \
    PATH=/command:$PATH

ARG TARGETARCH
ARG TARGETVARIANT
ARG S6_OVERLAY_VERSION=3.2.1.0

RUN set -eux \
    && apt-get update \
    && apt-get install --yes --quiet --no-install-recommends curl xz-utils \
    && S6_ARCH="" \
    && if [ "${TARGETARCH}${TARGETVARIANT}" = "amd64" ]; then S6_ARCH="x86_64"; \
    elif [ "${TARGETARCH}${TARGETVARIANT}" = "arm64" ]; then S6_ARCH="aarch64"; fi \
    && if [ -z "${S6_ARCH}" ]; then echo "Error: Cannot determine arch"; exit 1; fi \
    && curl --fail --silent --show-error --location --remote-name-all --parallel \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz.sha256" \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz.sha256" \
    && sha256sum --check ./*.sha256 \
    && tar --directory / -Jxpf s6-overlay-noarch.tar.xz \
    && tar --directory / -Jxpf s6-overlay-${S6_ARCH}.tar.xz \
    && rm ./*.tar.xz ./*.sha256 \
    && apt-get --yes purge curl xz-utils \
    && apt-get --yes autoremove --purge \
    && rm -rf /var/lib/apt/lists/*

# Copy rootfs (s6 service definitions, init scripts)
COPY --from=source /src/docker/rootfs /

###############################################
# Stage 4: Main application
###############################################
FROM s6-overlay-base AS main-app

ARG CONTAINER_APP_VERSION
ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
ARG JBIG2ENC_VERSION=0.30

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONWARNINGS="ignore:::django.http.response:517" \
    PNGX_CONTAINERIZED=1 \
    UV_LINK_MODE=copy \
    UV_CACHE_DIR=/cache/uv/

# Runtime packages
RUN set -eux \
    && apt-get update \
    && apt-get install --yes --quiet --no-install-recommends \
        curl gosu tzdata fonts-liberation gettext ghostscript gnupg \
        icc-profiles-free imagemagick postgresql-client \
        tesseract-ocr tesseract-ocr-eng tesseract-ocr-deu tesseract-ocr-fra \
        tesseract-ocr-ita tesseract-ocr-spa unpaper pngquant jbig2dec \
        libxml2 libxslt1.1 qpdf file libmagic1 media-types zlib1g \
        libzbar0 poppler-utils \
    && curl --fail --silent --show-error --location --remote-name-all \
        "https://github.com/paperless-ngx/builder/releases/download/jbig2enc-trixie-v${JBIG2ENC_VERSION}/jbig2enc_${JBIG2ENC_VERSION}-1_${TARGETARCH}.deb" \
    && dpkg --install ./jbig2enc_${JBIG2ENC_VERSION}-1_${TARGETARCH}.deb \
    && cp /etc/ImageMagick-6/paperless-policy.xml /etc/ImageMagick-6/policy.xml \
    && rm --force *.deb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/paperless/src/

# Python dependencies
COPY --from=source /src/pyproject.toml /src/uv.lock /usr/src/paperless/src/

RUN --mount=type=cache,target=${UV_CACHE_DIR},id=python-cache \
    set -eux \
    && apt-get update \
    && apt-get install --yes --quiet --no-install-recommends \
        build-essential default-libmysqlclient-dev pkg-config \
    && uv export --quiet --no-dev --all-extras --format requirements-txt --output-file requirements.txt \
    && uv pip install --system --no-python-downloads --python-preference system --requirements requirements.txt \
    && python3 -W ignore::RuntimeWarning -m nltk.downloader -d "/usr/share/nltk_data" snowball_data \
    && python3 -W ignore::RuntimeWarning -m nltk.downloader -d "/usr/share/nltk_data" stopwords \
    && python3 -W ignore::RuntimeWarning -m nltk.downloader -d "/usr/share/nltk_data" punkt_tab \
    && apt-get --yes purge build-essential default-libmysqlclient-dev pkg-config \
    && apt-get --yes autoremove --purge \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy backend source
COPY --from=source /src/src ./

# Copy compiled frontend
COPY --from=compile-frontend /src/src/documents/static/frontend/ ./documents/static/frontend/

# Create user and finalize
RUN set -eux \
    && addgroup --gid 1000 paperless \
    && useradd --uid 1000 --gid paperless --home-dir /usr/src/paperless paperless \
    && mkdir -p /usr/src/paperless/data /usr/src/paperless/media \
                /usr/src/paperless/consume /usr/src/paperless/export \
    && chown -R paperless:paperless /usr/src/paperless \
    && s6-setuidgid paperless python3 manage.py collectstatic --clear --no-input --link \
    && s6-setuidgid paperless python3 manage.py compilemessages

VOLUME ["/usr/src/paperless/data", "/usr/src/paperless/media", \
        "/usr/src/paperless/consume", "/usr/src/paperless/export"]

ENTRYPOINT ["/init"]
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
    CMD [ "curl", "-fs", "-S", "-L", "--max-time", "2", "http://localhost:8000" ]

LABEL org.opencontainers.image.title="Paperless-ngx"
LABEL org.opencontainers.image.description="Self-hosted document management system"
LABEL org.opencontainers.image.version="${CONTAINER_APP_VERSION}"
LABEL org.opencontainers.image.source="https://forge.eblu.me/eblume/blumeops"
LABEL org.opencontainers.image.vendor="blumeops"
