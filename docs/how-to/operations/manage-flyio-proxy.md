---
title: Manage Fly.io Proxy
modified: 2026-09-25
last-reviewed: 2026-09-25
tags:
  - how-to
  - fly-io
  - networking
  - operations
---

# Manage Fly.io Proxy

Operational tasks for the [[flyio-proxy]] public reverse proxy.

## Deploy Changes

Merging a change under `fly/` does **not** deploy it — the `deploy-fly`
workflow is a privileged, `workflow_dispatch`-only workflow per
[[warrant-approval-gated-runs]] invariant 3. Three ways to run it:

- **From gilbert** (human, vault-gated): `mise run fly-deploy`
- **From the forge UI** (human): dispatch *Deploy Fly.io Proxy* with the
  merged commit's full SHA (or `main`) as `revision`
- **From an agent session** (approval-gated):
  `mise run request-run deploy-fly.yaml <full-sha> --pr <N> -i revision=<full-sha> --why "…"`

## Add a New Public Service

See [[expose-service-publicly#Per-service setup]] for the full walkthrough. In short:

1. Add a `server` block to `fly/nginx.conf`
2. Add a Fly.io certificate: `fly certs add <domain> -a blumeops-proxy`
3. Deploy: `mise run fly-deploy`
4. Verify against `blumeops-proxy.fly.dev` with a `Host` header
5. Add DNS CNAME via Pulumi: `mise run dns-preview` then `mise run dns-up`

## Emergency Shutoff

If the proxy is causing issues (DDoS, unexpected traffic, bandwidth consumption on the home network):

**Level 1 — Stop the container (seconds, reversible):**
```bash
mise run fly-shutoff
# or: fly scale count 0 -a blumeops-proxy --yes
```
All public services go offline immediately. Tailscale tunnel drops. Zero traffic reaches indri. Restore with `fly scale count 1 -a blumeops-proxy`.

**Level 2 — Revoke Tailscale access (seconds):**
Remove the `flyio-proxy` node in the Tailscale admin console. Even if the container is running, it cannot reach the tailnet. Use this if the container itself may be compromised.

**Level 3 — Remove DNS (minutes to hours):**
Delete the CNAME records at Gandi. Takes time for DNS propagation but is the permanent shutoff.

**Level 1 is the primary response.** It is a single command, takes effect in seconds, and is trivially reversible. Keep `mise run fly-shutoff` somewhere easily accessible (e.g., pinned in a notes app) so it can be run quickly under stress.

## Check Status

```bash
# App and machine status
fly status -a blumeops-proxy

# Live logs
fly logs -a blumeops-proxy

# Health check
curl -sf https://blumeops-proxy.fly.dev/healthz

# Certificate status
fly certs list -a blumeops-proxy
```

## Rotate Tailscale Auth Key

The auth key expires every 90 days. To rotate:

1. Re-apply Pulumi to generate a new key: `mise run tailnet-up`
2. Re-run setup to stage the new secret: `mise run fly-setup`
3. Deploy to pick up the new secret: `mise run fly-deploy`

## Rotate Fly.io API Token

See [[rotate-fly-deploy-token]] for the full rotation procedure (75-day cadence, `org`-scoped).

## Static Forge Mirror

The app also serves a read-only mirror of the allowlisted public forge
repos — stagit HTML + git dumb HTTP — at `blumeops-proxy.fly.dev`
(staging; `forge.eblu.me` flips to it in the cutover). The mirror's bare
repos and generated site live on the `git-mirror` Fly volume. Full
design, layout and verification: `fly/git-mirror/README.md`.

- **First deploy of a mirror image:** `mise run fly-setup` (creates the
  volume idempotently) **before** the `deploy-fly` run — a machine
  declared with a `[[mounts]]` block that has no volume fails to start,
  and the deploy workflow's health check fails fatally.
- **Machine replacement:** nothing to do. The volume reattaches and
  `start.sh` regenerates the site from the repos.
- **Growth:** the volume is 5 GB (seven repos ≈ 1 GB today).
  `fly volumes resize` if it ever fills.

## Tailscale Node Identity (was: Node Name Drift)

The node keeps a **stable** identity: `tailscaled --statedir=/var/lib/tailscale`
is backed by the `git-mirror` volume via a bind mount in `fly/start.sh`
(`/volume/tailscale`), so the node key — and with it the `flyio-proxy`
name and CGNAT IP — survive machine
replacement. This is the fix that was reviewed and declined on 2026-06-25
when the app was stateless; the static mirror needs the volume for its
repos anyway, and the stable address is what makes the mirror's SSH push
endpoint addressable. The volume-anchors-the-machine tradeoff is
accepted: the mirror repos are state that must outlive machine
replacement regardless, and Fly reschedules on the volume's host only if
that host fails.

**Pre-2026-09-25 behaviour** (for orientation in old notes): without the
mount, `/var/lib/tailscale` lived on the ephemeral rootfs, each boot
registered a new node, and the name drifted `flyio-proxy` →
`flyio-proxy-1` → … The auth key is `ephemeral=True`
(`pulumi/tailscale/__main__.py`), so orphans auto-GC; routing and ACLs
are tag-based (`tag:flyio-proxy`), so the suffix never had a functional
impact.

## Troubleshooting

**502 Bad Gateway on fresh deploy**: MagicDNS may not be ready when nginx starts. The `start.sh` script polls `nslookup` before launching nginx, but if it still fails, check that `tailscale status` is healthy inside the container.

**Health check failing**: `fly ssh console -a blumeops-proxy` then `curl localhost:8080/healthz` to test locally.

**TLS errors on custom domain**: Check cert status with `fly certs show <domain> -a blumeops-proxy`. Certs auto-provision via Let's Encrypt and may take a few minutes.

**High latency (>1s p50)**: Check if direct WireGuard peering is established: `fly ssh console -a blumeops-proxy -C "tailscale ping indri"`. If it shows `via DERP`, the tunnel is relayed and latency will be 10-30s. See [[tailscale#Direct Peering vs DERP Relay]] for diagnosis.

## Related

- [[flyio-proxy]] - Service reference card
- [[expose-service-publicly]] - Full setup guide and architecture
