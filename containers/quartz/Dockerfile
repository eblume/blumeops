# Quartz Static Site Server
# Downloads and serves a Quartz-built static site from a release bundle
#
# Configuration (via environment):
#   DOCS_RELEASE_URL - URL to download the static site tarball
#
# The container downloads the tarball on startup, extracts it, and serves with nginx.

FROM nginx:alpine

# Install curl for downloading release assets
RUN apk add --no-cache curl

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Custom nginx config for SPA routing
RUN cat > /etc/nginx/conf.d/default.conf << 'EOF'
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;

    # Enable gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # SPA fallback - serve index.html for client-side routing
    location / {
        try_files $uri $uri/ $uri.html /index.html;
    }

    # Health check endpoint
    location /healthz {
        access_log off;
        return 200 "ok\n";
        add_header Content-Type text/plain;
    }
}
EOF

EXPOSE 80

CMD ["/start.sh"]
