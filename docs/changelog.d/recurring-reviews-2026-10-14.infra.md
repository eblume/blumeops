CloudNativePG operator 1.29.1 → 1.30.1 (1.29 series is EOL upstream); the
bump picks up the CVE-2026-55769 and CVE-2026-84304 fixes. The 1.30 CEL-immutable
`cluster` reference change has no surface here — no Database, Pooler, Publication,
Subscription, or ScheduledBackup CRs exist.
