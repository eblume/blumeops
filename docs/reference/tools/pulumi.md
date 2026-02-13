---
title: Pulumi
modified: 2026-02-12
tags:
  - reference
  - iac
  - pulumi
---

# Pulumi

Infrastructure-as-Code for DNS and Tailscale ACL management. Two independent projects, both using the Python SDK with uv toolchain.

## Projects

| Project | Stack | Source | Manages |
|---------|-------|--------|---------|
| `blumeops-dns` | `eblu-me` | `pulumi/gandi/` | DNS records for `eblu.me` via Gandi LiveDNS |
| `blumeops-tailnet` | `tail8d86e` | `pulumi/tailscale/` | ACL policy, device tags, auth keys |

### DNS (`blumeops-dns`)

Manages `*.ops.eblu.me` wildcard and base records pointing to [[indri]]'s Tailscale IP, plus public CNAME records for services routed via [[flyio-proxy]].

### Tailnet (`blumeops-tailnet`)

Manages the ACL policy (`policy.hujson`), device tags for [[indri]] and [[sifaka]], and auth keys for the Fly.io proxy.

## CLI Patterns

All operations use mise tasks that wrap `pulumi` with the correct stack and working directory:

```bash
# DNS
mise run dns-preview     # Preview DNS changes
mise run dns-up          # Apply DNS changes

# Tailscale
mise run tailnet-preview # Preview ACL/tag changes
mise run tailnet-up      # Apply ACL/tag changes
```

## Authentication

- **Gandi**: `GANDI_PERSONAL_ACCESS_TOKEN` environment variable
- **Tailscale**: `TAILSCALE_API_KEY` environment variable
- **Pulumi state**: Local backend (no Pulumi Cloud)

## Related

- [[gandi]] — DNS hosting
- [[tailscale]] — Tailnet configuration
- [[routing]] — How DNS records map to services
