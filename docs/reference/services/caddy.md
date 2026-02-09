---
title: Caddy
tags:
  - service
  - networking
  - tls
---

# Caddy

Reverse proxy for `*.ops.eblu.me` services with automatic TLS via ACME DNS-01.

## Quick Reference

| Property | Value |
|----------|-------|
| **Domain** | `*.ops.eblu.me` |
| **HTTPS Port** | 443 |
| **Config** | `ansible/roles/caddy/templates/Caddyfile.j2` |
| **Binary** | Custom build with Gandi DNS plugin |

## Why Caddy?

Caddy provides a single TLS termination point for all BlumeOps services:

- **Wildcard certificate** for `*.ops.eblu.me` via Let's Encrypt
- **DNS-01 challenge** using Gandi API (no port 80 needed)
- **Unified access** from k8s pods, containers, and tailnet clients

See [[routing]] for when to use `*.ops.eblu.me` vs `*.tail8d86e.ts.net`.

## Proxied Services

### Indri-Local Services

| Subdomain | Backend | Service |
|-----------|---------|---------|
| `forge.ops.eblu.me` | `localhost:3001` | [[forgejo]] |
| `registry.ops.eblu.me` | `localhost:5050` | [[zot]] |
| `jellyfin.ops.eblu.me` | `localhost:8096` | [[jellyfin]] |

### Kubernetes Services

K8s services are proxied via their Tailscale Ingress endpoints:

| Subdomain | Backend | Service |
|-----------|---------|---------|
| `grafana.ops.eblu.me` | `grafana.tail8d86e.ts.net` | [[grafana]] |
| `argocd.ops.eblu.me` | `argocd.tail8d86e.ts.net` | [[argocd]] |
| `docs.ops.eblu.me` | `docs.tail8d86e.ts.net` | [[docs]] (now publicly available at `docs.eblu.me` via [[flyio-proxy]]) |
| `feed.ops.eblu.me` | `feed.tail8d86e.ts.net` | [[miniflux]] |
| ... | ... | (see defaults/main.yml for full list) |

### TCP Services (Layer 4)

| Port | Backend | Service |
|------|---------|---------|
| 2222 | `localhost:2200` | Forgejo SSH |
| 5432 | `pg.tail8d86e.ts.net:5432` | [[postgresql]] |

## Configuration

Caddy is managed via the `caddy` Ansible role:

```bash
# Deploy caddy changes
mise run provision-indri -- --tags caddy
```

**Key files:**
- `ansible/roles/caddy/defaults/main.yml` - Service definitions
- `ansible/roles/caddy/templates/Caddyfile.j2` - Caddy config template

## Secrets

| Secret | Source | Description |
|--------|--------|-------------|
| `GANDI_BEARER_TOKEN` | 1Password | API token for DNS-01 challenges |

The token is written to `~/.config/caddy/gandi-token` (chmod 0600) and sourced by the Caddy wrapper script.

## Security Considerations

Caddy has no authentication layer — it is a plain reverse proxy. Access control relies entirely on Tailscale ACLs restricting which devices can reach indri on port 443. Currently `tag:homelab` and `autogroup:admin` can reach Caddy. The [[flyio-proxy]] no longer routes through Caddy — it pushes logs and metrics directly to [[loki]] and [[prometheus]] via their Tailscale Ingress endpoints.

## Custom Build

Caddy is built from source with the Gandi DNS plugin:

```bash
# Build location
~/code/3rd/caddy/bin/caddy
```

The build includes the `github.com/caddy-dns/gandi` plugin for ACME DNS-01 challenges.

## Related

- [[gandi]] - DNS hosting and ACME DNS-01 provider
- [[routing]] - Service routing architecture
- [[forgejo]] - Git forge (proxied by Caddy)
- [[zot]] - Container registry (proxied by Caddy)
- [[tailscale-operator]] - K8s services use Tailscale Ingress, then Caddy
