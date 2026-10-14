---
title: Disaster Recovery
modified: 2026-10-09
last-reviewed: 2026-10-09
tags:
  - operations
---

# Disaster Recovery

Recovery procedures for BlumeOps infrastructure.

## Procedures

| Scenario | Guide |
|----------|-------|
| Indri reboot/power loss | [[restart-indri]] |
| Ringtail reboot/power loss/hardware swap | [[restart-ringtail]] |
| Ringtail/k3s rebuild | 1) `mise run seed-secrets ringtail` ([[seed-secrets]] — human, biometric `op`); 2) human-local apply over `ssh ringtail` — first the one-time `sudo git clone https://forge.ops.eblu.me/eblume/blumeops.git /etc/blumeops`, then: fresh host (no blumeops generation active yet, so the `ringtail-apply@` unit does not exist) → `sudo nixos-rebuild switch --flake /etc/blumeops/nixos/ringtail#ringtail` (a full system build); host that already runs a blumeops generation → `sudo systemctl start --no-block ringtail-apply@<sha>` (`<sha>` is the full 40-hex `git rev-parse origin/main` from the clone), then tail `/var/log/ringtail-apply/<sha>.log` and check the `.status` sidecar; 3) the ArgoCD bootstrap runbook in `argocd/manifests/argocd/README.md` (see [[argocd]]; includes the 1Password Connect bootstrap) |
| Lost 1Password access | [[restore-1password-backup]] |

## Components

- [[backup]] - Backup overview
- [[borgmatic]] - Backup restoration
- [[1password]] - Credential recovery (backed up via `mise run op-backup`)
- [[forgejo]] - Source of truth for infrastructure code
