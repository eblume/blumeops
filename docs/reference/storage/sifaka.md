---
title: Sifaka
tags:
  - storage
---

# Sifaka NAS

Synology NAS providing network storage and backup target.

## Quick Reference

| Property | Value |
|----------|-------|
| **Dashboard** | https://nas.ops.eblu.me |
| **Model** | Synology DS423+ (DSM 7) |
| **Storage** | 10.9TB RAID 5 (4x Seagate IronWolf 4TB, ST4000VN006) |
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

Prometheus exporters run as Docker containers, managed by Ansible (`mise run provision-sifaka`).

| Exporter | Port | Purpose |
|----------|------|---------|
| node_exporter | 9100 | System metrics (CPU, memory, disk I/O) |
| smartctl_exporter | 9633 | SMART disk health data |

Scraped by [[prometheus]] via Caddy L4 TCP proxy at `nas.ops.eblu.me:9100` and `nas.ops.eblu.me:9633`. Dashboard: [[grafana]] > Sifaka Disk Health.

## First-Time Setup

These steps were performed once to enable Ansible provisioning. They are documented here for reference if sifaka is ever replaced or reset.

### 1. Enable SSH

DSM Control Panel > Terminal & SNMP > Enable SSH service (port 22).

### 2. SSH Key Authentication

From a tailnet client with an existing SSH key:

```bash
ssh-copy-id eblume@sifaka   # uses password auth initially
```

Synology requires strict permissions on the home directory. On sifaka:

```bash
chmod 755 ~                  # DSM defaults to 777; SSH refuses keys otherwise
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Home directory path: `/var/services/homes/eblume`.

### 3. Passwordless Sudo for Docker

Ansible needs `become: true` for Docker commands. Create a sudoers drop-in:

```bash
sudo vi /etc/sudoers.d/docker-ansible
```

Contents:

```
eblume ALL=(ALL) NOPASSWD: /volume1/@appstore/ContainerManager/usr/bin/docker
```

This grants passwordless sudo only for the Docker binary — no broader root access.

### 4. Docker Path

Synology installs Docker via Container Manager at a non-standard path:

```
/volume1/@appstore/ContainerManager/usr/bin/docker
```

This is configured in the `sifaka_exporters` role defaults.

### 5. Synology Device Naming

Synology uses `/dev/sata*` (e.g., `/dev/sata1` through `/dev/sata4`) instead of the standard `/dev/sd*` naming. The `smartctl_exporter` cannot auto-detect these devices, so they are passed explicitly via `--smartctl.device=` flags in the Ansible role.

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
