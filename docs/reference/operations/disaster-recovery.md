---
title: Disaster Recovery
modified: 2026-03-23
last-reviewed: 2026-03-23
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
| Ringtail/k3s rebuild | [[ringtail]] provisioning (`mise run provision-ringtail`) + ArgoCD bootstrap per [[retire-minikube]] phase 4 |
| Lost 1Password access | [[restore-1password-backup]] |

## Components

- [[backup]] - Backup overview
- [[borgmatic]] - Backup restoration
- [[1password]] - Credential recovery (backed up via `mise run op-backup`)
- [[forgejo]] - Source of truth for infrastructure code
