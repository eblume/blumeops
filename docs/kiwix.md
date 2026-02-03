---
id: kiwix
aliases:
  - kiwix
tags:
  - blumeops
---

# Kiwix Management Log

Kiwix serves offline Wikipedia (and other ZIM archives) in Kubernetes via Tailscale at https://kiwix.tail8d86e.ts.net.

## Service Details

- URL: https://kiwix.tail8d86e.ts.net
- Namespace: `kiwix`
- Image: `ghcr.io/kiwix/kiwix-serve:3.8.1`
- ArgoCD app: `kiwix`
- Storage: NFS mount from sifaka (`/volume1/torrents`)

## Architecture

The kiwix deployment has two components:

1. **kiwix-serve** - Main container serving ZIM files at port 80
2. **torrent-sync** - Sidecar that syncs declarative ZIM torrent list to Transmission

A CronJob (`zim-watcher`) runs hourly to detect new ZIM files and trigger a deployment restart when needed.

## Useful Commands

```bash
# View kiwix logs
kubectl --context=minikube-indri -n kiwix logs -f deployment/kiwix -c kiwix-serve

# View torrent sync logs
kubectl --context=minikube-indri -n kiwix logs -f deployment/kiwix -c torrent-sync

# Check ZIM watcher job
kubectl --context=minikube-indri -n kiwix get cronjob zim-watcher

# Manually trigger ZIM watcher
kubectl --context=minikube-indri -n kiwix create job --from=cronjob/zim-watcher zim-watcher-manual

# Sync from ArgoCD
argocd app sync kiwix
```

## ArgoCD Management

Kiwix is deployed via ArgoCD from `argocd/manifests/kiwix/`:
- `deployment.yaml` - Kiwix-serve + torrent-sync sidecar
- `service.yaml` - ClusterIP service
- `ingress-tailscale.yaml` - Tailscale Ingress
- `configmap-zim-torrents.yaml` - Declarative list of ZIM torrents to download
- `configmap-sync-script.yaml` - Script to sync torrents to Transmission
- `cronjob-zim-watcher.yaml` - Hourly job to restart kiwix on new ZIMs

## Adding New ZIM Archives

1. Edit `argocd/manifests/kiwix/configmap-zim-torrents.yaml`
2. Add the torrent URL from https://download.kiwix.org/zim/
3. Sync the kiwix app: `argocd app sync kiwix`
4. The torrent-sync sidecar will add the torrent to [[transmission|Transmission]]
5. Once downloaded, the zim-watcher CronJob will detect it and restart kiwix

## Configured Archives

The declarative torrent list includes:
- Wikipedia top 1M English articles with images
- Project Gutenberg (60,000+ public domain books)
- iFixit repair guides
- Stack Exchange sites (SuperUser, Math, etc.)
- LibreTexts textbooks (Bio, Chem, Eng, Math, Phys, Humanities)
- DevDocs (developer documentation bundles)

See `argocd/manifests/kiwix/configmap-zim-torrents.yaml` for the full list.

## Storage

ZIM files are stored on sifaka NAS at `/volume1/torrents/complete/`. The kiwix pod mounts this directory via NFS.

**Note**: The NFS mount works because minikube uses the docker driver which NATs through indri's LAN IP, allowing direct access to sifaka.

## Log

### 2026-01-21 (P6)
- **Migrated to Kubernetes** (Phase 6 of k8s migration)
- Direct NFS mount from sifaka (no PVC, shared with transmission)
- Torrent-sync sidecar adds configured ZIMs to Transmission
- ZIM-watcher CronJob restarts deployment when new files appear
- Tailscale Ingress at `kiwix.tail8d86e.ts.net`
- Retired ansible kiwix role from indri

### 2026-01-14
- Added transmission integration for background torrent downloads
- Enabled Gutenberg, iFixit, SuperUser, Math SE, and all LibreTexts archives

### 2026-01-13
- Added kiwix role to ansible playbook
- Operationalized ZIM archive downloads with configurable list
- Initial setup with kiwix-tools binary on indri
- Managed via LaunchAgent on port 5501
