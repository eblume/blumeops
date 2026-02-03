---
id: navidrome-log
aliases:
  - DJ
tags:
  - blumeops
  - service
---

Navidrome is a self-hosted music streaming server deployed on [[blumeops|BlumeOps]].

# Access

- **Primary URL**: https://dj.ops.eblu.me (via Caddy)
- **Tailscale URL**: https://dj.tail8d86e.ts.net

# Deployment

Navidrome runs in Kubernetes (minikube on [[indri]]) and is managed via [[argocd|ArgoCD]].

**Manifests**: `argocd/manifests/navidrome/`

## Storage

| Mount   | Type              | Source                  | Access     |
|---------|-------------------|-------------------------|------------|
| /music  | NFS PV            | sifaka:/volume1/music   | Read-only  |
| /data   | Local PVC (10Gi)  | minikube storage class  | Read-write |

The `/data` directory contains:
- SQLite database
- Configuration
- Cache files

## Configuration

Environment variables set in deployment:
- `ND_SCANSCHEDULE=1h` - Rescan library every hour
- `ND_LOGLEVEL=info` - Standard logging level
- `ND_MUSICFOLDER=/music` - Music library path
- `ND_DATAFOLDER=/data` - Data directory path

## Initial Setup

On first access, Navidrome will prompt to create an admin user. No default credentials.

# Operations

## Sync Application

```bash
argocd app sync navidrome
```

## Check Status

```bash
argocd app get navidrome
kubectl --context=minikube-indri -n navidrome get pods
kubectl --context=minikube-indri -n navidrome logs deploy/navidrome
```

## Verify NFS Mount

```bash
kubectl --context=minikube-indri -n navidrome exec deploy/navidrome -- ls /music
```

## Force Library Rescan

Access Settings > Library in the web UI, or trigger via API:
```bash
curl -X POST https://dj.ops.eblu.me/api/library/scan -H "x-nd-authorization: Bearer <token>"
```

# Related

- [[jellyfin]] - Video streaming (runs on indri directly)
- [[argocd]] - GitOps deployment
- [[blumeops]] - Infrastructure overview
