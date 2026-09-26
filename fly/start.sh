#!/bin/sh
set -e

# Connect to tailnet first — nginx needs MagicDNS for upstream resolution.
# Deploys use strategy=immediate (fly.toml, since f6febb1f): the old machine
# is gone before this one boots, so this cold-start sequence is downtime —
# the deploy workflow's fatal health check is what catches a boot that never
# completes. Fly.io runs Firecracker microVMs that support TUN devices
# natively — no need for --tun=userspace-networking.
# Tailscale state (node key + serve config) lives on the Fly volume via a
# bind mount, so the node keeps its identity (name + CGNAT IP) across
# machine replacement — the mirror's SSH endpoint is addressed by the
# stable MagicDNS name (fly.toml). A fresh volume simply gets a fresh
# identity, as before.
mkdir -p /volume/tailscale
mount --bind /volume/tailscale /var/lib/tailscale 2>/dev/null || true
tailscaled --statedir=/var/lib/tailscale --port=41641 &
sleep 2
# A persisted node key (volume) reconnects with its existing identity —
# no auth key needed, so a boot during an auth-key expiry gap still works.
# A fresh volume logs in with the key. (whoami, not status: status exits
# 0 in the transient "Starting" state even when not logged in.)
if ! tailscale whoami > /dev/null 2>&1; then
    tailscale up --authkey="${TS_AUTHKEY}" --hostname=flyio-proxy
fi
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

# Second Anubis instance in front of the static mirror backend vhost
# (127.0.0.1:8925, nginx.conf). COOKIE_DYNAMIC_DOMAIN scopes its
# challenge cookie to the request's hostname (blumeops-proxy.fly.dev
# today, forge.eblu.me after the cutover) instead of a fixed domain, so
# the forge.eblu.me challenge stays unaffected. Alloy scrapes its
# metrics on 9092.
BIND=127.0.0.1:8924 \
TARGET=http://127.0.0.1:8925 \
METRICS_BIND=127.0.0.1:9092 \
COOKIE_DYNAMIC_DOMAIN=1 \
anubis &
echo "Anubis (mirror) started"

# Start sshd — the mirror's git-shell push endpoint. WireGuard delivers
# tailnet traffic to the node's CGNAT IP directly (no `tailscale serve`
# — the tailnet has no autoAppCaps policy), so :22 is never public; the
# only client allowed on it is the private forge (tag:forge ->
# tag:flyio-proxy:22 ACL grant), and only as forced git commands (mirror
# user, no shell). -o overrides harden regardless of distro config drift.
ssh-keygen -A
mkdir -p /run/sshd
/usr/sbin/sshd -D -e -o PasswordAuthentication=no -o PermitRootLogin=no -o X11Forwarding=no &
SSHD_PID=$!
if ! kill -0 "$SSHD_PID" 2>/dev/null; then
    echo "WARNING: sshd failed to start (mirror push will not work)"
fi
echo "sshd started"

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

# Static mirror init (fly/git-mirror/README.md). Post-start, on a best
# effort basis: it only touches the volume (no tailnet needed), and a
# first deploy where fly-setup has not yet created the volume is a
# valid state — the staging vhost 302s to forge.ops.eblu.me until then.
if [ -d /volume/git-mirror ]; then
    /usr/local/bin/create-mirror.sh || \
        echo "WARNING: git-mirror init failed (staging vhost will 302 until fixed)"
else
    echo "git-mirror init skipped — /volume/git-mirror not present (run mise run fly-setup)"
fi

# Block on nginx — container exits if nginx stops
wait $NGINX_PID
