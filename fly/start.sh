#!/bin/sh
set -e

# Connect to tailnet first — nginx needs MagicDNS for upstream resolution.
# Deploys use strategy=immediate (fly.toml, since f6febb1f): the old machine
# is gone before this one boots, so this cold-start sequence is downtime —
# the deploy workflow's fatal health check is what catches a boot that never
# completes. Fly.io runs Firecracker microVMs that support TUN devices
# natively — no need for --tun=userspace-networking.
tailscaled --statedir=/var/lib/tailscale --port=41641 &
sleep 2
tailscale up --authkey="${TS_AUTHKEY}" --hostname=flyio-proxy
until tailscale status > /dev/null 2>&1; do sleep 1; done
echo "Tailscale connected"

# Wait for MagicDNS to be ready — upstream blocks resolve DNS at config
# load, so nginx will fail to start if MagicDNS can't resolve yet.
echo "Waiting for MagicDNS..."
until nslookup forge.tail8d86e.ts.net 100.100.100.100 > /dev/null 2>&1; do
    sleep 1
done
echo "MagicDNS ready"

# Ensure fail2ban deny files exist before nginx starts
# (the geo directives' `include`s fail if the files are missing).
touch /etc/nginx/forge-deny.conf /etc/nginx/photos-deny.conf

# Start Anubis — proof-of-work gateway for forge.eblu.me. Sits between the
# public forge server block (:8080) and the internal forge backend vhost
# (:8081). Started before nginx so the first proxied request doesn't 502.
# ANUBIS_ED25519_PRIVATE_KEY_HEX is a Fly secret; without it Anubis
# generates an ephemeral signing key (challenge cookies reset each deploy).
if [ -n "${ANUBIS_ED25519_PRIVATE_KEY_HEX:-}" ]; then
    export ED25519_PRIVATE_KEY_HEX="$ANUBIS_ED25519_PRIVATE_KEY_HEX"
fi
BIND=127.0.0.1:8923 \
TARGET=http://127.0.0.1:8081 \
METRICS_BIND=127.0.0.1:9091 \
COOKIE_DOMAIN=forge.eblu.me \
anubis &
echo "Anubis started"

# Start nginx — MagicDNS is available, upstreams resolved.
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
