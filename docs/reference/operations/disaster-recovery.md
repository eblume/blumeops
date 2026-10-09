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
| Ringtail/k3s rebuild | [[ringtail]] provisioning (`mise run provision-ringtail`, which also seeds the 1Password Connect secrets), then the manual ArgoCD bootstrap runbook in `argocd/manifests/argocd/README.md` (see [[argocd]]) |
| Lost 1Password access | [[restore-1password-backup]] |

## Components

- [[backup]] - Backup overview
- [[borgmatic]] - Backup restoration
- [[1password]] - Credential recovery (backed up via `mise run op-backup`)
- [[forgejo]] - Source of truth for infrastructure code
