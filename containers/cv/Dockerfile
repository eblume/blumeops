# CV/Resume Static Site Server
# Downloads and serves a CV site tarball (HTML+CSS+PDF) via nginx
#
# Configuration (via environment):
#   CV_RELEASE_URL - URL to download the CV content tarball
#
# The container downloads the tarball on startup, extracts it, and serves with nginx.

ARG CONTAINER_APP_VERSION=1.0.3

FROM nginx:alpine

ARG CONTAINER_APP_VERSION
LABEL org.opencontainers.image.title="CV"
LABEL org.opencontainers.image.description="Static site server for CV/resume"
LABEL org.opencontainers.image.version="${CONTAINER_APP_VERSION}"
LABEL org.opencontainers.image.source="https://forge.eblu.me/eblume/blumeops"
LABEL org.opencontainers.image.vendor="blumeops"

# Install curl for downloading release assets
RUN apk add --no-cache curl

# Copy startup script and nginx config
COPY start.sh /start.sh
COPY default.conf /etc/nginx/conf.d/default.conf
RUN chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]
