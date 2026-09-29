---
title: Sifaka Mounter
modified: 2026-09-29
last-reviewed: 2026-09-29
tags:
  - services
  - macos
  - nix
---

# Sifaka Mounter

nix-darwin user LaunchAgent `mcquack.eblume.sifaka-mounter` in the
`darwin/indri` flake (`launchd.user.agents."mcquack.eblume.sifaka-mounter"`),
replaces AutoMounter (see retired [[automounter]] page). Runs `mount-sifaka`
(store writeScript) at load, every 60 s, and once at 01:45 (borgmatic runs
unattended at 02:00).

## Quick Reference

| Property | Value |
|----------|-------|
| **Unit** | `mcquack.eblume.sifaka-mounter` |
| **Script** | `darwin/indri/mount-sifaka.sh` |
| **Server** | `smb://eblume@sifaka._smb._tcp.local/<share>` (Bonjour name kept from AutoMounter's config) |
| **Credential** | Login Keychain (internet password for `eblume`) |
| **Logs** | `/opt/homebrew/var/log/mcquack.sifaka-mounter.{out,err}.log` |
| **Metric** | `sifaka.prom` in alloy's textfile dir |

## Mounted Shares

| Share | Mount Point | Consumers |
|-------|-------------|-----------|
| backups | `/Volumes/backups` | borgmatic repository storage |
| photos | `/Volumes/photos` | borgmatic, immich library/upload |
| shower | `/Volumes/shower` | borgmatic source |
| allisonflix | `/Volumes/allisonflix` | [[jellyfin]]; `rip-video-finish` |
| music | `/Volumes/music` | `rip-cd-finish` |

`torrents` and `frigate` are no longer mounted on indri (vestigial since
[[retire-minikube]]; ringtail workloads use NFS —
[[sifaka-nfs-from-ringtail]]).

## How It Works and Safety

`osascript -e 'mount volume "smb://…"'` (NetFS path, same as Finder — creates
`/Volumes/<share>`, reads the login Keychain; no credential in repo/argv).
launchd never overlaps a one-shot job with itself, so at most one run is in progress; each `mount volume` is
killed after 30 s (perl SIGALRM; macOS has no coreutils timeout), so a
missing Keychain entry can never leave a GUI credential dialog behind —
indri dialogs block services. A failed mount is reported in the metric and
retried at the next interval, not retried within a run.

### Missing Keychain entry

Shows up as `sifaka_share_mounted{share=...} 0` (alert through the existing
Alloy → Prometheus path), NOT as a prompt. Seeding: on an interactive
session run one manual `osascript -e 'mount volume "smb://eblume@sifaka._smb._tcp.local/backups"'`
and tick "Remember in Keychain" — never `security add-internet-password`.

### #1225 note

The writeScript's first line is `#!/bin/sh`, the same argv[0] class as the
`*-metrics` collectors — no boot-criticality; during the pre-/nix window the
run fails 127 and the next interval retries.

## Verification

- `ssh indri 'mount | grep /Volumes'`
- The agent's out/err logs
- `sifaka_share_mounted == 1` for all five shares in Prometheus

## Related

- [[indri]] - Host machine
- [[sifaka]] - NAS providing the shares
- [[borgmatic]] - Main consumer (02:00 runs)
- [[restart-indri]] - Startup procedure
