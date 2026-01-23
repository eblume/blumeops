# Forgejo Actions CI/CD Bootstrap Plan

This plan details the setup of Forgejo Actions as the CI/CD system for blumeops, starting with the bootstrapping problem: using Forgejo to build and deploy Forgejo itself.

## Goals

1. **Forgejo Actions** as the primary CI system (replaces Woodpecker from original plan)
2. **Self-hosted Forgejo** built from source, deployed as mcquack LaunchAgent on indri
3. **Container builds** for ArgoCD manifests (devpi, etc.)
4. **Cron-scheduled tasks** via k8s CronJobs (not Actions)
5. **Local development** parity using `act` for workflow testing

## Why Forgejo Actions over Woodpecker?

- Native integration with Forgejo (no OAuth setup, automatic repo detection)
- GitHub Actions compatible syntax (huge ecosystem of reusable actions)
- `act` tool for local testing on gilbert
- Single system to maintain instead of two

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                           INDRI                                  │
│  ┌─────────────────────┐                                        │
│  │     Forgejo         │ ← Built from source                    │
│  │   (mcquack agent)   │ ← Deploys itself via CI                │
│  │                     │                                        │
│  │  - Web UI (3001)    │                                        │
│  │  - SSH (2200)       │                                        │
│  │  - Actions enabled  │                                        │
│  └─────────────────────┘                                        │
└─────────────────────────────────────────────────────────────────┘
         │
         │ SSH deploy
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      KUBERNETES (minikube)                       │
│  ┌─────────────────────┐     ┌─────────────────────┐           │
│  │   Forgejo Runner    │     │    Other Services   │           │
│  │   (act_runner)      │     │    (via ArgoCD)     │           │
│  │                     │     │                     │           │
│  │  - Polls Forgejo    │     │                     │           │
│  │  - Runs workflows   │     │                     │           │
│  │  - Docker-in-Docker │     │                     │           │
│  └─────────────────────┘     └─────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Phases

| Phase | Name | Description |
|-------|------|-------------|
| 1 | [Enable Actions](P1_enable_actions.md) | Configure Forgejo for Actions, deploy runner |
| 2 | [Mirror & Build](P2_mirror_and_build.md) | Mirror upstream Forgejo, create build workflow |
| 3 | [Self-Deploy](P3_self_deploy.md) | Forgejo deploys itself, transition to mcquack |
| 4 | [Container Builds](P4_container_builds.md) | Build custom container images (devpi, etc.) |

## The Bootstrap Problem

**Chicken-and-egg**: We need Forgejo Actions to build Forgejo, but Forgejo must be running first.

**Solution**:
1. Keep current brew-based Forgejo running during setup
2. Enable Actions, deploy runner
3. Mirror upstream Forgejo, create build workflow
4. First CI build creates the binary
5. CI deploys binary to indri as mcquack service
6. `brew services stop forgejo` and uninstall
7. Future builds: Forgejo builds and deploys itself

**Risk mitigation**: If self-deployment breaks Forgejo:
- blumeops is mirrored to GitHub
- Manual recovery: build on gilbert, scp to indri, restart service
- See Disaster Recovery section in P3

## Ansible Role Strategy

The forgejo ansible role will follow the zot/alloy pattern:

1. **Check binary exists** at expected path
2. **If missing**: Fail with message pointing to CI trigger instructions
3. **If present**: Deploy config, ensure LaunchAgent loaded

Ansible does NOT:
- Build the binary (that's CI's job)
- Deploy new versions (that's CI's job)

Ansible DOES:
- Manage app.ini configuration (sans secrets)
- Manage mcquack LaunchAgent plist
- Ensure service is running
- Collect logs via Alloy

## Files Summary

### New Files

| Path | Purpose |
|------|---------|
| `argocd/apps/forgejo-runner.yaml` | ArgoCD Application for runner |
| `argocd/manifests/forgejo-runner/` | Runner k8s manifests |
| `.forgejo/workflows/build-forgejo.yml` | Build workflow in blumeops repo |
| (on forge) `eblume/forgejo/.forgejo/workflows/` | Build workflow in forgejo mirror |

### Modified Files

| Path | Change |
|------|--------|
| `ansible/roles/forgejo/` | Complete rewrite for mcquack pattern |
| `ansible/roles/alloy/defaults/main.yml` | Update forgejo log paths |
| zk cards | Update forgejo, argocd, blumeops cards |

### Credentials Needed

| Item | Purpose | Storage |
|------|---------|---------|
| Runner registration token | Runner auth to Forgejo | 1Password |
| SSH deploy key | Runner SSH to indri | 1Password + k8s secret |

## Related Plans

- [P7_forgejo.md](../k8s-migration/P7_forgejo.md) - Original k8s migration plan (superseded for Forgejo itself, but SSH hostname split info still relevant)
- [P8_woodpecker.md](../k8s-migration/P8_woodpecker.md) - Original Woodpecker plan (superseded by Forgejo Actions)

## Decision Log

### 2026-01-23: Forgejo Actions over Woodpecker

**Decision**: Use Forgejo Actions instead of Woodpecker CI

**Rationale**:
- Native Forgejo integration (Actions is built-in)
- GitHub Actions compatible (reuse existing actions)
- `act` for local testing
- One less system to deploy and maintain

### 2026-01-23: Keep Forgejo on indri (not k8s)

**Decision**: Forgejo stays on indri as mcquack service, not migrated to k8s

**Rationale**:
- Avoid circular dependency (ArgoCD needs Forgejo to deploy Forgejo)
- Simpler SSH handling (direct port, no k8s networking complexity)
- Forgejo is critical infrastructure, benefits from isolation
- Can still use Tailscale serve for external access
