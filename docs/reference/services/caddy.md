---
title: Caddy
modified: 2026-07-14
last-reviewed: 2026-07-14
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
| `authentik.ops.eblu.me` | `authentik.tail8d86e.ts.net` | [[authentik]] |
| `photos.ops.eblu.me` | `photos.tail8d86e.ts.net` | [[immich]] |
| `paperless.ops.eblu.me` | `paperless.tail8d86e.ts.net` | [[paperless]] |
| `feed.ops.eblu.me` | `feed.tail8d86e.ts.net` | [[miniflux]] |
| `heph.ops.eblu.me` | `localhost:8787` | hephaestus hub |
| ... | ... | (see `defaults/main.yml` for the full ~25-service list) |

### Statically-Served Sites

Some sites are served directly by Caddy from disk (`kind: static`, `file_server`) rather than proxied to a backend:

| Subdomain | Root | Site |
|-----------|------|------|
| `docs.ops.eblu.me` | `{{ docs_content_dir }}` | [[docs]] (Quartz; also public at `docs.eblu.me` via [[flyio-proxy]]) |
| `cv.ops.eblu.me` | `{{ cv_content_dir }}` | [[cv]] (serves `resume.pdf` as an attachment download) |

### TCP Services (Layer 4)

| Port | Backend | Service |
|------|---------|---------|
| 2222 | `localhost:2200` | Forgejo SSH |
| 5433 | `immich-pg.tail8d86e.ts.net:5432` | [[postgresql]] (immich-pg on ringtail) |
| 5434 | `blumeops-pg-ringtail.tail8d86e.ts.net:5432` | [[postgresql]] (blumeops-pg on ringtail) |
| (exporters) | `sifaka:*` | Sifaka node_exporter + smartctl_exporter |

> Port `5432 → pg.tail8d86e.ts.net` (minikube blumeops-pg) was retired with the cluster — see [[retire-minikube]].

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

Caddy has no authentication layer — it is a plain reverse proxy. Access control relies entirely on Tailscale ACLs restricting which devices can reach indri on port 443. Currently `tag:homelab`, `autogroup:admin`, and `tag:flyio-proxy` (via `tag:flyio-target` on indri) can reach Caddy.

The [[flyio-proxy]] routes all public traffic through Caddy. This is the path for `*.eblu.me` requests from the public internet. Caddy sees these as requests from the Fly VM with `Host: *.ops.eblu.me` headers — the same routes used by tailnet clients.

## Custom Build

Custom `xcaddy` build with Gandi DNS and L4 plugins. See [[build-caddy-with-plugins]] for build instructions and forge mirror details.

## Related

- [[gandi]] - DNS hosting and ACME DNS-01 provider
- [[routing]] - Service routing architecture
- [[forgejo]] - Git forge (proxied by Caddy)
- [[zot]] - Container registry (proxied by Caddy)
- [[tailscale-operator]] - K8s services use Tailscale Ingress, then Caddy
