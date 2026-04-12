---
title: Service Versions
modified: 2026-04-12
last-reviewed: 2026-04-12
tags:
  - reference
  - maintenance
  - services
---

# Service Versions

`service-versions.yaml` (repo root) tracks version information for all deployed services and tools in blumeops. Each entry records the service name, deployment type, current version, upstream source, and when it was last reviewed.

This file enables a regular update cadence via `mise run service-review`, which surfaces stale services sorted by review date. See [[review-services]] for the full review process.

## Related

- [[review-services]] — How to review services for version freshness
