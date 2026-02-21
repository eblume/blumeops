# Quartz Static Site Server
# Downloads and serves a Quartz-built static site from a release bundle
#
# Configuration (via environment):
#   DOCS_RELEASE_URL - URL to download the static site tarball
#
# The container downloads the tarball on startup, extracts it, and serves with nginx.

ARG CONTAINER_APP_VERSION=1.28.2
ARG NGINX_VERSION=${CONTAINER_APP_VERSION}

FROM nginx:${NGINX_VERSION}-alpine

# Install curl for downloading release assets
RUN apk add --no-cache curl

# Copy startup script and nginx config
COPY start.sh /start.sh
COPY default.conf /etc/nginx/conf.d/default.conf
RUN chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]
