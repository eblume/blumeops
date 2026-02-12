---
title: Roles
modified: 2026-02-07
tags:
  - ansible
  - reference
---

# Ansible Roles

Roles for provisioning services on [[indri]]. Run via `mise run provision-indri`.

## Available Roles

| Role | Purpose | Service |
|------|---------|---------|
| **alloy** | Observability collector | [[alloy]] |
| **borgmatic** | Backup automation | [[borgmatic]] |
| **borgmatic_metrics** | Backup metrics exporter | [[borgmatic]] |
| **caddy** | Reverse proxy & TLS | [[routing]] |
| **forgejo** | Git forge | [[forgejo]] |
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

- [[indri]] - Target host
- [[observability]] - Metrics collection
