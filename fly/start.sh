#!/bin/sh
set -e

# Start nginx immediately so port 8080 is bound (avoids connection refused).
# Health check returns 503 until /tmp/tailscale-ready exists, so Fly.io
# keeps the old machine serving traffic until Tailscale connects.
nginx -g "daemon off;" &
NGINX_PID=$!
echo "Nginx started (waiting for Tailscale before proxying)"

# Start tailscale daemon. Fly.io runs Firecracker microVMs which support
# TUN devices natively — no need for --tun=userspace-networking.
tailscaled --statedir=/var/lib/tailscale &
sleep 2

# Authenticate and join tailnet
tailscale up --authkey="${TS_AUTHKEY}" --hostname=flyio-proxy

# Wait for tailscale to be ready, then signal nginx health check
until tailscale status > /dev/null 2>&1; do sleep 1; done
touch /tmp/tailscale-ready
echo "Tailscale connected"

# Start Alloy for observability (logs → Loki, metrics → Prometheus)
alloy run /etc/alloy/config.alloy \
    --server.http.listen-addr=127.0.0.1:12345 \
    --storage.path=/tmp/alloy-data &
echo "Alloy started"

# Block on nginx — container exits if nginx stops
wait $NGINX_PID
