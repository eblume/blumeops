---
title: Gandi
modified: 2026-04-27
last-reviewed: 2026-04-27
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
| **PAT** | `op://blumeops/gandi - blumeops/pat` |

## What It Does

Gandi hosts the DNS records that make `*.ops.eblu.me` resolve to [[indri]]'s Tailscale IP. Since Tailscale IPs are not publicly routable, this gives services real DNS names while keeping them private to the tailnet. The target IP is resolved dynamically from `indri.tail8d86e.ts.net` at deploy time.

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
| `cv.eblu.me` | CNAME | `blumeops-proxy.fly.dev` | 300s |
| `forge.eblu.me` | CNAME | `blumeops-proxy.fly.dev` | 300s |

Public CNAMEs point to [[flyio-proxy]] on Fly.io. See [[expose-service-publicly]] for adding new public services. See [[routing]] for the full service URL map.

## TLS Integration

[[caddy]] uses this same Gandi PAT for ACME DNS-01 challenges to obtain a wildcard Let's Encrypt certificate for `*.ops.eblu.me`. Caddy reads the PAT from `~/.config/caddy/gandi-token` on [[indri]], populated by ansible from 1Password.

## Authentication

One Gandi Personal Access Token, shared by Pulumi and Caddy. Gandi caps PATs at 90 days; rotate every 60 days via [[rotate-gandi-pat]].

## ACME Challenge Cleanup

Caddy's renewal flow leaves `_acme-challenge.ops` TXT orphans in the zone — a value-comparison bug in `libdns/gandi` v1.1.0 makes the cleanup phase a no-op. Run `mise run dns-acme-cleanup` periodically (alongside PAT rotation works well).

## Related

- [[manage-eblu-me-dns]] — Add/change DNS records via Pulumi
- [[rotate-gandi-pat]] — Rotate the shared Gandi PAT
- [[routing]] — Service URLs and routing architecture
- [[caddy]] — Reverse proxy using this PAT for TLS
- [[tailscale]] — Tailnet networking
- [[indri]] — Server hosting Caddy (DNS target)
