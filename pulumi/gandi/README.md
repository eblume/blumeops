# Gandi DNS Management

This Pulumi project manages DNS records for `eblu.me` via Gandi LiveDNS.

## What It Does

Creates DNS records that point `*.ops.eblu.me` to indri's Tailscale IP.

**Why indri?** indri hosts Caddy, the reverse proxy for all blumeops services.
All `*.ops.eblu.me` requests route through Caddy, which proxies to the appropriate
backend service (either on indri itself or in the k8s cluster).

Since Tailscale IPs (100.x.x.x) are not routable on the public internet, these
DNS records effectively make services accessible only from within the tailnet,
while still using real, resolvable DNS names.

The target IP is resolved dynamically from `indri.tail8d86e.ts.net` at deploy time,
so if indri's Tailscale IP changes, just re-run the deployment.

## Setup

```bash
cd pulumi/gandi
uv sync
pulumi stack select eblu-me  # or: pulumi stack init eblu-me
```

## Authentication

This project uses a Gandi Personal Access Token (PAT) shared with Caddy. See the [Gandi reference card](../../docs/reference/infrastructure/gandi.md) and [Rotate the Gandi PAT](../../docs/how-to/configuration/rotate-gandi-pat.md).

The mise tasks handle fetching the PAT from 1Password:

```bash
mise run dns-preview   # Preview only
mise run dns-up        # Preview and apply
```

Or manually:

```bash
export GANDI_PERSONAL_ACCESS_TOKEN=$(op read "op://blumeops/gandi - blumeops/pat")
pulumi up
```

## DNS Records Created

| Record | Type | Value | Purpose |
|--------|------|-------|---------|
| `*.ops.eblu.me` | A | (indri's Tailscale IP) | Wildcard for all services |
| `ops.eblu.me` | A | (indri's Tailscale IP) | Base subdomain |

## Service Hostnames

Once Caddy is configured on indri, services will be accessible at:

- `forge.ops.eblu.me` - Forgejo git server
- `registry.ops.eblu.me` - Zot container registry
- `grafana.ops.eblu.me` - Grafana dashboards
- `argocd.ops.eblu.me` - ArgoCD
- `feed.ops.eblu.me` - Miniflux RSS reader
- `pypi.ops.eblu.me` - DevPI Python index
- `kiwix.ops.eblu.me` - Kiwix offline content
- `tesla.ops.eblu.me` - TeslaMate
- `torrent.ops.eblu.me` - Transmission
- `prometheus.ops.eblu.me` - Prometheus metrics
- `loki.ops.eblu.me` - Loki logs
