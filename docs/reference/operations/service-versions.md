---
title: Service Versions
modified: 2026-07-30
last-reviewed: 2026-04-12
tags:
  - reference
  - maintenance
  - services
---

# Service Versions

`service-versions.yaml` (repo root) tracks version information for all deployed services and tools in blumeops. Each entry records the service name, deployment type, current version, upstream source, and when it was last reviewed.

This file enables a regular update cadence via `mise run service-review`, which surfaces stale services sorted by review date. See [[review-services]] for the full review process.

## Types

`type` is free text — nothing validates it; it only drives the `--type` filter on
`mise run service-review`. In use:

| Type | Meaning |
|------|---------|
| `argocd` | k8s workload on ringtail, synced by ArgoCD |
| `ansible` | native service on indri, converged by an ansible role |
| `nixos` | pinned in ringtail's NixOS config (`nixos/ringtail/`) |
| `container` | locally built container image |
| `fly` | runs in the Fly.io proxy (`fly/`) |
| `mise` | dev/ops CLI pinned in `mise.toml` |
| `manual` | installed by hand, not under IaC — inherently drift-prone, so these should carry a note saying what the real fix would be |

## Null fields

`last-reviewed` and `current-version` may be `null` when a version genuinely
isn't known — an install nothing asserts, or a host that couldn't be reached.
`service-review` floats null review dates to the top of the queue, which is the
right place for an untracked install. Prefer null over a guessed version: a
plausible-looking number that was never verified is worse than an obvious gap.

## Related

- [[review-services]] — How to review services for version freshness
