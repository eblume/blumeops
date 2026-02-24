#!/bin/bash
# Sync ZIM torrents from kiwix ConfigMap to Transmission
# Runs as a sidecar in the kiwix deployment
set -euo pipefail

TORRENT_LIST="${TORRENT_LIST:-/config/torrents.txt}"
TRANSMISSION_HOST="${TRANSMISSION_HOST:-transmission.torrent.svc.cluster.local}"
TRANSMISSION_PORT="${TRANSMISSION_PORT:-9091}"

echo "Syncing ZIM torrents to transmission at ${TRANSMISSION_HOST}:${TRANSMISSION_PORT}"

# Wait for transmission to be ready
# Transmission RPC returns 409 on first request (to provide session ID), which is fine
echo "Waiting for Transmission RPC..."
max_attempts=30
attempt=0
until curl -s -o /dev/null -w "%{http_code}" "http://${TRANSMISSION_HOST}:${TRANSMISSION_PORT}/transmission/rpc" | grep -qE "^(200|409)$"; do
    attempt=$((attempt + 1))
    if [[ $attempt -ge $max_attempts ]]; then
        echo "Transmission not ready after ${max_attempts} attempts, will retry next cycle"
        exit 0  # Don't fail, just skip this sync
    fi
    sleep 10
done
echo "Transmission is ready"

# Get current torrents from transmission
# transmission-remote returns header + data + footer, extract just torrent names
current=$(transmission-remote "${TRANSMISSION_HOST}:${TRANSMISSION_PORT}" -l 2>/dev/null | \
          tail -n +2 | head -n -1 | awk '{print $NF}' || true)

added=0
skipped=0

while IFS= read -r url || [[ -n "$url" ]]; do
    # Skip empty lines and comments
    [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
    # Trim whitespace
    url=$(echo "$url" | xargs)
    [[ -z "$url" ]] && continue

    # Extract base name from URL (remove .torrent extension)
    basename=$(basename "$url" .torrent)
    # Also try without .zim in case transmission reports it differently
    basename_no_zim="${basename%.zim}"

    # Check if already in transmission
    if echo "$current" | grep -qF "$basename_no_zim"; then
        ((skipped++)) || true
    else
        if transmission-remote "${TRANSMISSION_HOST}:${TRANSMISSION_PORT}" -a "$url" 2>/dev/null; then
            echo "Added: $basename"
            ((added++)) || true
        else
            echo "Warning: Failed to add $url" >&2
        fi
    fi
done < "$TORRENT_LIST"

echo "Sync complete: $added added, $skipped already present"
