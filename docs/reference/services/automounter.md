---
title: automounter
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
| backups | `/Volumes/backups` | [[borgmatic]] |
| torrents | `/Volumes/torrents` | [[kiwix]], [[transmission]] |
| music | `/Volumes/music` | [[navidrome]] |
| allisonflix | `/Volumes/allisonflix` | [[jellyfin]] |
| photos | `/Volumes/photos` | [[immich]] |

## Why AutoMounter?

There are free alternatives for mounting network shares on macOS (autofs, automountd, login scripts). AutoMounter was chosen for convenience and has proven reliable. If it becomes problematic, the alternative would be configuring autofs via Ansible.

## Related

- [[indri]] - Host machine
- [[sifaka]] - NAS providing the shares
- [[restart-indri]] - Startup procedure
