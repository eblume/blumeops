---
title: Mise Tasks
modified: 2026-02-24
tags:
  - reference
  - tools
  - mise
---

# Mise Tasks

Operational tasks for BlumeOps, run via `mise run <task>`. Tasks live in `mise-tasks/` and use `#USAGE` directives for argument parsing.

Run `mise tasks --sort name` for the live list with descriptions.

## AI & Documentation

| Task | Description |
|------|-------------|
| `ai-docs` | Prime AI context with key documentation |
| `docs-check-filenames` | Detect duplicate filenames in documentation |
| `docs-check-frontmatter` | Check required frontmatter fields |
| `docs-check-index` | Check every doc is referenced in its category index |
| `docs-check-links` | Validate wiki-links point to existing filenames |
| `docs-mikado` | View active Mikado dependency chains (C2 changes) |
| `docs-review` | Review the most stale doc by `last-reviewed` date |
| `docs-review-stale` | Report docs by last-modified date |
| `docs-review-tags` | Print frontmatter tag inventory |

## Deployment & Provisioning

| Task | Description |
|------|-------------|
| `provision-indri` | Run Ansible playbook for [[indri]] |
| `provision-ringtail` | Run Ansible playbook for [[ringtail]] (NixOS) |
| `provision-sifaka` | Run Ansible playbook for [[sifaka]] |
| `fly-deploy` | Deploy Fly.io public proxy |
| `fly-setup` | One-time Fly.io secrets and certs setup |
| `fly-shutoff` | Emergency shutoff: stop all Fly.io proxy machines |
| `dns-preview` | Preview DNS changes with [[pulumi]] |
| `dns-up` | Apply DNS changes with [[pulumi]] |
| `tailnet-preview` | Preview Tailscale ACL changes with [[pulumi]] |
| `tailnet-up` | Apply Tailscale ACL changes with [[pulumi]] |

## Containers & Registry

| Task | Description |
|------|-------------|
| `container-list` | List containers and their recent tags |
| `container-build-and-release` | Trigger container build workflows via Forgejo API |
| `container-version-check` | Validate version consistency across Dockerfiles, nix, and manifests |
| `mirror-create` | Create an upstream mirror in the `mirrors/` Forgejo org |

## Git & Forge

| Task | Description |
|------|-------------|
| `branch-cleanup` | Delete merged branches (local and remote) |
| `pr-comments` | List unresolved PR comments |
| `runner-logs` | View Forgejo Actions workflow logs |
| `validate-workflows` | Validate workflow files against runner schema |
| `mikado-branch-invariant-check` | Validate Mikado Branch Invariant on `mikado/*` branches |

## Operations & Monitoring

| Task | Description |
|------|-------------|
| `services-check` | Check all services are online and responding |
| `service-review` | Review the most stale service for version freshness |
| `blumeops-tasks` | List tasks from Todoist sorted by priority |
| `op-backup` | Encrypt 1Password export and send to indri for borgmatic |

## Infrastructure Setup

| Task | Description |
|------|-------------|
| `ensure-minikube-indri-kubectl-config` | Set up kubectl config for minikube-indri |
| `ensure-k3s-ringtail-kubectl-config` | Set up kubectl config for k3s-ringtail |

## ML & Hardware

| Task | Description |
|------|-------------|
| `frigate-export-model` | Export YOLOv9 model weights to ONNX via [[dagger]] |

## Related

- [[dagger]] — CI/CD build engine (containers, docs)
- [[ansible]] — Configuration management
- [[argocd-cli]] — ArgoCD deployment workflows
- [[pulumi]] — DNS and Tailscale IaC
