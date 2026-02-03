---
title: Loki
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
- Logs collected by [[Grafana Alloy|Alloy]] and pushed via Loki API
- Queried via [[Grafana]]

## Log Sources

**From Indri (via Alloy):**
- forgejo, tailscale (brew services)
- alloy, borgmatic, zot, jellyfin (LaunchAgents)

**From Kubernetes (via Alloy DaemonSet):**
- All pods in all namespaces

## Query Examples (LogQL)

```logql
{service="forgejo"}                     # All forgejo logs
{service="borgmatic", stream="stderr"}  # Borgmatic errors
{host="indri"} |= "error"               # All logs containing "error"
```

## Related

- [[Grafana Alloy|Alloy]] - Log collector
- [[Grafana]] - Log visualization
- [[Prometheus]] - Metrics counterpart
