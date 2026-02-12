---
title: Disaster Recovery
date-modified: 2026-02-10
tags:
  - operations
---

# Disaster Recovery

Recovery procedures for BlumeOps infrastructure.

## Procedures

| Scenario | Guide |
|----------|-------|
| Lost 1Password access | [[restore-1password-backup]] |
| Indri reboot/power loss | [[restart-indri]] |

## Components

- [[borgmatic]] - Backup restoration
- [[1password]] - Credential recovery (backed up via `mise run op-backup`)
- [[forgejo]] - Source of truth for infrastructure code
