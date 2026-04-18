---
title: Tailscale
modified: 2026-04-18
last-reviewed: 2026-04-18
tags:
  - infrastructure
  - networking
---

# Tailscale

Tailnet `tail8d86e.ts.net` provides secure networking for all BlumeOps infrastructure.

## ACL Management

ACLs managed via Pulumi in `pulumi/tailscale/policy.hujson`.

## Groups

| Group | Members | Purpose |
|-------|---------|---------|
| `group:allisonflix` | admin, member | [[jellyfin]] media access |

## Device Tags

| Tag | Devices | Purpose |
|-----|---------|---------|
| `tag:homelab` | indri, ringtail | Server infrastructure |
| `tag:nas` | sifaka | Network-attached storage |
| `tag:blumeops` | indri, sifaka, ringtail | Pulumi IaC managed resources |
| `tag:registry` | indri | Container registry (Zot) |
| `tag:forge` | indri | Forgejo git hosting |
| `tag:loki` | indri | Loki log aggregation |
| `tag:k8s-api` | indri | Kubernetes API server (minikube) |
| `tag:k8s-operator` | (operator pod) | Tailscale operator for k8s — see [[tailscale-operator]] |
| `tag:k8s` | (Ingress proxy pods) | Kubernetes Tailscale Ingress nodes; each also carries a per-service tag (`tag:grafana`, `tag:kiwix`, `tag:devpi`, `tag:feed`, `tag:pg`) |
| `tag:ci-gateway` | (ephemeral CI containers) | CI containers pushing images to registry |
| `tag:flyio-proxy` | (Fly.io proxy container) | Public reverse proxy |
| `tag:flyio-target` | indri, designated Ingress endpoints | Endpoints reachable by the Fly.io proxy (indri for Caddy routing, Ingress pods for Alloy metrics/logs) |

**Important:** Don't tag user-owned devices (like gilbert) via Pulumi. Tagging converts them to "tagged devices" which lose user identity and break user-based SSH rules. Gilbert is referenced as `tag:workstation` in tagOwners for ownership purposes but remains user-owned so `blume.erich@gmail.com` identity is preserved.

## Access Matrix

| Source | Kiwix | Forge | DevPI | Miniflux | PostgreSQL | NAS | Grafana | Loki |
|--------|-------|-------|-------|----------|------------|-----|---------|------|
| `autogroup:admin` | Y | Y | Y | Y | Y | Y | Y | Y |
| `autogroup:member` | Y | Y (443, SSH) | Y | Y | Y (5432) | - | - | - |
| `tag:homelab` | - | - | - | - | Y (5432) | Y | - | Y (3100) |
| `tag:k8s` | - | Y (3001, 2200) | - | - | - | - | - | - |

- **Admins** — full access to all services
- **Members** — user-facing services only; no Grafana, Loki, or NAS
- **Homelab** — server-to-server: full mutual access between homelab peers (including SSH), full NAS access, and k8s service access (443, 5432, 9187)
- **K8s** — can reach registry (443) and forge on indri (HTTP 3001, SSH 2200) for GitOps

Additional grants not shown in the matrix:
- `tag:flyio-proxy` → `tag:flyio-target` on tcp:443 only
- `tag:ci-gateway` → `tag:registry` on tcp:443
- `tag:k8s` → `tag:registry` on tcp:443
- `tag:homelab` → `tag:k8s` on tcp:443, tcp:5432, tcp:9187

See `pulumi/tailscale/policy.hujson` for the full grant definitions.

## SSH Access

| Source | Destinations | Auth |
|--------|--------------|------|
| `autogroup:member` | `autogroup:self` | check |
| `autogroup:admin` | `tag:homelab` | check (12h) |
| `autogroup:admin` | `tag:nas` | check (12h) |
| `tag:homelab` | `tag:homelab` | accept (tagged devices cannot perform interactive auth) |

## Auto Approvers

ProxyGroup pods (`tag:k8s`) can auto-approve their own VIP Services. This is required for multi-cluster Tailscale Ingress routing — without it, advertised ProxyGroup routes are not approved. See [[tailscale-operator]] for ProxyGroup configuration details.

## OAuth Credentials

Pulumi uses OAuth client from 1Password (blumeops vault):
- Scopes: acl, dns, devices, services
- Auto-applies `tag:blumeops` to IaC-managed resources

## Direct Peering vs DERP Relay

Just because Tailscale can route traffic does not mean it routes it efficiently. DERP relay servers are a fallback for when direct WireGuard connections cannot be established — they add significant latency (20+ seconds observed under load) because every packet bounces through a relay server.

**Direct peering is critical for any production-like traffic path.** Check with `tailscale ping <host>` — it should say `via <ip>:<port>`, not `via DERP(<region>)`.

Common reasons direct peering fails:
- **k8s pods**: Tailscale Ingress pods behind pod-network NAT cannot hole-punch. Route through a host-level Tailscale node (e.g., Caddy on indri) instead.
- **Cloud VMs**: Some cloud providers block incoming UDP. Pin the WireGuard port (`tailscaled --port=41641`) and expose it as a UDP service if possible.
- **Double NAT / CGNAT**: Multiple NAT layers make hole punching unreliable.

The [[flyio-proxy]] uses `--port=41641` pinning to enable direct peering with indri, and routes through [[caddy]] (host-level Tailscale) to avoid the DERP bottleneck of k8s-hosted Tailscale Ingress pods.

## Related

- [[routing|Routing]] - Service URLs
- [[hosts|Hosts]] - Device inventory
