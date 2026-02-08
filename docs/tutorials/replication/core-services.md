---
title: Core Services
tags:
  - tutorials
  - replication
  - forgejo
---

# Core Services Setup

> **Audiences:** Replicator
>
> **Prerequisites:** [[tailscale-setup|Tailscale Setup]]

This tutorial walks through setting up the foundational services that your GitOps infrastructure depends on: a git forge and optionally a container registry.

## Why Core Services First?

Before Kubernetes and ArgoCD, you need somewhere to store your infrastructure definitions. [[forgejo]] provides:
- Git hosting for your GitOps repository
- CI/CD workflows for building and deploying
- A web interface for code review and PRs

The [[zot]] container registry is optional but useful for hosting your own container images.

## Step 1: Install Forgejo

Forgejo runs directly on your server (not in Kubernetes) because Kubernetes depends on it.

### Using Ansible (BlumeOps Approach)

BlumeOps manages Forgejo via an Ansible role. See [[roles|Ansible Roles]].

### Manual Installation

1. Download Forgejo from [forgejo.org](https://forgejo.org/download/)
2. Create a service user and directories
3. Configure with `app.ini`
4. Set up as a system service

Key configuration points:
- SSH on a non-standard port (e.g., 2222) to avoid conflicts
- Database (SQLite works fine for personal use)
- Domain and URL settings for your Tailscale hostname

## Step 2: Configure SSH Access

Set up SSH for git operations:

```bash
# Add your SSH key to Forgejo via the web UI
# Then test access:
ssh -T git@your-server.tailnet.ts.net -p 2222
```

## Step 3: Create Your GitOps Repository

1. Create a new repository in Forgejo (e.g., `infrastructure` or `homelab`)
2. Initialize the standard directory structure:

```
your-repo/
├── ansible/           # Host configuration
│   ├── playbooks/
│   └── roles/
├── argocd/            # Kubernetes GitOps
│   ├── apps/          # ArgoCD Applications
│   └── manifests/     # K8s manifests per service
├── pulumi/            # IaC for Tailscale, DNS
└── docs/              # Documentation
```

3. Push your initial commit

## Step 4: Set Up CI/CD Runner (Optional)

Forgejo Actions runs workflows defined in `.forgejo/workflows/`. To use it:

1. Register a runner on your server
2. Configure runner to access your build tools
3. Create workflow files for builds and deployments

BlumeOps runs a Forgejo runner in Kubernetes - see [[forgejo]] for details.

## Step 5: Container Registry (Optional)

If you'll build custom container images, set up [[zot]]:

1. Install Zot on your server
2. Configure authentication
3. Set up TLS (via Caddy or similar)

For getting started, you can skip this and use public registries.

## What You Now Have

- Git hosting for infrastructure code
- SSH access for git operations
- Foundation for CI/CD workflows
- Optionally, a private container registry

## Next Steps

- [[kubernetes-bootstrap|Bootstrap Kubernetes]] - Now that you have a git repo, set up your cluster
- Configure Forgejo webhooks for ArgoCD (after ArgoCD is running)

## BlumeOps Specifics

BlumeOps' Forgejo setup includes:
- Ansible role for installation and updates
- SSH on port 2222, proxied via Caddy
- Integration with ArgoCD via deploy keys
- Forgejo runner in Kubernetes for CI/CD

See [[forgejo]] and [[zot]] for full details.
