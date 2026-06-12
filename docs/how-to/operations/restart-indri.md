---
title: Restart Indri
modified: 2026-06-11
last-reviewed: 2026-06-11
tags:
  - how-to
  - operations
---

# Restart Indri

How to safely shut down and restart [[indri]], the primary BlumeOps server.

> Historical note: until 2026-06 indri also hosted the minikube
> Kubernetes cluster, which dominated this procedure (graceful stop,
> random API ports, CNI conflicts). It was retired in
> [[retire-minikube]] — all Kubernetes now runs on [[ringtail]].

## Prerequisites

- SSH access to indri
- Tailscale connected

## Shutdown Procedure

### 1. Stop Native Services (Optional)

Native services managed by launchd will stop automatically during macOS shutdown. However, if you want to stop them explicitly first:

```bash
# LaunchAgent services
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.forgejo.plist'
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.caddy.plist'
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.zot.plist'
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.devpi.plist'  # see [[devpi-on-indri]]
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.jellyfin.plist'
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.alloy.plist'
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.borgmatic.plist'
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.forgejo-runner.plist'
```

### 2. Quit GUI Applications

These apps don't autostart and should be quit cleanly before reboot:

- **Docker Desktop** - Quit from menubar or: `ssh indri 'osascript -e "quit app \"Docker\""'` (backs the forgejo-runner's job containers until phase 6 of [[retire-minikube]])
- **Amphetamine** - Quit from menubar (prevents sleep; will need restart)
- **AutoMounter** - Quit from menubar (mounts sifaka SMB shares)

### 3. Reboot

```bash
ssh indri 'sudo shutdown -r now'
```

Or if you're at the console, use the Apple menu.

## Startup Procedure

After indri boots, most services recover automatically.

**What autostarts:** Docker Desktop and all mcquack LaunchAgent services (Forgejo, Caddy, Zot, Jellyfin, Alloy, Borgmatic, forgejo-runner, metrics collectors).

**What needs manual action:** Amphetamine and AutoMounter.

### 0. Dismiss macOS Permission Dialogs

After a cold boot, the **first inbound Tailscale SSH connection** to indri triggers a macOS GUI permission dialog from tailscaled. This blocks the SSH session (and anything downstream like ansible) until dismissed at the console. You must be logged in to indri (via Screen Sharing or physically) to approve it before running any remote commands.

### 1. Log In and Start GUI Apps

Log in to indri (via Screen Sharing or physically) and launch:

| App | Purpose | Launch Method |
|-----|---------|---------------|
| **Amphetamine** | Prevents sleep | Spotlight or App Store apps |
| **AutoMounter** | Mounts sifaka SMB shares to `/Volumes/` | Spotlight or App Store apps |

Docker Desktop autostarts on login. Wait for it to finish starting (whale icon in menubar stops animating) before proceeding.

### 2. Verify Sifaka Mounts

AutoMounter should automatically mount the sifaka shares. Verify:

```bash
ssh indri 'ls /Volumes/'
```

You should see: `allisonflix`, `backups`, `music`, `photos`, `torrents` (or similar).

If mounts are missing, open AutoMounter and trigger a reconnect.

### 3. Run Health Check

Once everything is up, verify all services:

```bash
mise run services-check
```

All checks should pass. If any fail, see [[troubleshooting]].

## Related

- [[indri]] - Server specifications
- [[troubleshooting]] - Diagnose issues
- [[cluster]] - Kubernetes details (ringtail k3s)
- [[sifaka]] - NAS storage
