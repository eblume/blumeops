---
title: Tailscale
tags:
  - infrastructure
  - network
---

# Tailscale

Tailnet `tail8d86e.ts.net` provides secure networking for all BlumeOps infrastructure.

## ACL Management

ACLs managed via Pulumi in `pulumi/policy.hujson`.

## Groups

| Group | Members | Purpose |
|-------|---------|---------|
| `group:allisonflix` | admin, member | [[jellyfin|Jellyfin]] media access |

## Device Tags

| Tag | Devices | Purpose |
|-----|---------|---------|
| `tag:homelab` | indri | Server infrastructure |
| `tag:nas` | sifaka | Network-attached storage |
| `tag:blumeops` | indri, sifaka | Pulumi IaC managed resources |
| `tag:registry` | indri | Container registry access |
| `tag:k8s-api` | indri | Kubernetes API server access |

**Important:** Don't tag user-owned devices (like gilbert). Tagging converts them to "tagged devices" which lose user identity and break user-based SSH rules.

## Access Matrix

| Source | Kiwix | Forge | PyPI | Miniflux | PostgreSQL | NAS | Grafana | Loki |
|--------|-------|-------|------|----------|------------|-----|---------|------|
| `autogroup:admin` | Y | Y | Y | Y | Y | Y | Y | Y |
| `autogroup:member` | Y | Y | Y | Y | Y | - | - | - |
| `tag:homelab` | - | - | - | - | - | Y | - | - |

- **Admins** - full access to all services
- **Members** - member services only, no Grafana/Loki/NAS

## SSH Access

| Source | Destinations | Auth |
|--------|--------------|------|
| `autogroup:member` | `autogroup:self` | check |
| `autogroup:admin` | `tag:homelab` | check (12h) |
| `autogroup:admin` | `tag:nas` | check (12h) |

## OAuth Credentials

Pulumi uses OAuth client from 1Password (blumeops vault):
- Scopes: acl, dns, devices, services
- Auto-applies `tag:blumeops` to IaC-managed resources

## Related

- [[routing|Routing]] - Service URLs
- [[hosts|Hosts]] - Device inventory
