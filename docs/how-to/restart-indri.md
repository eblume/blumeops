---
title: Restart Indri
tags:
  - how-to
  - operations
---

# Restart Indri

How to safely shut down and restart [[indri]], the primary BlumeOps server.

## Prerequisites

- SSH access to indri
- Tailscale connected

## Shutdown Procedure

### 1. Stop Kubernetes Gracefully

Minikube runs on the Docker driver, so stopping it cleanly ensures pods terminate gracefully and persistent volumes are properly unmounted.

```bash
ssh indri 'minikube stop'
```

This may take a minute as pods receive termination signals. You can verify it stopped:

```bash
ssh indri 'minikube status'
```

### 2. Stop Native Services (Optional)

Native services managed by launchd will stop automatically during macOS shutdown. However, if you want to stop them explicitly first:

```bash
# Forgejo (managed by brew services)
ssh indri 'brew services stop forgejo'

# LaunchAgent services
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.zot.plist'
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.alloy.plist'
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.borgmatic.plist'
```

### 3. Quit GUI Applications

These apps don't autostart and should be quit cleanly before reboot:

- **Docker Desktop** - Quit from menubar or: `ssh indri 'osascript -e "quit app \"Docker\""'`
- **Amphetamine** - Quit from menubar (prevents sleep; will need restart)
- **AutoMounter** - Quit from menubar (mounts sifaka SMB shares)

### 4. Reboot

```bash
ssh indri 'sudo shutdown -r now'
```

Or if you're at the console, use the Apple menu.

## Startup Procedure

After indri boots, most services recover automatically. Only a few things need manual attention.

**What autostarts:** Docker Desktop, brew services (Forgejo, Caddy), and all mcquack LaunchAgent services (Zot, Alloy, Borgmatic, metrics collectors).

**What needs manual action:** Amphetamine, AutoMounter, and minikube (including its Tailscale serve port).

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

### 3. Fix Minikube Remote Access

Minikube uses the Docker driver, which assigns a **random API server port** on each start. After a reboot, the Tailscale serve proxy (`k8s.tail8d86e.ts.net`) will still point to the old port, breaking remote `kubectl` access.

Run the minikube ansible role to detect the new port and update Tailscale serve:

```bash
mise run provision-indri -- --tags minikube
```

This will:
- Start minikube if it hasn't started yet
- Detect the current API server port
- Update `tailscale serve` to forward to the correct port

You can verify remote access works:

```bash
kubectl --context=minikube-indri get nodes
```

### 4. Run Health Check

Once everything is up, verify all services:

```bash
mise run services-check
```

All checks should pass. If any fail, see [[troubleshooting]].

## Related

- [[indri]] - Server specifications
- [[troubleshooting]] - Diagnose issues
- [[cluster]] - Kubernetes details
- [[sifaka]] - NAS storage
