---
title: Ntfy
modified: 2026-02-17
tags:
  - service
  - notifications
---

# Ntfy

Self-hosted push notification service. Ntfy receives HTTP POST messages and delivers them to subscribed clients (mobile apps, web UI, CLI).

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://ntfy.ops.eblu.me |
| **Tailscale URL** | https://ntfy.tail8d86e.ts.net |
| **Namespace** | `ntfy` |
| **Image** | `binwiederhier/ntfy:v2.17.0` |
| **Upstream** | https://github.com/binwiederhier/ntfy |
| **Manifests** | `argocd/manifests/ntfy/` |

## Architecture

Ntfy runs as a single pod with no persistent storage — message cache and attachments use an `emptyDir` volume. This is intentional: ntfy is treated as an ephemeral delivery channel, not a message store. Messages lost on pod restart are acceptable.

The upstream relay (`ntfy.sh`) is configured so mobile app clients can receive push notifications via Google FCM / Apple APNs without self-hosting those integrations.

## Producers

Currently the only producer is **frigate-notify**, which publishes camera detection alerts (person, vehicle, animal) from [[frigate|Frigate]] via MQTT to ntfy:

```
Frigate → MQTT (Mosquitto) → frigate-notify → ntfy → mobile clients
```

The frigate-notify config points to ntfy's cluster-internal address:

```
http://ntfy.ntfy.svc.cluster.local:80
```

Other services could publish to ntfy in the future — any HTTP client can POST to a topic.

## Configuration

Server config is in a ConfigMap (`ntfy-config`):

| Setting | Value |
|---------|-------|
| `base-url` | `https://ntfy.ops.eblu.me` |
| `upstream-base-url` | `https://ntfy.sh` |
| `attachment-total-size-limit` | 1 GB |
| `attachment-file-size-limit` | 10 MB |
| `attachment-expiry-duration` | 24h |

No authentication is configured — access is restricted by Tailscale ACLs (only tailnet clients can reach the service).

## Related

- [[routing]] - How ntfy is exposed via Caddy
- [[observability]] - Monitoring and alerting infrastructure
