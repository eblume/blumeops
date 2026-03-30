---
title: Ansible
modified: 2026-03-30
last-reviewed: 2026-03-30
tags:
  - ansible
  - reference
---

# Ansible

Host-level configuration management — the layer between cloud infrastructure ([[pulumi]]) and containerized workloads ([[argocd]]). The primary playbook is `ansible/playbooks/indri.yml` (targets [[indri]]); separate playbooks exist for [[ringtail]] and [[sifaka]].

## CLI Patterns

```bash
# Full provisioning
mise run provision-indri

# Specific role only
mise run provision-indri -- --tags caddy

# Dry run (preview changes)
mise run provision-indri -- --check --diff
```

Other hosts have their own playbooks:

```bash
# Ringtail (NixOS, k3s)
mise run provision-ringtail

# Sifaka (Synology NAS exporters)
mise run provision-sifaka
```

## Available Roles

| Role | Purpose | Service |
|------|---------|---------|
| **alloy** | Observability collector | [[alloy]] |
| **borgmatic** | Backup automation | [[borgmatic]] |
| **borgmatic_metrics** | Backup metrics exporter | [[borgmatic]] |
| **caddy** | Reverse proxy & TLS | [[routing]] |
| **forgejo** | Git forge | [[forgejo]] |
| **forgejo_actions_secrets** | CI/CD secrets for Forgejo Actions | [[forgejo]] |
| **forgejo_metrics** | Forge metrics exporter | [[forgejo]] |
| **jellyfin** | Media server | [[jellyfin]] |
| **jellyfin_metrics** | Media metrics exporter | [[jellyfin]] |
| **minikube** | Kubernetes cluster | [[cluster]] |
| **minikube_metrics** | Cluster metrics | [[cluster]] |
| **zot** | Container registry | [[zot]] |
| **zot_metrics** | Registry metrics | [[zot]] |

## Role Structure

Each role follows Ansible conventions:
```
ansible/roles/<role>/
├── defaults/main.yml    # Default variables
├── tasks/main.yml       # Task definitions
├── handlers/main.yml    # Handlers (restarts, etc.)
├── templates/           # Jinja2 templates
└── files/               # Static files
```

## Secrets

Roles that need secrets use 1Password via the playbook's `pre_tasks`. Secrets are gathered at playbook start and passed to roles as variables.

## Related

- [[indri]] — Primary managed host
- [[ringtail]] — NixOS host managed by its own playbook
- [[sifaka]] — Synology NAS managed by its own playbook
- [[observability]] — Metrics collection
