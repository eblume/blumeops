#!/bin/sh
set -e

# Connect to tailnet first — nginx needs MagicDNS for upstream resolution.
# Deploys use strategy=immediate (fly.toml, since f6febb1f): the old machine
# is gone before this one boots, so this cold-start sequence is downtime —
# the deploy workflow's fatal health check is what catches a boot that never
# completes. Fly.io runs Firecracker microVMs that support TUN devices
# natively — no need for --tun=userspace-networking.
# Tailscale state (node key + serve config) lives on the Fly volume via a
# bind mount: a persisted node key reconnects with its existing identity
# instead of re-authing with the auth key on every boot. The key is
# ephemeral (pulumi/tailscale), so a long-offline node is reclaimed and
# its boot re-auths — the name is stable for the node's lifetime, not
# guaranteed forever (see docs/how-to/operations/manage-flyio-proxy.md).
mkdir -p /volume/tailscale
mount --bind /volume/tailscale /var/lib/tailscale || echo "WARNING: tailscale state bind mount failed — node identity will not persist"
tailscaled --statedir=/var/lib/tailscale --port=41641 &
sleep 2
# A persisted node key (volume) that is still registered reconnects
# without any auth key, so a boot during an auth-key expiry gap still
# works. BackendState (not `whoami`, which is not a tailscale
# subcommand, and not plain `status`, which exits 0 while
# reconnecting): "Running" means already connected. Anything else —
# fresh volume (NoState), key deleted server-side (NeedsLogin) — logs
# in with the key. The key is ephemeral (pulumi/tailscale), so an
# offline node is eventually reclaimed and its boot re-auths.
# Poll until the state settles: a persisted-key reconnect is
# "Starting" for a moment, and a boot that re-auths in that window
# wastes the auth key (and fails if it has expired). Settled means
# Running (connected) or a stable logged-out state.
state=""
n=15
while [ "$n" -gt 0 ]; do
    # status can still be erroring while tailscaled starts: an empty
    # parse (not a settled state) just loops on.
    state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "NoState"' 2>/dev/null || true)
    case "$state" in Running|NoState|NeedsLogin) break ;; esac
    sleep 1
    n=$((n-1))
done
if [ "$state" != "Running" ]; then
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

# Start Anubis — proof-of-work gateway in front of the static mirror
# backend vhost (127.0.0.1:8925, nginx.conf). Started before nginx so the
# first proxied request doesn't 502. ANUBIS_ED25519_PRIVATE_KEY_HEX is a
# Fly secret; without it Anubis generates an ephemeral signing key
# (challenge cookies reset each deploy). COOKIE_DYNAMIC_DOMAIN scopes the
# challenge cookie to the request's hostname (forge.eblu.me / the staging
# host), so git/API clients are unaffected. Alloy scrapes its metrics on 9092.
if [ -n "${ANUBIS_ED25519_PRIVATE_KEY_HEX:-}" ]; then
    export ED25519_PRIVATE_KEY_HEX="$ANUBIS_ED25519_PRIVATE_KEY_HEX"
fi
BIND=127.0.0.1:8924 \
TARGET=http://127.0.0.1:8925 \
METRICS_BIND=127.0.0.1:9092 \
COOKIE_DYNAMIC_DOMAIN=1 \
anubis &

# Start sshd — the mirror's git-shell push endpoint. The tailnet
# (WireGuard) reaches the node's Tailscale IP directly (no `tailscale
# serve` — the tailnet has no autoAppCaps policy), and the only client
# allowed on it will be the private forge (tag:forge ->
# tag:flyio-proxy:22 ACL grant), forced git commands
# only (mirror user, no shell).
#
# Host keys live on the volume: Forgejo push mirrors use
# StrictHostKeyChecking=accept-new (TOFU) against a per-instance
# known_hosts, so keys regenerated on each deploy would break every
# mirror after its first sync. Copied into /etc/ssh (not symlinked:
# sshd checks private-key permissions, and symlinks report 777).
#
# Bind happens when sshd starts, so the tailnet IP must be up first —
# a missing address makes sshd refuse the listen socket and exit.
mkdir -p /volume/ssh /etc/ssh /run/sshd
if [ ! -f /volume/ssh/ssh_host_ed25519_key ]; then
    # Not `ssh-keygen -A -f /volume/ssh`: with -A, -f is a path *prefix*, so
    # it writes to /volume/ssh/etc/ssh/ (absent) and fails — the 09-29 boot
    # came up with no host keys and sshd exited (eblume/blumeops#1208).
    ssh-keygen -q -t ed25519 -N '' -f /volume/ssh/ssh_host_ed25519_key \
        || echo "WARNING: ssh host key generation failed"
fi
cp -p /volume/ssh/ssh_host_* /etc/ssh/ || echo "WARNING: ssh host key copy failed"

# Unquoted on purpose — space-separated -o flags sshd must see as words.
listen_addresses="-o ListenAddress=127.0.0.1"
# The push endpoint binds the Tailscale IP in addition to loopback; the
# ACL grant (tag:forge -> tag:flyio-proxy tcp:22) is the only inbound
# path. If the address is not up yet, sshd must fall back to loopback
# (it exits on a missing listen address), and the first mirror syncs
# retry until a boot has the interface.
n=15
while [ "$n" -gt 0 ]; do
    tscidr=$(tailscale ip -4 2>/dev/null | cut -d'/' -f1)
    [ -n "$tscidr" ] && break
    sleep 1
    n=$((n-1))
done
if [ -n "$tscidr" ]; then
    listen_addresses="$listen_addresses -o ListenAddress=${tscidr%%/*}"
else
    echo "WARNING: tailscale0 address never appeared — sshd stays on loopback; mirror pushes will fail until a restart"
fi
sshd_opts="$listen_addresses -o PasswordAuthentication=no -o PermitRootLogin=no -o X11Forwarding=no -o AllowUsers=mirror"
# `sshd -t` catches config and host-key errors up front: sshd exits on
# them only after the fork, so a kill -0 right after `&` still passes.
if /usr/sbin/sshd -t $sshd_opts; then
    /usr/sbin/sshd -D -e $sshd_opts &
    echo "sshd started"
else
    echo "WARNING: sshd config test failed — sshd not started, mirror pushes will fail"
fi

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
# effort basis: it only touches the volume (no tailnet needed). Gate on
# the volume mount, not a subdirectory — a fresh volume is empty, and
# create-mirror.sh creates /volume/git-mirror itself (mkdir -p).
if mountpoint -q /volume; then
    /usr/local/bin/create-mirror.sh || \
        echo "WARNING: git-mirror init failed (staging vhost will 302 until fixed)"
else
    echo "git-mirror init skipped — no volume attached (run mise run fly-setup)"
fi

# Block on nginx — container exits if nginx stops
wait $NGINX_PID
