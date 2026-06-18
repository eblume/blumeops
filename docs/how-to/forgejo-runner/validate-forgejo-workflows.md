---
title: Validate Forgejo Workflows
modified: 2026-06-17
last-reviewed: 2026-04-20
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Validate Forgejo Workflows

Run `forgejo-runner validate` against all workflow files to catch schema issues before upgrading the k8s runner daemon.

## Result

All current workflows pass the validation step with no changes needed:

- `branch-cleanup.yaml` — OK
- `build-blumeops.yaml` — OK
- `build-container.yaml` — OK
- `cv-deploy.yaml` — OK
- `deploy-fly.yaml` — OK

## Deliverables

1. `validate_workflows` function added to `src/blumeops/main.py` (formerly `.dagger/src/blumeops_ci/main.py`)
   - Uses `forgejo-runner validate --directory .` inside the upstream runner container
   - `runner_version` parameter pins validation to the deployed runner line
2. `mise run validate-workflows` task wired to `dagger call validate-workflows`
3. Pre-commit hook triggers on `.forgejo/workflows/` changes

## Usage

```fish
mise run validate-workflows
# or directly:
dagger call validate-workflows --src=.
```

## Related

- [[configure-k8s-runner]] — Runner configuration and upgrade flow
