---
title: Forgejo Runner
modified: 2026-04-20
last-reviewed: 2026-04-20
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
| **Image** | `registry.ops.eblu.me/blumeops/forgejo-runner` (see `argocd/manifests/forgejo-runner/kustomization.yaml` for current tag) |
| **DinD Sidecar** | `docker:27-dind` |

## Architecture

The pod runs two containers:

1. **runner** - The Forgejo runner daemon. Loads a rendered `server.connections` config at startup, then polls for jobs. Talks to DinD via `tcp://localhost:2375`.
2. **dind** - Docker-in-Docker sidecar (privileged). Provides the Docker daemon for job container execution. Uses a registry mirror at `host.minikube.internal:5050` ([[zot]]).

The runner daemon image is built from `containers/forgejo-runner/container.py`, not pulled directly from upstream. Credentials come from 1Password via [[external-secrets]], and the startup script renders the final config before launching the daemon. The `/data` volume remains for the runner home directory and job scratch space, not for `.runner` registration state.

## Job Execution Image

The actual container image used to run workflow steps is declared in `server.connections.labels` in the runner config. This image is tracked separately as `runner-job-image` in `service-versions.yaml`. See [[build-container-image]] for how it's built.

## Network

Jobs run with `network: "host"` to share the DinD network namespace. This gives job containers access to the same DNS and network as the pod, including cluster-internal services.

## Credentials

| Secret | Source | Purpose |
|--------|--------|---------|
| `FORGEJO_RUNNER_UUID` | 1Password ("Forgejo Secrets" → `runner_k8s_uuid`) | Static runner identity for `server.connections` |
| `FORGEJO_RUNNER_TOKEN` | 1Password ("Forgejo Secrets" → `runner_k8s_token`) | Static runner credential for `server.connections` |

## Related

- [[forgejo]] - The forge this runner connects to
- [[argocd]] - Deployment mechanism
- [[zot]] - Registry mirror for job image pulls
- [[build-container-image]] - How container images are built via this runner
