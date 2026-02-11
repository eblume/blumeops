---
title: How-To
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

## Configuration

| Guide | Description |
|-------|-------------|
| [[update-tailscale-acls]] | Update Tailscale access control policies |
| [[gandi-operations]] | Manage DNS records and cycle the Gandi API token |
| [[use-pypi-proxy]] | Configure pip and publish packages to devpi |
| [[expose-service-publicly]] | Expose a service to the public internet via Fly.io + Tailscale |

## Documentation

| Guide | Description |
|-------|-------------|
| [[update-documentation]] | Publish docs via build-blumeops workflow |

## Knowledge Base

| Guide | Description |
|-------|-------------|
| [[review-documentation]] | Periodically review and maintain documentation |

## Operations

| Guide | Description |
|-------|-------------|
| [[restart-indri]] | Safely shut down and restart indri |
| [[manage-flyio-proxy]] | Deploy, shutoff, and troubleshoot the public proxy |
| [[restore-1password-backup]] | Recover 1Password credentials from borgmatic backup |
| [[troubleshooting]] | Diagnose and fix common issues |

## Plans

Migration and transition plans for upcoming infrastructure changes.

| Plan | Description |
|------|-------------|
| [[plans]] | Index of all plans |
| [[migrate-forgejo-from-brew]] | Transition Forgejo from Homebrew to source-built binary |
| [[add-unifi-pulumi-stack]] | Add Pulumi IaC for UniFi Express 7 |
| [[adopt-dagger-ci]] | Adopt Dagger as CI/CD build engine |
| [[upstream-fork-strategy]] | Stacked-branch forking strategy for upstream projects |
