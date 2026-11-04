---
title: Caddy
modified: 2026-11-04
last-reviewed: 2026-09-18
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
| **Config** | `darwin/indri/caddy-services.json` (rendered to the Caddyfile by the indri flake's generation) |
| **Binary** | nixpkgs `caddy.withPlugins` (Gandi DNS + L4) in the generation; the generation-rendered wrapper execs it via `/nix/var/nix/profiles/system/sw/bin/caddy` |
| **Unit** | nix-managed LaunchAgent `mcquack.eblume.caddy` ([[indri]] flake) |

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
| ... | ... | (see `darwin/indri/caddy-services.json` for the full list) |

### Statically-Served Sites

Some sites are served directly by Caddy from disk (`kind: static`, `file_server`) rather than proxied to a backend:

| Subdomain | Root | Site |
|-----------|------|------|
| `docs.ops.eblu.me` | `~/blumeops/docs/content` | [[docs]] (Quartz; also public at `docs.eblu.me` via [[flyio-proxy]]) |
| `cv.ops.eblu.me` | `~/blumeops/cv/content` | [[cv]] (serves `resume.pdf` as an attachment download) |

### Fly Proxy Listener (:8443)

A second listener, `*.ops.eblu.me:8443`, serves only the services flagged `fly_proxied: true` (docs, cv, photos) — the [[flyio-proxy]] path. New services are unreachable from the fly node by default: to expose one, add `fly_proxied: true` to its service entry and its name to `fly_proxied_services` in `darwin/indri/caddy-services.json` — `mise run caddy-render-check` fails if the two diverge.

### TCP Services (Layer 4)

| Port | Backend | Service |
|------|---------|---------|
| 2222 | `localhost:2200` | Forgejo SSH |
| 5433 | `immich-pg.tail8d86e.ts.net:5432` | [[postgresql]] (immich-pg on ringtail) |
| 5434 | `blumeops-pg-ringtail.tail8d86e.ts.net:5432` | [[postgresql]] (blumeops-pg on ringtail) |
| (exporters) | `sifaka:*` | Sifaka node_exporter + smartctl_exporter |

> Port `5432 → pg.tail8d86e.ts.net` (minikube blumeops-pg) was retired with the cluster — see [[retire-minikube]].

## Configuration

The Caddy config is generation-owned (V5-83). Its sources live in `darwin/indri/`:

- `caddy-services.json` - service definitions (hosts, backends, static roots, `fly_proxied` split) and TCP routes; the Nix renderer turns it into the Caddyfile
- `caddy-pins.yaml` - cv and docs version pins (bumped by release PRs; see [[cv-on-indri]] and [[docs-on-indri]])
- `configuration.nix` - the LaunchAgent unit (`launchd.user.agents."mcquack.eblume.caddy"`), the wrapper, and the static-site paths

Config changes apply with the usual `mise run provision-indri -- --tags rebuild`
(or the merge's auto-apply). The Caddyfile is validated by `caddy adapt` at activation.
`mise run caddy-render-check` checks the fly-listener split of the service data in CI.

Rollback is `sudo darwin-rebuild --rollback` (see [[provision]] §Rolling back a service flip).

**Key files:**
- `darwin/indri/caddy-services.json` - service definitions
- `darwin/indri/caddy-pins.yaml` - cv/docs pins
- `darwin/indri/configuration.nix` - LaunchAgent unit, wrapper, static-site paths

## Secrets

| Secret | Source | Description |
|--------|--------|-------------|
| `GANDI_BEARER_TOKEN` | 1Password | API token for DNS-01 challenges |

The token is written to `~/.config/caddy/gandi-token` (chmod 0600) by the `seed-secrets` manifest (`mise run seed-secrets indri`) and sourced by the Caddy wrapper script; the switch's checks slot refuses to apply if it is missing or empty.

## Security Considerations

Caddy has no authentication layer — it is a plain reverse proxy. Access control relies entirely on Tailscale ACLs restricting which devices can reach indri on port 443. Indri:443 is reached by `tag:homelab`/`autogroup:admin` tailnet clients as before. The fly node reaches Caddy only via the fly-only `:8443` listener (`tag:flyio-origin`, tcp:8443 only) — it has no path to indri:443 anymore (eblume/blumeops#1396).

The [[flyio-proxy]] routes all public traffic through Caddy. This is the path for `*.eblu.me` requests from the public internet. Caddy sees these as requests from the Fly VM with `Host: *.ops.eblu.me` headers — the same routes used by tailnet clients.

## Binary Lineage

The binary is a nixpkgs `caddy.withPlugins` build (Gandi DNS for ACME DNS-01
and L4 for the TCP routes), declared in the [[indri]] flake's
`environment.systemPackages` so it is in the generation's closure. The
generation-rendered wrapper execs it through the system profile's
`/nix/var/nix/profiles/system/sw/bin/caddy` — the profile path, so it follows
every switch and `--rollback` — and the LaunchAgent plist's
`ProgramArguments[0]` stays the on-disk wrapper (a store path there would die
`EX_CONFIG` in the pre-`/nix` boot window). The prior `xcaddy` checkout build at
`~/code/3rd/caddy` was retired with the flip (blumeops#1275); the checkout
and its forge mirrors (`mirrors/caddy`, `mirrors/caddy-gandi`,
`mirrors/xcaddy`, `mirrors/caddy-l4`) are deleted, so a lineage rollback is
`darwin-rebuild --rollback` alone.

## Related

- [[gandi]] - DNS hosting and ACME DNS-01 provider
- [[routing]] - Service routing architecture
- [[forgejo]] - Git forge (proxied by Caddy)
- [[zot]] - Container registry (proxied by Caddy)
- [[tailscale-operator]] - K8s services use Tailscale Ingress, then Caddy
