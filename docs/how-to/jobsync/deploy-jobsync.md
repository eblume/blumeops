---
title: Deploy JobSync
modified: 2026-03-13
last-reviewed: 2026-03-13
tags:
  - how-to
  - jobsync
---

# Deploy JobSync

[JobSync](https://github.com/Gsync/jobsync) is a self-hosted job application tracker (Next.js + Prisma/SQLite) running on ringtail's k3s cluster via ArgoCD.

- **URL:** `https://jobsync.ops.eblu.me`
- **Auth:** Local accounts (email/password), no SSO
- **Storage:** 5Gi PVC at `/data` (SQLite DB + resume uploads)
- **AI:** Ollama at `ollama.ollama.svc.cluster.local:11434`

## Manifests

All in `argocd/manifests/jobsync/`:

| File | Purpose |
|------|---------|
| `deployment.yaml` | Single-replica deployment |
| `service.yaml` | ClusterIP on port 3000 |
| `ingress-tailscale.yaml` | Tailscale Ingress (ProxyGroup) |
| `pvc.yaml` | 5Gi local-path for `/data` |
| `external-secret.yaml` | `auth_secret` + `encryption_key` from 1Password |
| `kustomization.yaml` | Image tag override |

## Environment Variables

| Variable | Source | Purpose |
|----------|--------|---------|
| `DATABASE_URL` | Hardcoded | `file:/data/dev.db` |
| `AUTH_SECRET` | ExternalSecret | NextAuth session signing |
| `ENCRYPTION_KEY` | ExternalSecret | AES-256-GCM for stored API keys |
| `NEXTAUTH_URL` | Hardcoded | `https://jobsync.ops.eblu.me` |
| `AUTH_TRUST_HOST` | Hardcoded | `true` |
| `NEXT_TELEMETRY_DISABLED` | Hardcoded | `1` (opt out of Next.js telemetry) |
| `TZ` | Hardcoded | `America/Los_Angeles` |
| `OLLAMA_BASE_URL` | Hardcoded | `http://ollama.ollama.svc.cluster.local:11434` |
| `RAPIDAPI_KEY` | ExternalSecret | JSearch job search API key |

## Updating the Container

1. Build and push: `mise run container-release jobsync <version>`
2. Update `newTag` in `kustomization.yaml` to the full tag (e.g. `v1.1.4-3a811fb-nix`)
3. Sync: `argocd app sync jobsync`

See [[build-jobsync-container]] for nix build details.

## Notes

- **1Password item:** "JobSync" in blumeops vault, fields `auth_secret`, `encryption_key`, and `rapidapi_key`
- **Caddy route:** `jobsync.ops.eblu.me` → `https://jobsync.tail8d86e.ts.net` (in `ansible/roles/caddy/defaults/main.yml`)
- **`service-versions.yaml`:** Must have a `jobsync` entry or the pre-commit hook rejects container changes

## Observability

JobSync has no metrics endpoint. Logs are collected by Alloy on ringtail and shipped to Loki. Query in Grafana:

```logql
{namespace="jobsync", app="jobsync"}
```

The app runs a scheduled job search daily at 4 AM. Search failures appear in logs during those executions.

## Related

- [[jobsync]] — Service reference card
- [[build-jobsync-container]]
- [[deploy-k8s-service]]
