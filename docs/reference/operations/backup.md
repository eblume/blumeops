---
title: Backup
modified: 2026-10-08
last-reviewed: 2026-10-08
tags:
  - operations
---

# Backup

Daily automated backups of BlumeOps data (run by borgmatic on indri, daily at
2/3/4 AM across tiers).

## Components

- [[borgmatic]] - Backup orchestration
- [[sifaka|Sifaka]] - Primary backup target (NAS); [[borgmatic]] also ships the archive and photos tiers offsite to BorgBase
- [[backups]] - What gets backed up and retention
- [[disaster-recovery]] - Recovery procedures
