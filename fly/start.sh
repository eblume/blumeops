#!/bin/sh
set -e

# Start tailscale daemon. Fly.io runs Firecracker microVMs which support
# TUN devices natively — no need for --tun=userspace-networking.
tailscaled --statedir=/var/lib/tailscale &
sleep 2

# Authenticate and join tailnet
tailscale up --authkey="${TS_AUTHKEY}" --hostname=flyio-proxy

# Wait for tailscale to be ready
until tailscale status > /dev/null 2>&1; do sleep 1; done
echo "Tailscale connected"

# Start nginx — MagicDNS resolves *.tail8d86e.ts.net hostnames
nginx -g "daemon off;"
