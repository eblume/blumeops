---
title: Sifaka
modified: 2026-10-30
last-reviewed: 2026-10-27
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
| frigate | `/volume1/frigate` | NVR recordings, clips, models | [[frigate]] |
| paperless | `/volume1/paperless` | Paperless document library | [[paperless]] |
| shower | `shower` (SMB share) | Backup source mounted on indri | [[borgmatic]] |
| models | `/volume1/models` | Open-weight LLM archive (see below) | none yet |

indri reaches backups, allisonflix, photos, music, and shower over **SMB** via `darwin/indri/mount-sifaka.sh`. [[borgmatic]] and [[jellyfin]] consume those SMB mounts.

## Model Archive

`/volume1/models` holds open-weight LLM weights pulled ahead of the M5 Ultra Mac Studio (256GB unified memory) so they survive upstream takedowns or license changes. Picks were sized to load in 256GB with room for KV cache, across small (<35B), medium, and large-MoE tiers (~1TB total).

| Setting | Value |
|---------|-------|
| Created | 2026-10-30, in DSM |
| Data checksum | On (Btrfs bit-rot detection; can only be set at creation) |
| Recycle bin | Off |
| Quota | 1.5TB |
| Permissions | `eblume` read/write |
| NFS | None — copy to the consumer over SMB/rsync |

Layout is `/volume1/models/<org>/<repo>`, mirroring the Hugging Face repo id. The share root also holds `download.sh`, the script that defines what was pulled: it runs in a one-off `python:3.12-slim` container (`llm-download`) using `hf download`. Re-running it resumes and skips completed files:

```bash
ssh sifaka 'sudo /volume1/@appstore/ContainerManager/usr/bin/docker start llm-download'
ssh sifaka 'sudo /volume1/@appstore/ContainerManager/usr/bin/docker logs llm-download 2>&1 | grep ==='
```

The share and the container were set up by hand, outside Ansible. Moving share, NFS, and container management into `provision-sifaka` is tracked in heph.

## NFS Exports

| Export | Allowed Clients | Squash | Purpose |
|--------|-----------------|--------|---------|
| `/volume1/torrents` | 192.168.1.0/24, 100.64.0.0/10 | unverified (check DSM) | k8s pods |
| `/volume1/music` | 192.168.1.0/24, 100.64.0.0/10 | unverified (check DSM) | k8s pods |
| `/volume1/photos` | 192.168.1.0/24, 100.64.0.0/10 | No mapping | k8s pods |
| `/volume1/frigate` | per-host rule (see PV notes) | No mapping (per PV notes) | k8s pods on ringtail |
| `/volume1/reports` | per-host rule (see PV notes) | No mapping (per PV notes) | Prowler reports |
| `/volume1/paperless` | per-host rule (see PV notes) | No mapping | [[paperless]] on ringtail |

Squash settings are configured in DSM, not in this repo. Photos is `No mapping` per a direct check on sifaka recorded in [[security]] (non-root section, 2026-09-05); frigate, reports, and paperless are `No mapping` per their PV setup notes. Torrents and music are unverified, so check the DSM export rules directly rather than assuming `all_squash`. If NFS mounts fail with permission denied, see [[troubleshoot-sifaka-nfs]].

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
- ACL: `tag:homelab` can reach `tag:nas` (general grant)
- **Must run in TUN mode** for NFS — see [[troubleshoot-sifaka-nfs]]

## Backup

Sifaka is the **target** for [[backup|backups]], not a backup source. [[borgmatic]] sends backups TO sifaka, not OF sifaka.

Data protection for sifaka itself currently relies on the Synology RAID 5 configuration, which provides single-disk fault tolerance. Future plans include offsite duplication for additional resiliency.

## Related

- [[troubleshoot-sifaka-nfs]] - NFS permission denied troubleshooting
- [[backups|Backups]] - Backup policy
- [[borgmatic]] - Backup system
- [[frigate]] - NVR recordings consumer
- [[immich]] - Photo consumer
- [[jellyfin]] - Media consumer
- [[navidrome]] - Music consumer
