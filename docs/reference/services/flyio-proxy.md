---
title: Fly.io Proxy
tags:
  - service
  - networking
  - fly-io
---

# Fly.io Proxy

Public reverse proxy on [Fly.io](https://fly.io) that exposes selected BlumeOps services to the internet via a Tailscale tunnel back to the homelab.

## Quick Reference

| Property | Value |
|----------|-------|
| **App** | `blumeops-proxy` |
| **Region** | `sjc` (San Jose) |
| **Fly.io URL** | `blumeops-proxy.fly.dev` |
| **Config** | `fly/` directory in repo |
| **IaC** | `fly/fly.toml` (app), Pulumi (DNS + auth key) |

## Exposed Services

| Public domain | Backend | Service |
|---------------|---------|---------|
| `docs.eblu.me` | `docs.tail8d86e.ts.net` | [[docs]] |

## Architecture

Internet traffic hits Fly.io's Anycast edge, terminates TLS with a Let's Encrypt certificate, and is proxied by nginx to the backend service over a Tailscale WireGuard tunnel. See [[expose-service-publicly]] for the full architecture diagram.

## Key Files

| File | Purpose |
|------|---------|
| `fly/fly.toml` | App configuration |
| `fly/Dockerfile` | nginx + Tailscale container |
| `fly/nginx.conf` | Reverse proxy, caching, rate limiting |
| `fly/start.sh` | Entrypoint: start Tailscale, then nginx |
| `pulumi/tailscale/__main__.py` | Auth key (`tag:flyio-proxy`) |
| `pulumi/tailscale/policy.hujson` | ACL grants for proxy |
| `pulumi/gandi/__main__.py` | DNS CNAMEs |

## Networking

Fly.io runs Firecracker microVMs which support TUN devices natively. Tailscale runs with a real TUN interface (not userspace networking), so MagicDNS and direct Tailscale IP routing work normally.

The Tailscale auth key is `preauthorized=True` to avoid device approval hangs on container restarts.

## Secrets

| Secret | Source | Description |
|--------|--------|-------------|
| `TS_AUTHKEY` | Pulumi state → `fly secrets` | Tailscale auth key for joining tailnet |
| `FLY_DEPLOY_TOKEN` | Fly.io → 1Password | Deploy token for CI |

## Related

- [[expose-service-publicly]] - Setup guide for adding new public services
- [[manage-flyio-proxy]] - Operational tasks (deploy, shutoff, troubleshoot)
- [[caddy]] - Private reverse proxy for `*.ops.eblu.me` (separate system)
- [[tailscale]] - WireGuard mesh network
- [[gandi]] - DNS hosting
