---
title: Manage Fly.io Proxy
modified: 2026-02-08
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

## Troubleshooting

**502 Bad Gateway**: Check `fly logs` for nginx upstream errors. Verify the backend Tailscale service is running (`tailscale status` from inside the container via `fly ssh console`).

**Health check failing**: `fly ssh console -a blumeops-proxy` then `curl localhost:8080/healthz` to test locally.

**TLS errors on custom domain**: Check cert status with `fly certs show <domain> -a blumeops-proxy`. Certs auto-provision via Let's Encrypt and may take a few minutes.

## Related

- [[flyio-proxy]] - Service reference card
- [[expose-service-publicly]] - Full setup guide and architecture
