---
title: disaster-recovery
tags:
  - operations
---

# Disaster Recovery

TBD. Current state:

- [[borgmatic]] provides daily backups to [[sifaka-nas|Sifaka]]
- Infrastructure can be rebootstrapped using the blumeops repo
- Detailed DR procedures not yet documented

## Components

- [[borgmatic]] - Backup restoration
- [[1password]] - Credential recovery
- [[forgejo]] - Source of truth for infrastructure code
