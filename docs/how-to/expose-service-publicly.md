---
title: Expose a Service Publicly
modified: 2026-02-08
tags:
  - how-to
  - fly-io
  - tailscale
  - networking
aliases: []
id: expose-service-publicly
---

# Expose a Service Publicly via Fly.io + Tailscale

This guide describes how to expose a BlumeOps service to the public internet
using a reverse proxy container on [Fly.io](https://fly.io) that tunnels back
to [[indri]] over [[tailscale]]. The approach keeps the home IP hidden,
requires no changes to existing infrastructure (`*.ops.eblu.me`, [[caddy]],
DNS), and is reusable for multiple services.

## Architecture

```
Internet → <service>.eblu.me
               │
         Fly.io edge (Anycast, TLS via Let's Encrypt)
               │
         Fly.io VM (nginx reverse proxy + Tailscale)
               │  (WireGuard tunnel)
         tailnet (tail8d86e.ts.net)
               │
         <service>.tail8d86e.ts.net (Tailscale ingress)
               │
         k8s Service → pod
```
(The approach works similarly for non-k8s services via `tailscale serve`
service definitions, eg. [[forgejo]] and [[zot]])

A single Fly.io container serves as the public-facing proxy for all exposed
services. Each service gets a `server` block in the nginx config and a DNS
CNAME. The container joins the tailnet via an ephemeral auth key and reaches
backend services through Tailscale ingress endpoints.

Existing `*.ops.eblu.me` services remain private behind Tailscale — this
approach does not touch [[caddy]], [[gandi]] DNS-01, or any other existing
infrastructure. They can continue to operate in parallel for private access.

## Key decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Proxy host | Fly.io (free tier) | Managed container, no server to maintain via Ansible. Shared IPv4 + IPv6 are free for HTTP/HTTPS; dedicated IPv4 is $2/mo if a service needs non-HTTP(S) protocols |
| Tunnel | Tailscale (existing) | Already in use, WireGuard encryption, ACL control |
| DNS | CNAME at [[gandi]] | No DNS migration needed, no Cloudflare dependency |
| TLS (public) | Fly.io auto-provisions Let's Encrypt | No cert management, `$0.10/mo` per hostname |
| TLS (origin) | Tailscale handles encryption | WireGuard tunnel encrypts all traffic |
| CDN/cache | nginx `proxy_cache` in container | Per-service: aggressive for static sites, selective or disabled for dynamic services |
| DDoS | Fly.io Anycast + nginx rate limiting | Not enterprise-grade; see [[#Break-glass shutoff]] |
| IaC | `fly/` directory in repo, Pulumi for DNS + TS key | No well-maintained Fly.io Pulumi provider; `fly.toml` is the app's IaC |

## TLS in this architecture

There are three independent TLS segments — none involve Caddy:

1. **Browser → Fly.io edge**: Fly.io auto-provisions a Let's Encrypt
   certificate for each custom domain (e.g., `docs.eblu.me`). Validated via
   TLS-ALPN challenge — no DNS API needed.
2. **nginx → Tailscale ingress**: nginx proxies to
   `https://<service>.tail8d86e.ts.net`. The Tailscale ingress serves a
   Tailscale-issued cert. nginx uses `proxy_ssl_verify off` since the
   underlying tunnel is already encrypted.
3. **WireGuard tunnel**: All Tailscale traffic is encrypted at the network
   layer regardless of application-level TLS.

Caddy continues to serve `*.ops.eblu.me` with its existing Gandi DNS-01
certificates. The two TLS domains are completely independent.

## External references

- [Tailscale on Fly.io](https://tailscale.com/kb/1132/flydotio) — official guide for running Tailscale in a Fly.io container
- [Fly.io Custom Domains](https://fly.io/docs/networking/custom-domain/) — how Fly handles TLS for custom domains
- [Home Assistant + Fly.io + Tailscale](https://community.home-assistant.io/t/expose-ha-to-the-internet-via-a-cloud-reverse-proxy-fly-io-and-a-vpn-tailscale-for-free-for-now-without-opening-ports/352118) — community guide describing this exact pattern

---

## One-time setup (first service)

These steps establish the Fly.io proxy infrastructure. They only need to be done once.

### Step 1: Fly.io account and app

1. Create or recover a Fly.io account at https://fly.io (requires credit card for free tier)
2. Install `flyctl`: `brew install flyctl`
3. Authenticate: `fly auth login`
4. Create the app: `fly apps create blumeops-proxy`
5. Store the Fly.io deploy token in 1Password (blumeops vault):
   - Generate: `fly tokens create deploy -a blumeops-proxy`
   - Store as `fly-deploy-token` field

### Step 2: Repository structure

Create the `fly/` directory at the repository root. This is separate from `containers/` because the image is built and deployed directly to Fly.io by `fly deploy` — it never goes through `registry.ops.eblu.me`.

```
fly/
├── README.md           # Setup notes and context
├── fly.toml            # Fly.io app configuration
├── Dockerfile          # nginx + tailscale
├── nginx.conf          # Reverse proxy + cache config
└── start.sh            # Entrypoint: start tailscale, then nginx
```

**`fly/fly.toml`** — app configuration:

```toml
app = "blumeops-proxy"
primary_region = "sjc"

[build]

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1

[checks]
  [checks.health]
    port = 8080
    type = "http"
    interval = "30s"
    timeout = "5s"
    path = "/healthz"
```

**`fly/Dockerfile`** — nginx + tailscale:

```dockerfile
FROM nginx:alpine

# Copy tailscale binaries from official image
COPY --from=docker.io/tailscale/tailscale:stable \
    /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=docker.io/tailscale/tailscale:stable \
    /usr/local/bin/tailscale /usr/local/bin/tailscale

RUN mkdir -p /var/run/tailscale /var/lib/tailscale \
    && apk add --no-cache iptables ip6tables

COPY nginx.conf /etc/nginx/nginx.conf
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8080

CMD ["/start.sh"]
```

**`fly/start.sh`** — entrypoint:

```bash
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
```

**`fly/nginx.conf`** — reverse proxy with caching and rate limiting:

> The example below shows a **static site** configuration (docs.eblu.me).
> For dynamic services, see [[#Considerations for dynamic services]].

```nginx
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Rate limiting zones — define per-service zones as needed
    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;

    # Proxy cache: 200MB, evict after 24h of no access
    proxy_cache_path /tmp/cache levels=1:2 keys_zone=services:10m
                     max_size=200m inactive=24h;

    # --- docs.eblu.me (static site) ---
    server {
        listen 8080;
        server_name docs.eblu.me;

        limit_req zone=general burst=20 nodelay;

        location / {
            proxy_pass https://docs.tail8d86e.ts.net;
            proxy_ssl_verify off;
            proxy_ssl_server_name on;

            # Cache aggressively — static site only.
            # Do NOT use these settings for dynamic services.
            proxy_cache services;
            proxy_cache_valid 200 1d;
            proxy_cache_valid 404 1m;
            proxy_cache_use_stale error timeout updating;
            proxy_cache_lock on;

            # Prevent cache-busting: ignore query strings and
            # client cache-control headers.
            # Safe for static sites; breaks dynamic services.
            proxy_cache_key $host$uri;
            proxy_ignore_headers Cache-Control Set-Cookie;

            add_header X-Cache-Status $upstream_cache_status;
        }
    }

    # Catch-all: reject unknown hosts, but serve health check
    server {
        listen 8080 default_server;

        location /healthz {
            return 200 "ok\n";
        }

        location / {
            return 444;
        }
    }
}
```

### Step 3: Tailscale auth key and ACLs (Pulumi)

Extend the existing `pulumi/tailscale/` project.

**Add to `pulumi/tailscale/__main__.py`:**

```python
# Auth key for Fly.io proxy container
flyio_key = tailscale.TailnetKey(
    "flyio-proxy-key",
    reusable=True,
    ephemeral=True,
    preauthorized=True,  # Skip device approval on the tailnet
    tags=["tag:flyio-proxy"],
    expiry=7776000,  # 90 days
)
pulumi.export("flyio_authkey", flyio_key.key)
```

> **Note:** `preauthorized=True` is required if your tailnet has device
> approval enabled. Without it, each new container start (including
> health-check restarts) creates a node that needs manual approval,
> causing the container to hang before nginx starts.

**Add to `pulumi/tailscale/policy.hujson`:**

Tag owner (allows the k8s operator to assign this tag to Ingress proxy nodes):
```
"tag:flyio-target": ["autogroup:admin", "tag:blumeops", "tag:k8s-operator"],
```

Access grant (Fly.io proxy → explicitly tagged endpoints on HTTPS only):
```
{
    "src": ["tag:flyio-proxy"],
    "dst": ["tag:flyio-target"],
    "ip":  ["tcp:443"],
},
```

ACL test:
```
{
    "src":  "tag:flyio-proxy",
    "accept": ["tag:flyio-target:443"],
    "deny":   ["tag:k8s:443", "tag:homelab:443", "tag:homelab:22", "tag:nas:445", "tag:registry:443"],
},
```

Each service's Tailscale Ingress must be annotated with `tag:flyio-target` to be reachable by the proxy — see [[#7. Update Tailscale ACLs if needed]].

Deploy: `mise run tailnet-preview` then `mise run tailnet-up`.

After deploying, extract the auth key and set it as a Fly.io secret:

```bash
# Get the key from Pulumi state
cd pulumi/tailscale && pulumi stack output flyio_authkey --show-secrets

# Set it in Fly.io
fly secrets set TS_AUTHKEY="tskey-auth-..." -a blumeops-proxy
```

Store the auth key in 1Password as well for the `fly-setup` mise task.

### Step 4: Mise tasks

**`mise-tasks/fly-deploy`:**

```bash
#!/usr/bin/env bash
#MISE description="Deploy the Fly.io public proxy"

set -euo pipefail

cd "$(dirname "$0")/../fly"
fly deploy "$@"
```

**`mise-tasks/fly-setup`:**

```bash
#!/usr/bin/env bash
#MISE description="One-time setup: configure Fly.io secrets and certs (idempotent)"

set -euo pipefail

APP="blumeops-proxy"

# Fetch Tailscale auth key from Pulumi state
echo "Fetching Tailscale auth key from Pulumi..."
TS_AUTHKEY=$(cd "$(dirname "$0")/../pulumi/tailscale" && pulumi stack select tail8d86e && pulumi stack output flyio_authkey --show-secrets)
fly secrets set TS_AUTHKEY="$TS_AUTHKEY" --stage -a "$APP"
echo "Tailscale auth key staged (will take effect on next deploy)"

# Allocate IPs (idempotent — fly errors if already allocated)
# Shared IPv4 is free and sufficient for HTTP/HTTPS services.
# Use 'fly ips allocate-v4' (no --shared) for dedicated IPv4 ($2/mo)
# if the service needs non-HTTP protocols.
fly ips allocate-v4 --shared -a "$APP" 2>/dev/null || true
fly ips allocate-v6 -a "$APP" 2>/dev/null || true
echo "IPs allocated"

# Add certs for all public domains (idempotent — fly ignores duplicates)
fly certs add docs.eblu.me -a "$APP" 2>/dev/null || true
# fly certs add wiki.eblu.me -a "$APP" 2>/dev/null || true  # future services
echo "Certificates configured"

echo "Done. Run 'mise run fly-deploy' to deploy."
```

**`mise-tasks/fly-shutoff`:**

```bash
#!/usr/bin/env bash
#MISE description="Emergency shutoff: stop all Fly.io proxy machines"

set -euo pipefail

APP="blumeops-proxy"

echo "EMERGENCY SHUTOFF: Stopping all machines for $APP"
fly scale count 0 -a "$APP" --yes
echo "All machines stopped. Public services are offline."
echo "To restore: fly scale count 1 -a $APP"
```

### Step 5: Forgejo CI workflow

**`.forgejo/workflows/deploy-fly.yaml`:**

```yaml
name: Deploy Fly.io Proxy

on:
  workflow_dispatch:
  push:
    branches: [main]
    paths:
      - 'fly/**'

jobs:
  deploy:
    runs-on: k8s
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install flyctl
        run: |
          curl -L https://fly.io/install.sh | sh
          echo "/root/.fly/bin" >> "$GITHUB_PATH"

      - name: Deploy to Fly.io
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_DEPLOY_TOKEN }}
        run: |
          cd fly
          fly deploy

      - name: Verify health
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_DEPLOY_TOKEN }}
        run: |
          fly status -a blumeops-proxy
          echo ""
          echo "Health check:"
          sleep 10
          curl -sf https://blumeops-proxy.fly.dev/healthz || echo "Warning: health check failed (may need DNS propagation)"
```

The `FLY_DEPLOY_TOKEN` Forgejo Actions secret must be set via the [[forgejo]] API or UI, following the pattern in the `forgejo_actions_secrets` Ansible role.

---

## Per-service setup

To expose an additional service (example: `wiki.eblu.me`):

### 1. Add nginx server block

Edit `fly/nginx.conf` — add a new `server` block. The configuration
differs significantly between static and dynamic services.

**Static site example** (same pattern as docs):

```nginx
# --- wiki.eblu.me (static) ---
server {
    listen 8080;
    server_name wiki.eblu.me;

    limit_req zone=general burst=20 nodelay;

    location / {
        proxy_pass https://wiki.tail8d86e.ts.net;
        proxy_ssl_verify off;

        proxy_cache services;
        proxy_cache_valid 200 1d;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating;
        proxy_cache_lock on;
        proxy_cache_key $host$uri;
        proxy_ignore_headers Cache-Control Set-Cookie;

        add_header X-Cache-Status $upstream_cache_status;
    }
}
```

**Dynamic service example** (e.g., Forgejo):

```nginx
# --- forge.eblu.me (dynamic, authenticated) ---
server {
    listen 8080;
    server_name forge.eblu.me;

    # Higher rate limit — git operations, CI webhooks, and API calls
    # can legitimately burst. Forgejo also has its own rate limiting,
    # so this is a safety net, not the primary control.
    limit_req zone=general burst=50 nodelay;

    # Git LFS and repo uploads can be large
    client_max_body_size 512m;

    location / {
        proxy_pass https://forge.tail8d86e.ts.net;
        proxy_ssl_verify off;

        # NO proxy_cache — dynamic content with sessions.
        # Caching would serve stale pages and break authentication.

        # Pass through headers needed for proper proxying
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (Forgejo uses it for live updates)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Selectively cache static assets only
    location ~* \.(css|js|png|jpg|svg|woff2?)$ {
        proxy_pass https://forge.tail8d86e.ts.net;
        proxy_ssl_verify off;

        proxy_cache services;
        proxy_cache_valid 200 7d;
        proxy_cache_key $host$uri;

        add_header X-Cache-Status $upstream_cache_status;
    }
}
```

Key differences for dynamic services:
- **No blanket caching** — only static assets (CSS, JS, images) are cached
- **Respect `Set-Cookie`** — do not ignore session headers
- **Include query strings** in non-cached requests (default behavior when
  `proxy_cache_key` is not overridden)
- **Higher rate limits** — legitimate usage patterns are burstier
- **Proxy headers** — pass `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`
  so the backend sees the real client IP (important for Forgejo's audit logs
  and its own rate limiting)
- **WebSocket support** — many modern web apps use WebSockets
- **Larger body size** — git pushes and file uploads need more than the default 1MB

### 2. Add Fly.io certificate

```bash
fly certs add wiki.eblu.me -a blumeops-proxy
```

Or add it to `mise-tasks/fly-setup` so it's captured for future runs.

### 3. Deploy

```bash
mise run fly-deploy
```

Or push the `fly/nginx.conf` change to main — the Forgejo workflow deploys automatically.

### 4. Verify against fly.dev

Test the proxy before touching DNS. Use the `Host` header to simulate
the real domain:

```bash
# Health check
curl -sf https://blumeops-proxy.fly.dev/healthz

# Simulate real domain request
curl -I -H "Host: wiki.eblu.me" https://blumeops-proxy.fly.dev/
# Should return 200 with X-Cache-Status header
```

If this fails, debug without any public DNS impact.

### 5. Add DNS CNAME (Pulumi)

Only after verifying the proxy works. Add to `pulumi/gandi/__main__.py`:

```python
wiki_public = gandi.livedns.Record(
    "wiki-public",
    zone=domain,
    name="wiki",
    type="CNAME",
    ttl=300,
    values=["blumeops-proxy.fly.dev."],
)
```

Deploy: `mise run dns-preview` then `mise run dns-up`.

### 6. Verify with real domain

```bash
curl -I https://wiki.eblu.me
# Should return 200 with X-Cache-Status header
```

### 7. Tag the Tailscale Ingress with `tag:flyio-target`

The fly.io proxy can only reach endpoints tagged with `tag:flyio-target`. Add the annotation to the service's Tailscale Ingress:

```yaml
annotations:
  tailscale.com/tags: "tag:k8s,tag:flyio-target"
```

Include `tag:k8s` to preserve existing access rules for the Ingress proxy node. The `tag:flyio-target` tag opts this specific endpoint into being reachable by the fly.io proxy — no broad ACL changes needed.

For non-k8s services (e.g., Forgejo on indri), create a k8s ExternalName Service pointing to the host, then a Tailscale Ingress with the same annotation.

---

## Security

### DDoS and rate limiting

This approach provides basic protection, not enterprise-grade:

- **Fly.io Anycast** absorbs volumetric L3/L4 attacks
- **nginx `limit_req`** caps per-IP request rates at the container level
- **nginx `proxy_cache`** serves most requests from cache — only cache
  misses traverse the Tailscale tunnel to indri

For **static sites**, the cache is the primary defense. Most requests
never reach the origin. Cache-busting is mitigated by ignoring query
strings (`proxy_cache_key $host$uri`) and client cache-control headers.

For **dynamic services**, the cache covers only static assets. Most
requests flow through the Tailscale tunnel to indri on every hit. This
makes dynamic services significantly more vulnerable to L7 DDoS — an
attacker sending high volumes of legitimate-looking requests (login
pages, API endpoints, search queries) bypasses the cache entirely.
Mitigations for dynamic services:

- nginx `limit_req` is the primary defense at the proxy layer — tune
  the rate and burst per service
- The backend service's own rate limiting (e.g., Forgejo's built-in
  rate limiter) provides a second layer
- fail2ban on indri (see below) can block IPs showing abuse patterns
- The break-glass shutoff remains the last resort

If a publicly exposed dynamic service attracts targeted attacks or the
home network bandwidth is impacted, consider migrating to Cloudflare
Tunnel for enterprise-grade DDoS protection (requires DNS migration;
see plan history in git).

### fail2ban

fail2ban monitors log files for repeated failed authentication attempts
(SSH brute force, bad login passwords, API abuse) and bans IPs via
firewall rules.

**Static sites**: fail2ban does not apply. There is no login surface,
no sessions, no credentials to brute force.

**Dynamic services with authentication** (e.g., Forgejo): fail2ban is
relevant and should be configured on **indri**, not on Fly.io. The
nginx proxy is transparent — it forwards requests but does not see
authentication outcomes. fail2ban watches the service's own logs on
indri for patterns like repeated failed logins.

Setup considerations for Forgejo specifically:

- Forgejo logs failed auth attempts to its log file
- fail2ban needs a filter matching Forgejo's log format
- Banned IPs are blocked at indri's firewall (the Fly.io proxy IP is
  the Tailscale address of the `flyio-proxy` node, not the end user's
  IP)
- **Important**: for fail2ban to see real client IPs, the nginx proxy
  must pass `X-Real-IP` / `X-Forwarded-For` headers (included in the
  dynamic service nginx config above), and Forgejo must be configured
  to trust the proxy and log the forwarded IP rather than the proxy's
  Tailscale IP
- Disable open user registration before exposing Forgejo publicly —
  require explicit invites

### Break-glass shutoff

If the proxy is causing issues, stop it immediately:

```bash
mise run fly-shutoff
```

This stops all machines in seconds — zero traffic reaches indri. See [[manage-flyio-proxy#Emergency Shutoff]] for the full escalation ladder (container stop → Tailscale revoke → DNS removal).

---

## Considerations for dynamic services

The architecture described in this guide works for both static and dynamic
services, but the nginx configuration and security posture differ
significantly. This section summarizes what changes when exposing a
dynamic, authenticated service like [[forgejo]].

| Concern | Static site | Dynamic service |
|---------|-------------|-----------------|
| Caching | Aggressive (cache everything, 1d TTL) | Static assets only, or disabled |
| Session cookies | Ignored (`proxy_ignore_headers Set-Cookie`) | Must be passed through |
| Query strings | Ignored in cache key | Included (default behavior) |
| Rate limiting | 10r/s is plenty | Higher burst needed; coordinate with backend rate limiter |
| Request body size | Default 1MB is fine | Increase for uploads (`client_max_body_size`) |
| WebSocket | Not needed | Often needed (`proxy_http_version 1.1`, `Upgrade` headers) |
| Proxy headers | Optional | Required (`X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`) |
| fail2ban | Not applicable | Configure on indri, watching service logs |
| DDoS exposure | Low — cache absorbs most traffic | Higher — most requests hit origin |
| Pre-exposure checklist | Deploy and go | Disable open registration, audit access controls, configure fail2ban |

### Checklist before exposing a dynamic service

- [ ] Disable open user registration (require invites or admin approval)
- [ ] Audit access controls and permissions
- [ ] Configure the service to log the forwarded client IP (not the proxy IP)
- [ ] Set up fail2ban on indri with a filter for the service's log format
- [ ] Tag the service's Tailscale Ingress with `tag:flyio-target`
- [ ] Test the nginx config locally or in staging before deploying
- [ ] Rehearse the break-glass shutoff (`mise run fly-shutoff`)

---

## IaC summary

| Component | Managed by | Declarative? |
|-----------|------------|:---:|
| Tailscale auth key | Pulumi (`pulumi/tailscale/`) | yes |
| Tailscale ACLs | Pulumi (`pulumi/tailscale/policy.hujson`) | yes |
| DNS CNAMEs | Pulumi (`pulumi/gandi/`) | yes |
| Container + app config | `fly/Dockerfile` + `fly/fly.toml` in repo | yes |
| Deployment | Forgejo CI on push to `fly/`, or `mise run fly-deploy` | yes |
| Fly.io secrets + certs | `mise run fly-setup` (one-time, idempotent) | semi |

The "semi" for Fly.io secrets is a one-time operation backed by a repeatable mise task. Fly.io does not have a mature Pulumi or Terraform provider, so `fly.toml` + `flyctl` is the standard IaC model for Fly.io apps.

---

## Verification

### Pre-DNS (verify against fly.dev)

Test the proxy works before creating any public DNS records:

1. `curl -sf https://blumeops-proxy.fly.dev/healthz` — returns `ok`
2. `curl -I -H "Host: docs.eblu.me" https://blumeops-proxy.fly.dev/` — returns 200 with `X-Cache-Status` header
3. `fly status -a blumeops-proxy` — shows healthy machine
4. All `*.ops.eblu.me` services still work from tailnet (unchanged)
5. `mise run services-check` passes

If anything fails here, debug without public DNS impact.

### Post-DNS (after CNAME is live)

After deploying DNS (`mise run dns-up`):

1. `curl -I https://docs.eblu.me` — returns 200 with `X-Cache-Status` header
2. `dig docs.eblu.me` — resolves to Fly.io IPs (not Tailscale IP)
3. `dig forge.ops.eblu.me` — still resolves to indri's Tailscale IP (unchanged)
4. Second request to same URL shows `X-Cache-Status: HIT`
