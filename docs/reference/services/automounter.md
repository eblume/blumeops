---
title: Automounter
modified: 2026-06-12
last-reviewed: 2026-06-12
tags:
  - services
  - macos
---

# AutoMounter

macOS app that automatically mounts [[sifaka]] SMB shares on [[indri]].

## Quick Reference

| Property | Value |
|----------|-------|
| **App** | [AutoMounter](https://www.pixeleyes.co.nz/automounter/) |
| **Source** | Mac App Store (paid) |
| **Autostart** | No (must launch manually after reboot) |
| **Purpose** | Mount sifaka SMB shares to `/Volumes/` |

## Mounted Shares

| Share | Mount Point | Consumers |
|-------|-------------|-----------|
| backups | `/Volumes/backups` | [[borgmatic]] (repository storage) |
| photos | `/Volumes/photos` | [[borgmatic]] (backs up immich library/upload) |
| shower | `/Volumes/shower` | [[borgmatic]] (backup source) |
| allisonflix | `/Volumes/allisonflix` | [[jellyfin]] |
| music | `/Volumes/music` | none — vestigial since [[retire-minikube]] |
| torrents | `/Volumes/torrents` | none — vestigial since [[retire-minikube]] |
| frigate | `/Volumes/frigate` | none — vestigial since [[retire-minikube]] |

Workloads that moved to ringtail k3s ([[navidrome]], [[immich]], [[kiwix]],
[[transmission]], [[frigate]], paperless) mount sifaka directly over NFS
(see [[sifaka-nfs-from-ringtail]]) rather than going through indri's SMB
mounts. The vestigial mounts are harmless but could be removed from
AutoMounter's configuration; note that borgmatic still reads `photos` over
SMB even though immich itself uses NFS.

## Why AutoMounter?

There are free alternatives for mounting network shares on macOS (autofs, automountd, login scripts). AutoMounter was chosen for convenience and has proven reliable. If it becomes problematic, the alternative would be configuring autofs via Ansible.

## Related

- [[indri]] - Host machine
- [[sifaka]] - NAS providing the shares
- [[restart-indri]] - Startup procedure
