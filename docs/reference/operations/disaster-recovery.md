---
title: Disaster Recovery
tags:
  - operations
---

# Disaster Recovery

TBD. Current state:

- [[reference/services/borgmatic|Borgmatic]] provides daily backups to [[reference/storage/sifaka|Sifaka]]
- Infrastructure can be rebootstrapped using the blumeops repo
- Detailed DR procedures not yet documented

## Components

- [[reference/services/borgmatic|Borgmatic]] - Backup restoration
- [[reference/services/1password|1Password]] - Credential recovery
- [[reference/services/forgejo|Forgejo]] - Source of truth for infrastructure code
