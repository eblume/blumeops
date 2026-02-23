---
title: How-To
modified: 2026-02-22
tags:
  - how-to
---

# How-To Guides

Task-oriented instructions for common BlumeOps operations. These guides assume you already understand the basic concepts - see [[tutorials|Tutorials]] if you're learning.

## Deployment

| Guide | Description |
|-------|-------------|
| [[deploy-k8s-service]] | Deploy a new service to Kubernetes via ArgoCD |
| [[add-ansible-role]] | Add a new Ansible role for indri services |
| [[create-release-artifact-workflow]] | Build artifacts and publish to Forgejo packages |
| [[build-container-image]] | Build and release a custom container image via Dagger |

## Configuration

| Guide | Description |
|-------|-------------|
| [[update-tailscale-acls]] | Update Tailscale access control policies |
| [[gandi-operations]] | Manage DNS records and cycle the Gandi API token |
| [[use-pypi-proxy]] | Configure pip and publish packages to devpi |
| [[expose-service-publicly]] | Expose a service to the public internet via Fly.io + Tailscale |
| [[update-documentation]] | Publish docs via build-blumeops workflow |

## Knowledge Base

| Guide | Description |
|-------|-------------|
| [[review-documentation]] | Periodically review and maintain documentation |
| [[review-services]] | Periodically review services for version freshness |
| [[agent-change-process]] | C0/C1/C2 change classification and Mikado method for agents |

## Operations

| Guide | Description |
|-------|-------------|
| [[connect-to-postgres]] | Connect to PostgreSQL as a superuser via psql |
| [[restart-indri]] | Safely shut down and restart indri |
| [[manage-flyio-proxy]] | Deploy, shutoff, and troubleshoot the public proxy |
| [[restore-1password-backup]] | Recover 1Password credentials from borgmatic backup |
| [[troubleshooting]] | Diagnose and fix common issues |

## Plans

Migration and transition plans for upcoming infrastructure changes.

| Plan | Description |
|------|-------------|
| [[plans]] | Index of all plans |
| [[completed]] | Completed plans archive |
| [[migrate-forgejo-from-brew]] | Transition Forgejo from Homebrew to source-built binary |
| [[add-unifi-pulumi-stack]] | Add Pulumi IaC for UniFi Express 7 (abandoned) |
| [[segment-home-network]] | Manual three-network segmentation for UniFi Express 7 |
| [[adopt-dagger-ci]] | Adopt Dagger as CI/CD build engine |
| [[upstream-fork-strategy]] | Stacked-branch forking strategy for upstream projects |
| [[adopt-oidc-provider]] | Deploy OIDC identity provider for SSO across services |
| [[upgrade-grafana-helm-chart]] | Upgrade Grafana Helm chart from 8.8.2 to 11.x |
| [[operationalize-reolink-camera]] | Cloud-free NVR with Frigate and ring buffer recording |

## Ringtail

| Guide | Description |
|-------|-------------|
| [[manage-lockfile]] | Update or lock NixOS flake inputs via Dagger |

## Zot

Mikado chain for hardening the zot registry. Track progress with `mise run docs-mikado harden-zot-registry`.

- [[harden-zot-registry]]
- [[register-zot-oidc-client]]
- [[wire-ci-registry-auth]]
- [[enforce-tag-immutability]]
- [[adopt-commit-based-container-tags]]
- [[add-container-version-sync-check]]
- [[install-dagger-on-nix-runner]]
- [[pin-container-versions]]
- [[add-dagger-nix-build]]
- [[fix-ntfy-nix-version]]

## Authentik

Mikado chain for deploying Authentik. Track progress with `mise run docs-mikado deploy-authentik`.

- [[deploy-authentik]]
- [[build-authentik-container]]
- [[provision-authentik-database]]
- [[create-authentik-secrets]]
- [[migrate-grafana-to-authentik]]

## Forgejo Runner

Mikado chain for upgrading the k8s forgejo-runner daemon from v6.3.1 to v12.x. Track progress with `mise run docs-mikado upgrade-k8s-runner`.

- [[upgrade-k8s-runner]]
- [[validate-workflows-against-v12]]
- [[review-runner-config-v12]]
