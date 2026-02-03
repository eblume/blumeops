---
title: Sifaka NAS
tags:
  - storage
---

# Sifaka NAS

Synology NAS providing network storage and backup target.

## Quick Reference

| Property | Value |
|----------|-------|
| **Dashboard** | https://nas.ops.eblu.me |
| **Model** | Synology |
| **Storage** | 10.9TB RAID 5 |
| **Role** | Backup target, media storage |

## Network Shares

| Share | Path | Purpose | Consumers |
|-------|------|---------|-----------|
| backups | `/volume1/backups` | Borg backup repository | [[services/borgmatic|Borgmatic]] |
| torrents | `/volume1/torrents` | ZIM downloads | [[services/kiwix|Kiwix]], [[services/transmission|Transmission]] |
| music | `/volume1/music` | Music library | [[services/navidrome|Navidrome]] |
| allisonflix | `/volume1/allisonflix` | Video library | [[services/jellyfin|Jellyfin]] |
| photos | `/volume1/photos` | Photo library | [[services/immich|Immich]] |

## NFS Exports

| Export | Allowed Clients | Purpose |
|--------|-----------------|---------|
| `/volume1/torrents` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |
| `/volume1/music` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |
| `/volume1/photos` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |

## Monitoring

Node exporter running in Docker container, scraped by [[services/prometheus|Prometheus]] at `sifaka:9100`.

## Tailscale

- Tag: `tag:nas`
- ACL: `tag:homelab` can access for backups

## Backup

Sifaka is the **target** for [[operations/backup|backups]], not a backup source. [[services/borgmatic|Borgmatic]] sends backups TO sifaka, not OF sifaka.

Data protection for sifaka itself currently relies on the Synology RAID 5 configuration, which provides single-disk fault tolerance. Future plans include offsite duplication for additional resiliency.

## Related

- [[storage/backups|Backups]] - Backup policy
- [[services/borgmatic|Borgmatic]] - Backup system
- [[services/immich|Immich]] - Photo consumer
- [[services/jellyfin|Jellyfin]] - Media consumer
- [[services/navidrome|Navidrome]] - Music consumer
