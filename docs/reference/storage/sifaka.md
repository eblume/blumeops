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
| backups | `/volume1/backups` | Borg backup repository | [[Borgmatic]] |
| torrents | `/volume1/torrents` | ZIM downloads | [[Kiwix]], [[Transmission]] |
| music | `/volume1/music` | Music library | [[Navidrome]] |
| allisonflix | `/volume1/allisonflix` | Video library | [[Jellyfin]] |
| photos | `/volume1/photos` | Photo library | [[Immich]] |

## NFS Exports

| Export | Allowed Clients | Purpose |
|--------|-----------------|---------|
| `/volume1/torrents` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |
| `/volume1/music` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |
| `/volume1/photos` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |

## Monitoring

Node exporter running in Docker container, scraped by [[Prometheus]] at `sifaka:9100`.

## Tailscale

- Tag: `tag:nas`
- ACL: `tag:homelab` can access for backups

## Backup

Sifaka is the **target** for [[Backup|backups]], not a backup source. [[Borgmatic]] sends backups TO sifaka, not OF sifaka.

Data protection for sifaka itself currently relies on the Synology RAID 5 configuration, which provides single-disk fault tolerance. Future plans include offsite duplication for additional resiliency.

## Related

- [[Backup Policy|Backups]] - Backup policy
- [[Borgmatic]] - Backup system
- [[Immich]] - Photo consumer
- [[Jellyfin]] - Media consumer
- [[Navidrome]] - Music consumer
