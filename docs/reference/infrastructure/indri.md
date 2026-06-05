---
title: Indri
modified: 2026-05-27
last-reviewed: 2026-05-27
tags:
  - infrastructure
  - host
---

# Indri

Primary BlumeOps server. Mac Mini M1 (2020).

## Specifications

| Property | Value |
|----------|-------|
| **Model** | Mac mini M1, 2020 (Macmini9,1) |
| **CPU / RAM** | 8 cores / 16 GB |
| **Storage** | 2TB internal SSD |
| **macOS** | 15.7.3 (Sequoia) |
| **Tailscale hostname** | `indri.tail8d86e.ts.net` |
| **Tailscale Tag** | `tag:homelab` |
| **Power** | [[power|Battery-backed UPS]] |

## Services Hosted

**Native (via Ansible):**
- [[forgejo]] - Git forge
- [[zot]] - Container registry
- [[jellyfin]] - Media server
- [[borgmatic]] - Backup system
- [[alloy|Alloy]] - Metrics/logs collector
- [[caddy]] - Reverse proxy for `*.ops.eblu.me`
- [[devpi]] - PyPI mirror (LaunchAgent)
- [[hephaestus]] - heph task/context sync hub (LaunchAgent, self-updating)
- [[cv]] - Static CV site, served by Caddy
- [[docs]] - Quartz-built docs site, served by Caddy

**Kubernetes (via minikube):**
- [[apps|Most k8s applications]]. A growing set of apps (Authentik, Frigate, ntfy, Immich, Homepage, Shower, Kingfisher, alloy-ringtail) now run on [[ringtail]]'s k3s instead. Long-term plan is to decommission indri's minikube entirely.

**GUI Applications (manual start required):**
- Docker Desktop - Container runtime for minikube
- Amphetamine - Prevents sleep
- [[automounter]] - Mounts [[sifaka]] SMB shares

## Maintenance Notes

**Sleep prevention:** Uses Amphetamine (App Store) to prevent sleep. If Amphetamine crashes after extended uptime, consider switching to `pmset` or `caffeinate` via ansible.

**Passwordless sudo:** Configured for `erichblume` user (`/etc/sudoers.d/erichblume`) to allow ansible `become: true` without prompts. Acceptable given Tailscale is the trust boundary.

## Related

- [[routing]] - Port mappings
- [[cluster]] - Minikube details
- [[automounter]] - SMB share mounting
- [[restart-indri]] - Shutdown and startup procedure
