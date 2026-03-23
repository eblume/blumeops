---
title: Loki
modified: 2026-03-23
last-reviewed: 2026-03-23
tags:
  - service
  - observability
---

# Loki

Log aggregation system for BlumeOps infrastructure.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://loki.ops.eblu.me |
| **Namespace** | `monitoring` |
| **Image** | `registry.ops.eblu.me/blumeops/loki` (see `argocd/manifests/loki/kustomization.yaml` for current tag) |
| **Storage** | 50Gi PVC |
| **Retention** | 31 days |

## Architecture

- Single-node deployment with filesystem storage
- TSDB index with 24h period
- Logs collected by [[alloy|Alloy]] and pushed via Loki API
- Queried via [[grafana]]

## Log Sources

**From Indri (via Alloy):**
- forgejo, tailscale (brew services)
- alloy, borgmatic, zot, jellyfin (LaunchAgents)

**From Kubernetes (via Alloy DaemonSet):**
- All pods in all namespaces

**From Fly.io proxy (via embedded Alloy):**
- nginx JSON access logs (`{instance="flyio-proxy", job="flyio-nginx"}`)

## Query Examples (LogQL)

```logql
{service="forgejo"}                     # All forgejo logs
{service="borgmatic", stream="stderr"}  # Borgmatic errors
{host="indri"} |= "error"               # All logs containing "error"
{instance="flyio-proxy"} |= "docs.eblu.me" # Fly.io proxy access logs for docs
```

## Related

- [[alloy|Alloy]] - Log collector
- [[grafana]] - Log visualization
- [[prometheus]] - Metrics counterpart
