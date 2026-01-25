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

This project requires a Gandi Personal Access Token (PAT) with LiveDNS permissions.

**The PAT expires every 30 days and must be cycled manually.**

### Cycling the PAT

1. Go to [Gandi PAT Management](https://admin.gandi.net/organizations/1db8d76a-f729-11ed-b8d1-00163e94b645/account/pat)

2. Create a new PAT:
   - Name: `blumeops-pulumi` (or similar)
   - Expiration: 30 days (maximum)
   - Permissions required:
     - **Manage domain name technical configurations** (required for DNS records)
     - See and renew domain names
   - Optional permissions (enabled but not strictly required):
     - See & download SSL certificates
     - Manage Cloud resources
     - See Cloud resources
     - View Organization
     - Deploy Web Hosting instances
     - Manage Web Hosting instances
     - See and renew Web Hosting instances

3. Update 1Password:
   ```bash
   # Update the existing item with the new PAT value
   op item edit mco6ka3dc3rmw7zkg2dhia5d2m pat="<NEW_PAT_VALUE>" --vault vg6xf6vvfmoh5hqjjhlhbeoaie
   ```

4. Delete the old PAT from Gandi admin console

### Running with Authentication

The mise task handles fetching the PAT from 1Password:

```bash
mise run dns-up        # Preview and apply changes
mise run dns-preview   # Preview only
```

Or manually:

```bash
export GANDI_PERSONAL_ACCESS_TOKEN=$(op item get mco6ka3dc3rmw7zkg2dhia5d2m --field pat --reveal --vault vg6xf6vvfmoh5hqjjhlhbeoaie)
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
