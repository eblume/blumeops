---
title: Disaster Recovery
tags:
  - operations
---

# Disaster Recovery

TBD. Current state:

- [[services/borgmatic|Borgmatic]] provides daily backups to [[storage/sifaka|Sifaka]]
- Infrastructure can be rebootstrapped using the blumeops repo
- Detailed DR procedures not yet documented

## Components

- [[services/borgmatic|Borgmatic]] - Backup restoration
- [[services/1password|1Password]] - Credential recovery
- [[services/forgejo|Forgejo]] - Source of truth for infrastructure code
