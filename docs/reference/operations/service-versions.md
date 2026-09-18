---
title: Service Versions
modified: 2026-09-17
last-reviewed: 2026-04-12
tags:
  - reference
  - maintenance
  - services
---

# Service Versions

`service-versions.yaml` (repo root) tracks version information for all deployed services and tools in blumeops. Each entry records the service name, deployment type, release ownership, current version, upstream source, and when it was last reviewed.

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

## Release Ownership (`release`)

`type` is the deploy mechanism; `release` is an orthogonal axis: who advances
`current-version`. The field is optional — absent (or any value other than
`self`) means the service tracks an external upstream and its review asks
"is there a newer upstream version to bump?". `release: self` marks a
first-party service whose version is advanced by its own release pipeline
(horkos, cv, docs, talos, and the hephaestus entries). For those, the review
checks pipeline health instead — last release actually published, pin/deploy
landed, deployed version == `current-version`, app healthy — and then
refreshes build deps in the source repo. See [[review-services]].

Self-released services stay in the staleness queue: `last-reviewed` still
measures human attention.

## Null fields

`last-reviewed` and `current-version` may be `null` when a version genuinely
isn't known — an install nothing asserts, or a host that couldn't be reached.
`service-review` floats null review dates to the top of the queue, which is the
right place for an untracked install. Prefer null over a guessed version: a
plausible-looking number that was never verified is worse than an obvious gap.

## Related

- [[review-services]] — How to review services for version freshness
