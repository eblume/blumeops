---
title: Forgejo Runner
modified: 2026-03-30
last-reviewed: 2026-03-30
tags:
  - service
  - ci-cd
---

# Forgejo Runner

Forgejo Actions runner daemon for CI/CD job execution. Runs as a Kubernetes pod on [[indri]] (minikube) with a Docker-in-Docker sidecar.

## Quick Reference

| Property | Value |
|----------|-------|
| **Namespace** | `forgejo-runner` |
| **ArgoCD App** | `forgejo-runner` |
| **Runner Name** | `k8s-runner` |
| **Labels** | `k8s` |
| **Capacity** | 2 concurrent jobs |
| **Timeout** | 3h |
| **Forgejo Instance** | https://forge.ops.eblu.me |
| **Image** | `code.forgejo.org/forgejo/runner` (see `argocd/manifests/forgejo-runner/kustomization.yaml` for current tag) |
| **DinD Sidecar** | `docker:27-dind` |

## Architecture

The pod runs two containers:

1. **runner** - The Forgejo runner daemon. Registers with the forge on first start, then polls for jobs. Talks to DinD via `tcp://localhost:2375`.
2. **dind** - Docker-in-Docker sidecar (privileged). Provides the Docker daemon for job container execution. Uses a registry mirror at `host.minikube.internal:5050` ([[zot]]).

Runner state (`/data/.runner`) is stored in an `emptyDir` volume, so re-registration happens on pod restart. The registration token comes from 1Password via [[external-secrets]].

## Job Execution Image

The actual container image used to run workflow steps is set via `RUNNER_LABELS` in the deployment, not in the runner config. This image is tracked separately as `runner-job-image` in `service-versions.yaml`. See [[build-container-image]] for how it's built.

## Network

Jobs run with `network: "host"` to share the DinD network namespace. This gives job containers access to the same DNS and network as the pod, including cluster-internal services.

## Credentials

| Secret | Source | Purpose |
|--------|--------|---------|
| `RUNNER_TOKEN` | 1Password ("Forgejo Secrets" → `runner_reg`) | Runner registration with forge |

## Related

- [[forgejo]] - The forge this runner connects to
- [[argocd]] - Deployment mechanism
- [[zot]] - Registry mirror for job image pulls
- [[build-container-image]] - How container images are built via this runner
