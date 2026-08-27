---
title: Routing
modified: 2026-08-27
last-reviewed: 2026-08-27
tags:
  - infrastructure
  - networking
---

# Service Routing

Services are accessible via three DNS domains with different reachability.

## DNS Domains

| Domain | Proxy | Reachable From |
|--------|-------|----------------|
| `*.eblu.me` | [[flyio-proxy]] (Fly.io → Tailscale tunnel) | Public internet |
| `*.ops.eblu.me` | Caddy on indri | k8s pods, docker containers, tailnet clients |
| `*.tail8d86e.ts.net` | Tailscale MagicDNS | Tailnet clients only |

**Use `*.ops.eblu.me`** for services that need pod-to-service communication. Use `*.eblu.me` for services exposed publicly via Fly.io.

## Caddy Services (`*.ops.eblu.me`)

DNS points to [[indri]]'s Tailscale IP. TLS via Let's Encrypt (ACME DNS-01 with Gandi).

Backends split two ways: services running natively on [[indri]] are proxied
to `localhost`, while workloads on [[ringtail]]'s k3s are reached through
their Tailscale Ingress endpoints (`<service>.tail8d86e.ts.net`) — traffic
stays on the tailnet either way. The table below tracks
`ansible/roles/caddy/defaults/main.yml`.

| Service | URL | Description |
|---------|-----|-------------|
| Homepage | https://go.ops.eblu.me | Service dashboard (k3s) |
| [[forgejo]] | https://forge.ops.eblu.me | Git hosting (SSH: 2222) |
| [[zot]] | https://registry.ops.eblu.me | Container registry |
| [[jellyfin]] | https://jellyfin.ops.eblu.me | Media server |
| [[grafana]] | https://grafana.ops.eblu.me | Dashboards (k3s) |
| [[argocd]] | https://argocd.ops.eblu.me | GitOps CD (k3s) |
| [[prometheus]] | https://prometheus.ops.eblu.me | Metrics (k3s) |
| [[loki]] | https://loki.ops.eblu.me | Logs (k3s) |
| [[miniflux]] | https://feed.ops.eblu.me | RSS reader (k3s) |
| [[devpi]] | https://pypi.ops.eblu.me | PyPI caching proxy / private index |
| Heph | https://heph.ops.eblu.me | Task/context hub + PWA (indri) |
| [[kiwix]] | https://kiwix.ops.eblu.me | Offline Wikipedia (k3s) |
| [[transmission]] | https://torrent.ops.eblu.me | BitTorrent (k3s) |
| [[teslamate]] | https://tesla.ops.eblu.me | Tesla logger (k3s) |
| [[immich]] | https://photos.ops.eblu.me | Photo/video management (k3s) |
| [[navidrome]] | https://dj.ops.eblu.me | Music streaming (k3s) |
| [[docs]] | https://docs.ops.eblu.me | Documentation site (Quartz, static) |
| [[cv]] | https://cv.ops.eblu.me | CV / resume (static) |
| NVR (Frigate) | https://nvr.ops.eblu.me | Camera viewer (k3s) |
| [[authentik]] | https://authentik.ops.eblu.me | Identity provider (k3s) |
| [[ntfy]] | https://ntfy.ops.eblu.me | Push notifications (k3s) |
| [[horkos]] | https://horkos.ops.eblu.me | Approval broker for agent runs (k3s) |
| [[ollama]] | https://ollama.ops.eblu.me | Local LLM runtime (k3s) |
| [[mealie]] | https://meals.ops.eblu.me | Recipe manager (k3s) |
| [[paperless]] | https://paperless.ops.eblu.me | Document management (k3s) |
| Shower | https://shower.ops.eblu.me | Baby shower guest registry (going to be archived soon); staff console here, guest surface public (see below) |
| [[talos]] | https://talos.ops.eblu.me | Agent workflow service (pi + OpenRouter, k3s) |
| [[sifaka|Sifaka]] | https://nas.ops.eblu.me | NAS dashboard |

Raw TCP (L4) proxies — SSH and the two PostgreSQL instances — are listed
under the port map below.

## Public Services (`*.eblu.me`)

DNS CNAMEs point to `blumeops-proxy.fly.dev`. TLS via Fly.io-managed Let's Encrypt. Traffic tunnels back to [[caddy]] on [[indri]] over a direct Tailscale WireGuard connection, then Caddy routes to the service. See [[flyio-proxy]] for details.

| Service | URL | Description |
|---------|-----|-------------|
| Landing page | https://eblu.me, https://www.eblu.me | "Under construction" apex splash |
| [[docs]] | https://docs.eblu.me | Documentation site |
| [[cv]] | https://cv.eblu.me | CV / resume |
| [[forgejo]] | https://forge.eblu.me | Git hosting (public) |
| Shower | https://shower.eblu.me | Baby shower guest registry (going to be archived soon) — guest surface only; `/host/` and `/admin/` 403 with a pointer to shower.ops.eblu.me |

The apex landing page is the one exception to the "tunnel back to Caddy on
indri" model: it's a single static splash served directly from nginx on the
Fly proxy (files baked into the image), so it stays up even when indri or the
tunnel is down. A `CNAME` is also illegal at the zone apex, so `eblu.me` uses
`A`/`AAAA` records pointed at Fly's ingress IPs instead of the `CNAME` the
subdomains use; `www.eblu.me` is a normal `CNAME` like the rest.

## Tailscale-Only Services

| Service | Endpoint | Description |
|---------|----------|-------------|
| k3s API | `ssh ringtail` | The k8s cluster lives on [[ringtail]]; there is no dedicated MagicDNS hostname for the API server. From the tailnet, use `k3s kubectl` over SSH or fetch the kubeconfig — see [[ringtail]] |

The old `k8s.tail8d86e.ts.net` Minikube endpoint was retired 2026-06 with the
cluster itself; every k8s workload (including ArgoCD) now runs on ringtail's
k3s. See [[retire-minikube]] for the migration record.

## Port Map (Indri)

| Port | Service | Protocol | Binding | Notes |
|------|---------|----------|---------|-------|
| 443 | Caddy | HTTPS | 0.0.0.0 | Reverse proxy |
| 2222 | Caddy L4 | TCP | 0.0.0.0 | SSH proxy to Forgejo |
| 5433 | Caddy L4 | TCP | 0.0.0.0 | PostgreSQL proxy — immich-pg on ringtail |
| 5434 | Caddy L4 | TCP | 0.0.0.0 | PostgreSQL proxy — blumeops-pg on ringtail ([[postgresql]]) |
| 9100 | Caddy L4 | TCP | 0.0.0.0 | Sifaka node_exporter proxy |
| 9633 | Caddy L4 | TCP | 0.0.0.0 | Sifaka smartctl_exporter proxy |
| 2200 | Forgejo SSH | TCP | localhost | Built-in SSH server |
| 3001 | Forgejo | HTTP | localhost | Web UI |
| 5050 | Zot | HTTP | localhost | Registry API |
| 8096 | Jellyfin | HTTP | localhost | Media server |

## Related

- [[gandi]] - DNS hosting for `eblu.me`
- [[tailscale]] - ACL configuration
- [[indri]] - Where services run
- [[ringtail]] - k3s cluster host
- [[flyio-proxy]] - Public reverse proxy for `*.eblu.me`
- [[expose-service-publicly]] - How to add a new public service
