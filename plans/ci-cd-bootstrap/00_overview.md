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
│  │   (host mode)       │     │    (via ArgoCD)     │           │
│  │                     │     │                     │           │
│  │  - Custom image     │     │                     │           │
│  │  - Node.js + tools  │     │                     │           │
│  │  - Docker builds    │     │                     │           │
│  └─────────────────────┘     └─────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Phases

| Phase | Name | Description | Status |
|-------|------|-------------|--------|
| 1 | [Enable Actions](P1_enable_actions.md) | Configure Forgejo for Actions, deploy runner in host mode | ✅ Complete |
| 2 | [Custom Runner Image](P2_mirror_and_build.md) | Build custom runner with Node.js/tools, enable standard Actions | ✅ Complete |
| 3 | [Mirror Forgejo & Build](P3_mirror_forgejo.md) | Mirror upstream Forgejo, create build workflow | Planning |
| 4 | [Self-Deploy](P4_self_deploy.md) | Forgejo deploys itself, transition to mcquack | Planning |
| 5 | [Container Builds](P5_container_builds.md) | Build custom container images (devpi, etc.) | Planning |

## The Bootstrap Problem

**Chicken-and-egg**: We need Forgejo Actions to build Forgejo, but Forgejo must be running first.

**Additional complication**: The stock runner image lacks Node.js, so standard GitHub Actions don't work.

**Solution**:
1. Keep current brew-based Forgejo running during setup ✅
2. Enable Actions, deploy runner in host mode ✅
3. **Build custom runner image** with Node.js and tools (bootstrap manually, then automate)
4. Mirror upstream Forgejo, create build workflow
5. Address cross-compilation challenge (Linux runner → macOS target)
6. First CI build creates the binary
7. CI deploys binary to indri as mcquack service
8. `brew services stop forgejo` and uninstall
9. Future builds: Forgejo builds and deploys itself

**Cross-compilation challenge**:
The runner runs in Linux containers (k8s), but Forgejo needs to run on indri (macOS ARM64). Options:
- Cross-compile with CGO_ENABLED=1 (complex, needs OSX toolchain)
- Cross-compile with CGO_ENABLED=0 (breaks Tailscale DNS resolution)
- Build on gilbert manually, use CI only for deploy
- Run a native macOS runner on indri (outside k8s)

This will be addressed in Phase 3.

**Risk mitigation**: If self-deployment breaks Forgejo:
- blumeops is mirrored to GitHub
- Manual recovery: build on gilbert, scp to indri, restart service
- See Disaster Recovery section in P4

## Host Mode Runner

The runner uses **host mode** (`ubuntu-latest:host`), meaning:
- Jobs run directly in the runner container (no Docker/k8s pods spawned)
- Tools must be pre-installed in the runner image
- Stock image lacks Node.js, so `actions/checkout@v4` doesn't work
- Solution: Build custom runner image with necessary tools (Phase 2)

## Ansible Role Strategy

The forgejo ansible role will follow the zot/alloy pattern:

1. **Check binary exists** at expected path
2. **If missing**: Fail with message pointing to CI trigger instructions
3. **If present**: Deploy config, ensure LaunchAgent loaded

Ansible does NOT:
- Build the binary (that's CI's job)
- Deploy new versions (that's CI's job)

Ansible DOES:
- Manage app.ini configuration (via template with secrets from 1Password)
- Manage mcquack LaunchAgent plist
- Ensure service is running
- Collect logs via Alloy

## Files Summary

### New Files

| Path | Purpose |
|------|---------|
| `argocd/apps/forgejo-runner.yaml` | ArgoCD Application for runner ✅ |
| `argocd/manifests/forgejo-runner/` | Runner k8s manifests ✅ |
| `argocd/manifests/forgejo-runner/Dockerfile` | Custom runner image (P2) |
| `.forgejo/workflows/build-runner.yml` | Auto-rebuild runner image (P2) |
| `.forgejo/workflows/test.yml` | Test workflow ✅ |
| (on forge) `eblume/forgejo/.forgejo/workflows/` | Build workflow in forgejo mirror (P3) |

### Modified Files

| Path | Change |
|------|--------|
| `ansible/roles/forgejo/` | Complete rewrite for mcquack pattern (P4) |
| `ansible/roles/alloy/defaults/main.yml` | Update forgejo log paths (P4) |
| zk cards | Update forgejo, argocd, blumeops cards |

### Credentials Needed

| Item | Purpose | Storage |
|------|---------|---------|
| Runner registration token | Runner auth to Forgejo | 1Password ✅ |
| SSH deploy key | Runner SSH to indri (for Forgejo deploy) | 1Password + k8s secret (P3) |

## Related Plans

- [P7_forgejo.md](../k8s-migration/P7_forgejo.md) - Original k8s migration plan (superseded for Forgejo itself, but SSH hostname split info still relevant)
- [P8_woodpecker.md](../k8s-migration/P8_woodpecker.md) - Original Woodpecker plan (superseded by Forgejo Actions)

## Decision Log

### 2026-01-23: Custom runner image as Phase 2

**Decision**: Move custom runner image work from P4 to P2

**Rationale**:
- Stock runner lacks Node.js, can't run `actions/checkout@v4`
- Need working GitHub Actions before building Forgejo
- Bootstrap manually (podman build on gilbert), then automate

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
