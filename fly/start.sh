#!/bin/sh
set -e

# Connect to tailnet first — nginx needs MagicDNS for upstream resolution.
# With bluegreen deploys, the old machine serves traffic until this one is
# fully ready. Fly.io runs Firecracker microVMs that support TUN devices
# natively — no need for --tun=userspace-networking.
tailscaled --statedir=/var/lib/tailscale &
sleep 2

tailscale up --authkey="${TS_AUTHKEY}" --hostname=flyio-proxy
until tailscale status > /dev/null 2>&1; do sleep 1; done
echo "Tailscale connected"

# Ensure fail2ban deny file exists before nginx starts
touch /etc/nginx/forge-deny.conf

# Start nginx — MagicDNS is available, health check passes immediately.
nginx -g "daemon off;" &
NGINX_PID=$!
echo "Nginx started"

# Start fail2ban for login brute-force protection.
# Non-fatal — nginx rate limiting is the primary defense; fail2ban is additive.
if fail2ban-server -b; then
    echo "fail2ban started"
else
    echo "WARNING: fail2ban failed to start (nginx rate limiting still active)"
fi

# Start Alloy for observability (logs → Loki, metrics → Prometheus)
alloy run /etc/alloy/config.alloy \
    --server.http.listen-addr=127.0.0.1:12345 \
    --storage.path=/tmp/alloy-data &
echo "Alloy started"

# Block on nginx — container exits if nginx stops
wait $NGINX_PID
