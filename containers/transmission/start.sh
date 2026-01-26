#!/bin/bash
set -e

# Handle PUID/PGID like linuxserver images
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Update transmission user UID/GID if different from default
if [ "$PUID" != "1000" ] || [ "$PGID" != "1000" ]; then
    echo "Updating transmission user to UID=$PUID GID=$PGID"
    deluser transmission 2>/dev/null || true
    delgroup transmission 2>/dev/null || true
    addgroup -g "$PGID" transmission
    adduser -D -u "$PUID" -G transmission transmission
fi

# Ensure directories exist with correct ownership
mkdir -p /config /downloads/complete /downloads/incomplete
chown -R transmission:transmission /config /downloads

# Create default config if it doesn't exist
CONFIG_FILE="/config/settings.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating default configuration..."
    cat > "$CONFIG_FILE" << 'EOF'
{
    "download-dir": "/downloads/complete",
    "incomplete-dir": "/downloads/incomplete",
    "incomplete-dir-enabled": true,
    "rpc-enabled": true,
    "rpc-bind-address": "0.0.0.0",
    "rpc-port": 9091,
    "rpc-whitelist-enabled": false,
    "rpc-host-whitelist-enabled": false,
    "peer-port": 51413,
    "watch-dir-enabled": false,
    "umask": 2
}
EOF
    chown transmission:transmission "$CONFIG_FILE"
fi

# Set timezone
if [ -n "$TZ" ]; then
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
fi

echo "Starting transmission-daemon..."
exec su-exec transmission transmission-daemon \
    --foreground \
    --config-dir /config \
    --log-level=info
