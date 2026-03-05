# Transmission Prometheus exporter - collect-on-scrape, no polling loop
# uv run --script handles dependency resolution at runtime

ARG CONTAINER_APP_VERSION=1.0.0

FROM python:3.13-alpine3.23

LABEL org.opencontainers.image.title="Transmission Exporter"
LABEL org.opencontainers.image.description="Prometheus exporter for Transmission BitTorrent client"

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

ENV PYTHONUNBUFFERED=1
ENV UV_CACHE_DIR=/tmp/uv-cache

WORKDIR /app
COPY exporter.py .

EXPOSE 19091
USER 65534:65534
CMD ["uv", "run", "--script", "/app/exporter.py"]
