---
title: Alloy
date-modified: 2026-02-08
tags:
  - service
  - observability
---

# Grafana Alloy

Unified observability collector for metrics and logs with three deployments:
1. **Indri (host)** - System metrics and service logs from macOS host
2. **Kubernetes (DaemonSet)** - Automatic pod log collection and service health probes
3. **Fly.io proxy (embedded)** - nginx access log metrics and log forwarding from [[flyio-proxy]]

## Quick Reference

| Property | Value |
|----------|-------|
| **Indri Binary** | `~/.local/bin/alloy` |
| **Indri Config** | `~/.config/grafana-alloy/config.alloy` |
| **K8s Namespace** | `alloy` |
| **K8s Image** | `grafana/alloy:v1.8.2` |
| **ArgoCD App** | `alloy-k8s` |
| **Fly.io Config** | `fly/alloy.river` |
| **Fly.io Image** | `grafana/alloy:v1.5.1` (binary copied into nginx container) |

## Metrics Collected

### From Indri
- System metrics via `prometheus.exporter.unix`
- Textfile collector: `minikube.prom`, `borgmatic.prom`, `zot.prom`, `jellyfin.prom`
- Zot registry metrics from `http://localhost:5050/metrics`
- Pushed to [[prometheus]] via remote_write

### From Kubernetes
- All pod logs via `loki.source.kubernetes`
- Service health probes: miniflux, kiwix, transmission, devpi, argocd

### From Fly.io Proxy
- `flyio_nginx_http_requests_total` — request rate by status/method/host
- `flyio_nginx_http_request_duration_seconds` — latency histogram
- `flyio_nginx_http_response_bytes_total` — response bandwidth
- `flyio_nginx_cache_requests_total` — cache HIT/MISS/EXPIRED counts
- Pushed to [[prometheus]] via remote_write through [[caddy]]

## Logs Collected

**Brew services:** forgejo, tailscale

**mcquack LaunchAgents:** alloy, borgmatic, zot, jellyfin

Logs pushed to [[loki]] at `https://loki.tail8d86e.ts.net/loki/api/v1/push`.

**Fly.io proxy:** nginx JSON access logs pushed to [[loki]] at `https://loki.ops.eblu.me/loki/api/v1/push` (via [[caddy]]).

## Why Built from Source

The Homebrew bottle uses `CGO_ENABLED=0`, which breaks Tailscale MagicDNS. Building with `CGO_ENABLED=1` uses the macOS native resolver.

**Note:** This may no longer be needed now that services use `*.ops.eblu.me` URLs (routed via Caddy) instead of `*.tail8d86e.ts.net`. Should be tested in the future.

## Related

- [[prometheus]] - Metrics storage
- [[loki]] - Log storage
- [[grafana]] - Visualization
