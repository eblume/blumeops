---
title: Fly.io Proxy
modified: 2026-04-17
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

| Public domain | Backend | Service |
|---------------|---------|---------|
| `docs.eblu.me` | `docs.tail8d86e.ts.net` | [[docs]] |
| `cv.eblu.me` | `cv.tail8d86e.ts.net` | [[cv]] |
| `forge.eblu.me` | `forge.tail8d86e.ts.net` | [[forgejo]] |

## Architecture

Internet traffic hits Fly.io's Anycast edge, terminates TLS with a Let's Encrypt certificate, and is proxied by nginx to the backend service over a Tailscale WireGuard tunnel. See [[expose-service-publicly]] for the full architecture diagram.

### Upstream Keepalive

Nginx uses `upstream` blocks with `keepalive` connection pools to reuse TLS connections through the WireGuard tunnel. This avoids a per-request TLS handshake, which was previously the dominant source of latency (35s+ p50 before keepalive, sub-second after).

**Trade-off:** DNS for upstream hostnames is resolved once at config load, not per-request. If Tailscale Ingress pods get new IPs (restart, reschedule, minikube restart), run `mise run fly-reload` to re-resolve without a full redeploy. A Grafana alert fires when upstreams are unreachable.

Each upstream requires `proxy_ssl_name` set to the actual Tailscale hostname — nginx sends the upstream block name as SNI by default, which the Tailscale Ingress proxy won't recognize.

## Key Files

| File | Purpose |
|------|---------|
| `fly/fly.toml` | App configuration |
| `fly/Dockerfile` | nginx + Tailscale + Alloy container |
| `fly/nginx.conf` | Reverse proxy, caching, rate limiting, JSON logging |
| `fly/alloy.river` | Alloy config: log tailing, metric extraction, remote_write |
| `fly/start.sh` | Entrypoint: start Tailscale, wait for MagicDNS, then nginx + Alloy |
| `pulumi/tailscale/__main__.py` | Auth key (`tag:flyio-proxy`) |
| `pulumi/tailscale/policy.hujson` | ACL grants for proxy |
| `pulumi/gandi/__main__.py` | DNS CNAMEs |

## Networking

Fly.io runs Firecracker microVMs which support TUN devices natively. Tailscale runs with a real TUN interface (not userspace networking), so MagicDNS and direct Tailscale IP routing work normally.

The Tailscale auth key is `preauthorized=True` to avoid device approval hangs on container restarts.

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

The `tag:flyio-proxy` ACL grants access only to `tag:flyio-target:443`. Services must explicitly opt in by adding a `tailscale.com/tags: "tag:k8s,tag:flyio-target"` annotation to their Tailscale Ingress. This means the proxy can only reach endpoints that have been individually tagged — a compromised nginx config cannot route to arbitrary services on the tailnet.

Currently tagged as `tag:flyio-target`: [[docs]], [[cv]], [[forgejo]], [[loki]], [[prometheus]]. Loki and Prometheus are tagged so that [[alloy|Alloy]] (running inside the container) can push logs and metrics directly via their Tailscale Ingress endpoints — the restricted ACL means Caddy on indri (`tag:homelab`) is not reachable from the proxy.

### Crawler Mitigation

The proxy serves a `robots.txt` blocking crawlers from expensive endpoints:

- `/mirrors/` — large mirrored repos
- `/user/` — auth endpoints (crawlers follow redirect loops)
- `/users/` — user profile pages
- `/*/archive/` — git bundle generation (DoS vector, see below)
- `/*/releases/download/` — release artifacts

Archive requests (`/<owner>/<repo>/archive/*`) are 302-redirected to `forge.ops.eblu.me` (tailnet-only), preventing unauthenticated archive generation. This mitigates a known Forgejo DoS vector where crawlers requesting unique commit SHAs trigger unbounded git bundle generation.

Release downloads are cached at the proxy layer (7-day TTL, keyed by URI) to absorb repeated downloads of the same artifact.

To expose an additional service through the proxy, add the `tag:flyio-target` annotation to its Tailscale Ingress. See [[expose-service-publicly]] for the full workflow.

## Spider Trap Mitigation

The SPA fallback (`try_files ... /index.html`) serves `index.html` with a 200 for *any* URI, including non-existent paths. Quartz's relative links (`../path`) compound when resolved from phantom URLs, creating an infinite tree of unique URIs that crawlers follow indefinitely. In March 2026, Meta's crawler (`meta-externalagent/1.1`) hit ~49,000 unique URIs over 7 hours this way.

Two nginx `location` guards in `containers/quartz/default.conf` mitigate the trap:

1. **`/tags/` depth limit** — `/tags/<name>` is always flat; anything deeper returns 404.
2. **Global depth-5 cutoff** — real content never exceeds depth 4; paths with 5+ segments return 404.

These are applied in the Quartz container's nginx config, not the Fly.io proxy. The proper fix is switching Quartz to root-absolute links (planned for the fork).

## Secrets

| Secret | Source | Description |
|--------|--------|-------------|
| `TS_AUTHKEY` | Pulumi state → `fly secrets` | Tailscale auth key for joining tailnet |
| `FLY_DEPLOY_TOKEN` | Fly.io → 1Password | Deploy token for CI |

## Related

- [[expose-service-publicly]] - Setup guide for adding new public services
- [[manage-flyio-proxy]] - Operational tasks (deploy, shutoff, troubleshoot)
- [[caddy]] - Private reverse proxy for `*.ops.eblu.me` (separate system)
- [[tailscale]] - WireGuard mesh network
- [[gandi]] - DNS hosting
