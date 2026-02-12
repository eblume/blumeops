---
title: Loki
date-modified: 2026-02-08
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
| **Tailscale URL** | https://loki.tail8d86e.ts.net |
| **Namespace** | `monitoring` |
| **Image** | `grafana/loki:3.4.2` |
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
