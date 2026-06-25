---
title: Manage Fly.io Proxy
modified: 2026-04-18
last-reviewed: 2026-04-18
tags:
  - how-to
  - fly-io
  - networking
  - operations
---

# Manage Fly.io Proxy

Operational tasks for the [[flyio-proxy]] public reverse proxy.

## Deploy Changes

After modifying files in `fly/`:

```bash
mise run fly-deploy
```

Pushes to `fly/` on main also trigger automatic deployment via the Forgejo CI workflow.

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
Remove the `flyio-proxy` node (or its current suffixed variant, e.g. `flyio-proxy-2` — see [Tailscale Node Name Drift](#tailscale-node-name-drift)) in the Tailscale admin console. Even if the container is running, it cannot reach the tailnet. Use this if the container itself may be compromised.

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

## Tailscale Node Name Drift

The proxy's Tailscale node name drifts on each machine restart — it appears as
`flyio-proxy`, then `flyio-proxy-1`, `flyio-proxy-2`, and so on. **This is
expected and benign; no action is needed.**

**Why it happens:** `tailscaled --statedir=/var/lib/tailscale` (`fly/start.sh`)
persists the node identity (node key), but `fly.toml` has no `[[mounts]]` block,
so that directory lives on the Firecracker microVM's ephemeral rootfs and is
wiped on every restart/redeploy. Each boot, `tailscale up --hostname=flyio-proxy`
registers a brand-new node. If the prior node has not yet been garbage-collected,
Tailscale resolves the name collision by appending an incrementing suffix.

The auth key is `ephemeral=True` (`pulumi/tailscale/__main__.py`), so offline
nodes auto-GC within minutes — orphans do not accumulate. Routing and ACLs are
tag-based (`tag:flyio-proxy`), not name-based, so the suffix has no functional
impact.

**The fix we chose not to apply:** Mounting a Fly volume at `/var/lib/tailscale`
(`fly volumes create … ` + a `[[mounts]]` block) would persist the node key
across restarts, so the node reconnects with stable identity and keeps the
canonical `flyio-proxy` name. We deliberately don't do this: a Fly volume is
pinned to a single physical host, which anchors the otherwise stateless proxy
and hurts Fly's freedom to reschedule the machine on host failure. For a
stateless edge proxy, statelessness is worth more than a stable node name.
(Reviewed and closed 2026-06-25.)

## Troubleshooting

**502 Bad Gateway on fresh deploy**: MagicDNS may not be ready when nginx starts. The `start.sh` script polls `nslookup` before launching nginx, but if it still fails, check that `tailscale status` is healthy inside the container.

**Health check failing**: `fly ssh console -a blumeops-proxy` then `curl localhost:8080/healthz` to test locally.

**TLS errors on custom domain**: Check cert status with `fly certs show <domain> -a blumeops-proxy`. Certs auto-provision via Let's Encrypt and may take a few minutes.

**High latency (>1s p50)**: Check if direct WireGuard peering is established: `fly ssh console -a blumeops-proxy -C "tailscale ping indri"`. If it shows `via DERP`, the tunnel is relayed and latency will be 10-30s. See [[tailscale#Direct Peering vs DERP Relay]] for diagnosis.

## Related

- [[flyio-proxy]] - Service reference card
- [[expose-service-publicly]] - Full setup guide and architecture
