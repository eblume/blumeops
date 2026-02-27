---
title: Review Runner Config for v12
modified: 2026-02-27
last-reviewed: 2026-02-27
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Review Runner Config for v12

Compare the current runner ConfigMap against the v12.7.0 default config to identify new, changed, or deprecated keys.

## Findings

Compared `forgejo-runner generate-config` output from v6.3.1 and v12.7.0. Our config is minimal and remains valid for v12.

### New sections in v12 (not adopted)

- **`server.connections`** — multi-server polling. Not needed (single Forgejo instance).
- **`cache.secret_url`** — load cache secret from file URL. Not needed.
- **`runner.report_retry`** — retry config for log uploads. Defaults are fine.

### Changed semantics

- **`container.docker_host`** — v12 supports `unix://` and `ssh://` URLs. Our explicit `tcp://127.0.0.1:2375` still correct for DinD sidecar.
- **`cache`** section restructured with proxy/server split and better docs. We don't configure cache, so defaults apply.

### Config update applied

Added `shutdown_timeout: 3h` to allow graceful job completion on pod termination (v12 default, was missing from our v6 config). Added review date comment.

`container.valid_volumes` and `container.options` left empty — our jobs use host networking and don't mount volumes. Can harden later if needed.

## Related

- [[upgrade-k8s-runner]] — Parent goal
- [[validate-workflows-against-v12]] — Sibling prerequisite
