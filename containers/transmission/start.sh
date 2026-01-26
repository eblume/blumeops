#!/bin/bash
set -e

# Handle PUID/PGID like linuxserver images
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Create or update transmission group/user with requested UID/GID
# The transmission package may have created a user with different IDs
echo "Setting up transmission user with UID=$PUID GID=$PGID"

# Remove existing user/group if they exist (ignore errors)
deluser transmission 2>/dev/null || true
delgroup transmission 2>/dev/null || true

# Create fresh user/group with requested IDs
addgroup -g "$PGID" transmission
adduser -D -u "$PUID" -G transmission transmission

# Ensure directories exist with correct ownership
mkdir -p /config /downloads/complete /downloads/incomplete
# Only chown /config (emptyDir) - /downloads is NFS and may not allow chown
chown -R transmission:transmission /config 2>/dev/null || true
chown transmission:transmission /downloads /downloads/complete /downloads/incomplete 2>/dev/null || true

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
