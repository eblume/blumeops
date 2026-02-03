---
id: transmission-log
tags:
  - blumeops
---

# Transmission Management Log

Transmission is a BitTorrent daemon running in Kubernetes, primarily used to download large ZIM archives for [[kiwix|Kiwix]].

## Service Details

- URL: https://torrent.tail8d86e.ts.net
- Namespace: `torrent`
- Image: `lscr.io/linuxserver/transmission:latest`
- ArgoCD app: `torrent`
- Storage: NFS PVC from sifaka (`/volume1/torrents`)

## Useful Commands

```bash
# View transmission logs
kubectl --context=minikube-indri -n torrent logs -f deployment/transmission

# Check RPC connectivity (from another pod)
kubectl --context=minikube-indri run -it --rm curl --image=curlimages/curl -- \
  curl -s http://transmission.torrent.svc.cluster.local:9091/transmission/rpc

# Sync from ArgoCD
argocd app sync torrent
```

## ArgoCD Management

Transmission is deployed via ArgoCD from `argocd/manifests/torrent/`:
- `deployment.yaml` - Transmission container with NFS volume
- `service.yaml` - ClusterIP service (port 9091)
- `ingress-tailscale.yaml` - Tailscale Ingress for web UI
- `pv-nfs.yaml` - NFS PersistentVolume
- `pvc.yaml` - PersistentVolumeClaim

## Storage Layout

The NFS share on sifaka (`/volume1/torrents`) has this structure:
- `/downloads/` - Active downloads and torrent metadata
- `/downloads/complete/` - Completed downloads
- `/config/` - Transmission configuration
- `/watch/` - Watch directory for .torrent files

Kiwix reads from `/downloads/complete/` to serve ZIM archives.

## Integration with Kiwix

The [[kiwix]] deployment includes a torrent-sync sidecar that:
1. Reads the declarative ZIM torrent list from a ConfigMap
2. Adds missing torrents to Transmission via RPC
3. Runs on startup and every 30 minutes

When downloads complete:
1. Transmission moves files to `/downloads/complete/`
2. The zim-watcher CronJob (in kiwix namespace) detects new ZIMs
3. Kiwix deployment is restarted to pick up new archives

## Monitoring

**TODO:** Write custom transmission exporter. Existing exporters (`metalmatze/transmission-exporter`, `sandrotosi/simple_transmission_exporter`) are incompatible with Transmission 4's changed JSON API (type mismatches in `lastScrapeTimedOut` field).

Current monitoring via web UI at https://torrent.tail8d86e.ts.net:
- Active/seeding/paused torrent counts
- Upload/download speeds
- Disk usage

Basic uptime monitoring via blackbox probe in [[alloy|Alloy k8s]] (see Services Health dashboard).

## Log

### 2026-01-22

- Attempted to add `metalmatze/transmission-exporter` sidecar for Prometheus metrics
- Exporter failed with JSON parsing errors - incompatible with Transmission 4 API changes
- Removed exporter sidecar, dashboard, and Prometheus scrape config
- Added basic HTTP probe via Alloy k8s blackbox exporter instead
- Deleted stale `transmission.prom` textfile from indri

### 2026-01-21 (P6)
- **Migrated to Kubernetes** (Phase 6 of k8s migration)
- NFS PersistentVolume for storage on sifaka
- Tailscale Ingress at `torrent.tail8d86e.ts.net`
- RPC accessible to kiwix namespace for torrent sync
- Moved existing ZIM files to `/downloads/complete/` for seeding
- Retired ansible transmission role from indri

### 2026-01-14
- Added transmission role to ansible playbook
- Integrated with kiwix role for torrent-based ZIM downloads
- Initial setup with transmission-cli via homebrew
- Managed via brew services on port 9091
- Metrics collected via textfile exporter
