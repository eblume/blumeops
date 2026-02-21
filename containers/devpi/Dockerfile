ARG CONTAINER_APP_VERSION=6.19.1

FROM python:3.12-slim

ARG CONTAINER_APP_VERSION
ARG DEVPI_SERVER_VERSION=${CONTAINER_APP_VERSION}
ARG DEVPI_WEB_VERSION=5.0.1

# Install devpi-server and devpi-web
RUN pip install --no-cache-dir \
    devpi-server==${DEVPI_SERVER_VERSION} \
    devpi-web==${DEVPI_WEB_VERSION}

# Create non-root user
RUN useradd -r -u 1000 devpi && mkdir -p /devpi && chown devpi:devpi /devpi

# Add startup script
COPY --chown=devpi:devpi start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

USER devpi
WORKDIR /devpi

# Expose default port
EXPOSE 3141

ENTRYPOINT ["/usr/local/bin/start.sh"]
