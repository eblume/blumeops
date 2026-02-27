---
title: Validate Workflows Against v12
modified: 2026-02-27
last-reviewed: 2026-02-27
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Validate Workflows Against v12

Run `forgejo-runner validate` (available from v9.0+) against all workflow files to catch schema issues before upgrading the k8s runner daemon.

## Result

All 6 workflows pass v12.7.0 schema validation with no changes needed:

- `branch-cleanup.yaml` — OK
- `build-blumeops.yaml` — OK
- `build-container-nix.yaml` — OK
- `build-container.yaml` — OK
- `cv-deploy.yaml` — OK
- `deploy-fly.yaml` — OK

## Deliverables

1. `validate_workflows` function added to `.dagger/src/blumeops_ci/main.py`
   - Uses `forgejo-runner validate --directory .` inside the upstream runner container
   - `runner_version` parameter (default `12.7.0`) pins to deployed version
2. `mise run validate-workflows` task wired to `dagger call validate-workflows`
3. Pre-commit hook triggers on `.forgejo/workflows/` changes

## Usage

```fish
mise run validate-workflows
# or directly:
dagger call validate-workflows --src=.
```

## Related

- [[upgrade-k8s-runner]] — Parent goal
- [[review-runner-config-v12]] — Sibling prerequisite
