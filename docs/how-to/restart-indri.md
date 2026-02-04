---
title: restart-indri
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

After indri boots, several things need manual attention.

### 1. Start GUI Applications

These must be started manually after reboot. Log in to indri (via Screen Sharing or physically) and launch:

| App | Purpose | Launch Method |
|-----|---------|---------------|
| **Docker Desktop** | Container runtime for minikube | Spotlight or `/Applications/Docker.app` |
| **Amphetamine** | Prevents sleep | Spotlight or App Store apps |
| **AutoMounter** | Mounts sifaka SMB shares to `/Volumes/` | Spotlight or App Store apps |

Wait for Docker Desktop to fully start (whale icon in menubar stops animating).

### 2. Verify Sifaka Mounts

AutoMounter should automatically mount the sifaka shares. Verify:

```bash
ssh indri 'ls /Volumes/'
```

You should see: `allisonflix`, `backups`, `music`, `photos`, `torrents` (or similar).

If mounts are missing, open AutoMounter and trigger a reconnect.

### 3. Start Minikube

```bash
ssh indri 'minikube start'
```

This starts the Kubernetes cluster inside Docker. It may take a few minutes as all pods come up.

Monitor pod startup:

```bash
kubectl --context=minikube-indri get pods -A -w
```

### 4. Verify Native Services

LaunchAgent services should start automatically. Check them:

```bash
ssh indri 'launchctl list | grep mcquack'
ssh indri 'brew services list | grep forgejo'
```

If any are missing, Ansible can restore them:

```bash
mise run provision-indri
```

### 5. Run Health Check

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
