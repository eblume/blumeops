---
title: sifaka-nas
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
| backups | `/volume1/backups` | Borg backup repository | [[borgmatic]] |
| torrents | `/volume1/torrents` | ZIM downloads | [[kiwix]], [[transmission]] |
| music | `/volume1/music` | Music library | [[navidrome]] |
| allisonflix | `/volume1/allisonflix` | Video library | [[jellyfin]] |
| photos | `/volume1/photos` | Photo library | [[immich]] |

## NFS Exports

| Export | Allowed Clients | Purpose |
|--------|-----------------|---------|
| `/volume1/torrents` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |
| `/volume1/music` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |
| `/volume1/photos` | 192.168.1.0/24, 100.64.0.0/10 | k8s pods via Docker NAT |

## Monitoring

Node exporter running in Docker container, scraped by [[prometheus]] at `sifaka:9100`.

## Tailscale

- Tag: `tag:nas`
- ACL: `tag:homelab` can access for backups

## Backup

Sifaka is the **target** for [[backup|backups]], not a backup source. [[borgmatic]] sends backups TO sifaka, not OF sifaka.

Data protection for sifaka itself currently relies on the Synology RAID 5 configuration, which provides single-disk fault tolerance. Future plans include offsite duplication for additional resiliency.

## Related

- [[backups|Backups]] - Backup policy
- [[borgmatic]] - Backup system
- [[immich]] - Photo consumer
- [[jellyfin]] - Media consumer
- [[navidrome]] - Music consumer
