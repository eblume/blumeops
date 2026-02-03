---
title: Disaster Recovery
tags:
  - operations
---

# Disaster Recovery

TBD. Current state:

- [[borgmatic|Borgmatic]] provides daily backups to [[sifaka|Sifaka]]
- Infrastructure can be rebootstrapped using the blumeops repo
- Detailed DR procedures not yet documented

## Components

- [[borgmatic|Borgmatic]] - Backup restoration
- [[1password|1Password]] - Credential recovery
- [[forgejo|Forgejo]] - Source of truth for infrastructure code
