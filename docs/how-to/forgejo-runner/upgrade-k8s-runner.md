---
title: Upgrade K8s Forgejo Runner to v12
requires:
  - validate-workflows-against-v12
  - review-runner-config-v12
modified: 2026-02-27
last-reviewed: 2026-02-27
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Upgrade K8s Forgejo Runner to v12

Upgrade the k8s forgejo-runner daemon from v6.3.1 to v12.7.0 (or latest v12.x at time of execution).

## Background

The k8s runner on indri (minikube) uses the upstream `code.forgejo.org/forgejo/runner` image, currently pinned to v6.3.1. The latest is v12.7.0. The runner is still in alpha and uses major version bumps for each breaking change, so v6→v12 crosses six major versions. The ringtail runner is already at ~v12.6.4 via nixpkgs and needs no work.

Blast radius is low — if the upgrade breaks CI, revert the image tag in `argocd/manifests/forgejo-runner/deployment.yaml` and sync.

## Breaking Changes Crossed

| Version | Change | Impact |
|---------|--------|--------|
| v7.0 | CLI `--gitea-instance` → `--forgejo-instance`; `FORGEJO_*` env vars | Low — our registration doesn't use the old flag |
| v8.0 | Workflow schema validation; default image → `node:22-bookworm` | Workflows must pass validation |
| v9.0 | Stricter schema + actions validation; `forgejo-runner validate` added | Same — but now we have a tool |
| v10.0 | Cache isolation; skip v10.0.0 (regression) | Low |
| v11.0 | License MIT → GPLv3 | Non-technical |
| v12.0 | Git binary required; git worktrees for remote actions | Low — OCI image includes git |

## Execution Steps

Once prerequisites are met:

1. Update `argocd/manifests/forgejo-runner/deployment.yaml`:
   - Change runner image from `code.forgejo.org/forgejo/runner:6.3.1` to `code.forgejo.org/forgejo/runner:12.7.0`
2. Update `argocd/manifests/forgejo-runner/config.yaml` with any config changes from [[review-runner-config-v12]]
3. Push, sync ArgoCD: `argocd app sync forgejo-runner`
4. Verify runner registers and connects: check Forgejo admin → runners
5. Trigger a test workflow (manual dispatch of `build-container.yaml` or `branch-cleanup.yaml`)
6. Update `service-versions.yaml` to note the daemon version

## Rollback

Revert the image tag to `6.3.1` in `deployment.yaml`, push, and sync.

## Related

- [[forgejo]] — Forgejo service reference
- [[validate-workflows-against-v12]] — Pre-upgrade workflow validation
- [[review-runner-config-v12]] — Config format review
