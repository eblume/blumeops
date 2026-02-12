---
title: Fly.io Proxy
date-modified: 2026-02-08
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

## Architecture

Internet traffic hits Fly.io's Anycast edge, terminates TLS with a Let's Encrypt certificate, and is proxied by nginx to the backend service over a Tailscale WireGuard tunnel. See [[expose-service-publicly]] for the full architecture diagram.

## Key Files

| File | Purpose |
|------|---------|
| `fly/fly.toml` | App configuration |
| `fly/Dockerfile` | nginx + Tailscale + Alloy container |
| `fly/nginx.conf` | Reverse proxy, caching, rate limiting, JSON logging |
| `fly/alloy.river` | Alloy config: log tailing, metric extraction, remote_write |
| `fly/start.sh` | Entrypoint: start Tailscale, Alloy, then nginx |
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
  - `flyio_nginx_http_request_duration_seconds` — latency histogram
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

Currently tagged as `tag:flyio-target`: [[docs]], [[loki]], [[prometheus]]. Loki and Prometheus are tagged so that [[alloy|Alloy]] (running inside the container) can push logs and metrics directly via their Tailscale Ingress endpoints — the restricted ACL means Caddy on indri (`tag:homelab`) is not reachable from the proxy.

To expose an additional service through the proxy, add the `tag:flyio-target` annotation to its Tailscale Ingress. See [[expose-service-publicly]] for the full workflow.

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
