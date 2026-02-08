---
title: Indri
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
| **Storage** | 2TB internal SSD |
| **macOS** | 15.7.3 (Sequoia) |
| **Tailscale IP** | 100.98.163.89 |
| **Tailscale Tag** | `tag:homelab` |
| **UPS** | Anker SOLIX F2000 GaNPrime |

## Services Hosted

**Native (via Ansible):**
- [[forgejo]] - Git forge
- [[zot]] - Container registry
- [[jellyfin]] - Media server
- [[borgmatic]] - Backup system
- [[alloy|Alloy]] - Metrics/logs collector
- [[caddy]] - Reverse proxy for `*.ops.eblu.me`

**Kubernetes (via minikube):**
- [[apps|All k8s applications]]

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
