---
title: Fly.io Proxy
modified: 2026-09-28
last-reviewed: 2026-09-28
tags:
  - service
  - networking
  - fly-io
---

# Fly.io Proxy

Public reverse proxy on [Fly.io](https://fly.io) that exposes selected BlumeOps services to the internet via a Tailscale tunnel back to the homelab.

## Quick Reference

| Property | Value |
|----------|-------|
| **App** | `blumeops-proxy` |
| **Region** | `sjc` (San Jose) |
| **Fly.io URL** | `blumeops-proxy.fly.dev` |
| **Config** | `fly/` directory in repo |
| **IaC** | `fly/fly.toml` (app), Pulumi (DNS + auth key) |

## Exposed Services

| Public domain | Backend (via Caddy) | Service |
|---------------|---------------------|---------|
| `eblu.me`, `www.eblu.me` | *(served at the edge)* | Apex landing page |
| `docs.eblu.me` | `docs.ops.eblu.me` | [[docs]] |
| `cv.eblu.me` | `cv.ops.eblu.me` | [[cv]] |
| `forge.eblu.me` | *(served at the edge — Fly volume)* | [[#Static forge mirror]] |
| `photos.eblu.me` | `photos.ops.eblu.me` | [[immich]] (shared links only) |
| `blumeops-proxy.fly.dev` | *(served at the edge — Fly volume)* | [[#Static forge mirror]] (staging, same content) |

The apex landing page is the one service **not** tunneled to indri: it's a
single static "under construction" splash served straight from nginx (files
under `fly/landing/`, baked into the image), so it survives an indri or tunnel
outage. Because a `CNAME` is illegal at the zone apex, `eblu.me` uses `A`/`AAAA`
records to Fly's ingress IPs rather than the `CNAME` the subdomains use.

## Static forge mirror

Read-only mirror of the allowlisted public forge repos, served at the edge
from a Fly volume (stagit HTML + git dumb HTTP, pushed by the private
forge's push mirrors over tailnet SSH). Served at the public name
`forge.eblu.me` — the CNAME points at the Fly app, so there is no relay to
indri (the old dynamic Forgejo relay was retired in the public/private
split, [eblume/blumeops#1208](https://forge.eblu.me/eblume/blumeops/issues/1208));
`blumeops-proxy.fly.dev` (the app's free hostname) serves the same content
as a staging surface. Every path the static site does not serve 302s to
`forge.ops.eblu.me`. Design and operations: `fly/git-mirror/README.md`,
[[manage-flyio-proxy#Static Forge Mirror]].

## Architecture

Internet traffic hits Fly.io's Anycast edge, terminates TLS with a Let's Encrypt certificate, and is proxied by nginx to [[caddy]] on [[indri]] over a direct Tailscale WireGuard tunnel. Caddy then routes to the actual service. See [[expose-service-publicly]] for the full architecture diagram.

### Why Caddy, not per-service Tailscale Ingress?

Previously, nginx connected directly to each service's `*.tail8d86e.ts.net` Tailscale Ingress endpoint. This caused **20+ second latency** because the Tailscale Ingress pods (running inside k8s) are behind pod-network NAT and can only reach the Fly VM via Tailscale DERP relay servers — not direct WireGuard peering.

Routing through Caddy on indri solves this because indri's host-level Tailscale can establish direct WireGuard connections with the Fly VM (45ms round trip). This generalizes to all services regardless of where they run (native on indri or ringtail k3s), since Caddy already routes to everything.

### Direct WireGuard Peering

The Fly VM pins its Tailscale WireGuard listener to port 41641 (`tailscaled --port=41641`). Combined with well-behaved NAT on both sides (`MappingVariesByDestIP: false`), this allows Tailscale to establish direct peer-to-peer connections via UDP hole punching — no dedicated IPv4 required.

If direct peering fails (observable via `tailscale ping indri` showing "via DERP"), allocate a dedicated IPv4 ($2/month) with `fly ips allocate-v4` to provide a guaranteed inbound UDP path.

## Key Files

| File | Purpose |
|------|---------|
| `fly/fly.toml` | App configuration |
| `fly/Dockerfile` | nginx + Tailscale + Alloy container |
| `fly/nginx.conf` | Reverse proxy, caching, rate limiting, JSON logging |
| `fly/landing/` | Apex landing page (`index.html` + construction GIF), served at the edge |
| `fly/alloy.river` | Alloy config: log tailing, metric extraction, remote_write |
| `fly/start.sh` | Entrypoint: start Tailscale, wait for MagicDNS, then nginx + Alloy |
| `pulumi/tailscale/__main__.py` | Auth key (`tag:flyio-proxy`) |
| `pulumi/tailscale/policy.hujson` | ACL grants for proxy |
| `pulumi/gandi/__main__.py` | DNS: subdomain CNAMEs + apex `A`/`AAAA` |
| `fly/git-mirror/` | Static forge mirror: allowlist, push hooks, scripts |

## Networking

Fly.io runs Firecracker microVMs which support TUN devices natively. Tailscale runs with a real TUN interface (not userspace networking), so MagicDNS and direct Tailscale IP routing work normally.

The `tailscaled` process is started with `--port=41641` to pin the WireGuard listener to a fixed port. This is critical for direct peering — without it, hole punching is unreliable. A `[[services]]` block in `fly.toml` exposes this port as UDP, though it is only active when a dedicated IPv4 is allocated.

The Tailscale auth key is `preauthorized=True` to avoid device approval hangs on container restarts, and `ephemeral=True` so offline nodes auto-GC. The node key now persists on the `git_mirror` Fly volume (bind-mounted over `/var/lib/tailscale`), so a restart reconnects with the existing identity and the `flyio-proxy` name is stable; only a long-offline reclaim (the key is ephemeral) re-auths and may take the name back. See [[manage-flyio-proxy#Tailscale Node Name Drift]].

## Observability

[[alloy|Alloy]] runs inside the container alongside nginx and Tailscale, providing:

- **Logs**: nginx JSON access logs tailed and pushed to [[loki|Loki]] (`{instance="flyio-proxy", job="flyio-nginx"}`)
- **Metrics**: Derived from access logs, pushed to [[prometheus|Prometheus]] via `remote_write`
  - `flyio_nginx_http_requests_total` — request rate by status/method/host
  - `flyio_nginx_http_request_duration_seconds` — total request latency histogram (includes proxy overhead)
  - `flyio_nginx_upstream_response_time_seconds` — backend response time histogram (Forgejo processing only)
  - `flyio_nginx_http_response_bytes_total` — response bandwidth
  - `flyio_nginx_cache_requests_total` — cache HIT/MISS/EXPIRED counts

### Dashboards

| Dashboard | Purpose |
|-----------|---------|
| **Docs APM** | Per-service view for `docs.eblu.me`: request rate, latency percentiles, cache hit ratio, error rate, bandwidth, access logs |
| **Fly.io Proxy Health** | Aggregate proxy health: connections, total request rate by host, cache performance, upstream latency, Alloy health |

Alloy listens on `127.0.0.1:12345` for self-scraping its `/metrics` endpoint. All metrics carry `instance="flyio-proxy"`.

## Security Considerations

The `tag:flyio-proxy` ACL grants outbound access only to `tag:flyio-target:443`. Indri carries this tag (for Caddy), and the k8s Tailscale Ingress pods for Loki and Prometheus also carry it so [[alloy|Alloy]] can push logs and metrics directly. A compromised proxy cannot route to arbitrary services on the tailnet — only `tag:flyio-target` endpoints on port 443. The one inbound *service* grant to the proxy node is `tag:forge` → `tag:flyio-proxy` on tcp:22 (the forge's push-mirror sync into the static mirror's git-shell `mirror` account — forced git commands, no login); the admin wildcard grant still reaches every port.

### Crawler Mitigation

The `forge.eblu.me` static mirror serves a `robots.txt` disallowing the whole
path (crawlers are not the audience; the clone endpoint is dumb-HTTP git, not
a crawl target), and the edge rejects declared AI crawlers with a bare 403
before the Anubis proof-of-work hop (see [[ai-scraper-mitigation]]). The old
relay's per-endpoint defenses — the `/mirrors/` blackhole, the
`/*/archive/` → tailnet 302, and the 7-day release-download cache — were
retired with the relay, because the static mirror serves source only: there is
no `/mirrors/` tree, no on-demand archive generation, and no release
artifacts to cache.

To expose an additional service through the proxy, add a Caddy route for it and an nginx `server` block. See [[expose-service-publicly]] for the full workflow.

## Secrets

| Secret | Source | Description |
|--------|--------|-------------|
| `TS_AUTHKEY` | Pulumi state → `fly secrets` | Tailscale auth key for joining tailnet |
| `FLY_DEPLOY_TOKEN` | Fly.io → 1Password | Deploy token for CI |

## Related

- [[expose-service-publicly]] - Setup guide for adding new public services
- [[manage-flyio-proxy]] - Operational tasks (deploy, shutoff, troubleshoot)
- [[caddy]] - Private reverse proxy for `*.ops.eblu.me` (separate system)
- [[docs-on-indri]] - Where `docs.eblu.me` is served today (static site on indri)
- [[tailscale]] - WireGuard mesh network
- [[gandi]] - DNS hosting
