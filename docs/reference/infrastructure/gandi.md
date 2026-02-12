---
title: Gandi
date-modified: 2026-02-08
tags:
  - infrastructure
  - networking
  - dns
---

# Gandi

DNS hosting provider for the `eblu.me` domain, managed via Pulumi IaC.

## Quick Reference

| Property | Value |
|----------|-------|
| **Domain** | `eblu.me` |
| **Provider** | Gandi LiveDNS |
| **IaC** | `pulumi/gandi/` |
| **Stack** | `eblu-me` |

## What It Does

Gandi hosts the DNS records that make `*.ops.eblu.me` resolve to [[indri]]'s Tailscale IP (`indri.tail8d86e.ts.net`). Since Tailscale IPs are not publicly routable, this gives services real DNS names while keeping them private to the tailnet.

The target IP is resolved dynamically from `indri.tail8d86e.ts.net` at deploy time, so if indri's Tailscale IP changes, re-running the deployment is sufficient.

## DNS Records

### Private services (Caddy on indri)

| Record | Type | Value | TTL |
|--------|------|-------|-----|
| `*.ops.eblu.me` | A | indri's Tailscale IP | 300s |
| `ops.eblu.me` | A | indri's Tailscale IP | 300s |

Both records point to [[indri]], which runs [[caddy]] as the reverse proxy for all private services.

### Public services (Fly.io proxy)

| Record | Type | Value | TTL |
|--------|------|-------|-----|
| `docs.eblu.me` | CNAME | `blumeops-proxy.fly.dev` | 300s |

Public CNAMEs point to [[flyio-proxy]] on Fly.io. See [[expose-service-publicly]] for adding new public services.

See [[routing]] for the full service URL map.

## Pulumi Configuration

The Pulumi program lives in `pulumi/gandi/`:

- `__main__.py` - Creates the two A records via `pulumiverse_gandi`
- `Pulumi.eblu-me.yaml` - Stack config (domain, subdomain)

Stack config values:

| Key | Value |
|-----|-------|
| `blumeops-dns:domain` | `eblu.me` |
| `blumeops-dns:subdomain` | `ops` |

A break-glass override is available via the `BLUMEOPS_REVERSE_PROXY_IP` environment variable, which bypasses dynamic IP resolution.

## TLS Integration

[[caddy]] uses Gandi's API separately (via `GANDI_BEARER_TOKEN`) for ACME DNS-01 challenges to obtain a wildcard Let's Encrypt certificate for `*.ops.eblu.me`. This is a different credential from the Pulumi PAT.

## Authentication

Gandi requires a Personal Access Token (PAT) for API access. PATs have a maximum lifetime of 90 days (currently set to 30). See [[gandi-operations]] for deployment and PAT cycling instructions.

## Related

- [[gandi-operations]] - PAT cycling and deployment how-to
- [[routing]] - Service URLs and routing architecture
- [[caddy]] - Reverse proxy using Gandi for TLS
- [[tailscale]] - Tailnet networking
- [[indri]] - Server hosting Caddy (DNS target)
