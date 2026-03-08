---
title: JobSync
modified: 2026-03-08
tags:
  - service
  - job-search
---

# JobSync

Self-hosted job application tracker. Tracks job applications, automates job searching via the JSearch API, and provides AI-powered resume tailoring via [[ollama|Ollama]].

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://jobsync.ops.eblu.me |
| **Tailscale URL** | https://jobsync.tail8d86e.ts.net |
| **Namespace** | `jobsync` |
| **Cluster** | ringtail k3s |
| **Image** | `blumeops/jobsync` (Nix-built) |
| **Upstream** | https://github.com/Gsync/jobsync |
| **Manifests** | `argocd/manifests/jobsync/` |
| **Port** | 3000 |

## Architecture

```
Browser ──HTTPS──► Caddy (jobsync.ops.eblu.me)
                      │
                      ▼
               Tailscale ProxyGroup
                      │
                      ▼
              JobSync (Next.js)
              ┌───────┴───────┐
              │               │
         SQLite (/data)    Ollama (in-cluster)
              │               │
         PVC 5Gi         GPU-accelerated LLM
```

- **Framework:** Next.js 15 + Prisma ORM
- **Database:** SQLite on a 5Gi PVC at `/data`
- **Auth:** Local email/password accounts (NextAuth v5), no SSO
- **AI:** Ollama at `http://ollama.ollama.svc.cluster.local:11434` for resume tailoring
- **Job Search:** JSearch API via RapidAPI (requires `RAPIDAPI_KEY`)

## Job Search (JSearch / RapidAPI)

The automated job search feature uses the [JSearch API](https://rapidapi.com/letscrape-6bRBa3QguO5/api/jsearch) on RapidAPI. The API key can be configured two ways (checked in order):

1. **Per-user:** Added via Settings > API Keys in the web UI (encrypted with `ENCRYPTION_KEY`)
2. **Environment variable:** `RAPIDAPI_KEY` env var as a fallback for all users

Without either, job search automations fail with: `Search failed: network - RAPIDAPI_KEY is not configured`

The free tier allows 200 requests/month. The key is stored in 1Password ("JobSync" item, `rapidapi_key` field) and synced via ExternalSecret.

## Secrets

All secrets are in the **JobSync** 1Password item (blumeops vault), synced by ExternalSecret:

| Secret | 1Password Field | Purpose |
|--------|-----------------|---------|
| `auth_secret` | `auth_secret` | NextAuth session signing |
| `encryption_key` | `encryption_key` | AES-256-GCM for stored API keys |
| `rapidapi_key` | `rapidapi_key` | JSearch job search API |

## Observability

JobSync has no metrics endpoint or Grafana dashboard. Logs are collected by [[alloy|Alloy]] on ringtail and shipped to Loki on indri.

**Querying logs in Grafana:**

```logql
{namespace="jobsync", app="jobsync"}
```

To search for job search errors specifically:

```logql
{namespace="jobsync", app="jobsync"} |~ "(?i)(rapid|search failed|error)"
```

The app runs a scheduled job search daily at 4 AM. Failures appear in logs during those executions.

## Container

Built with Nix on ringtail (x86_64). See [[build-jobsync-container]] for details.

```fish
mise run container-release jobsync <version>
```

Update `newTag` in `argocd/manifests/jobsync/kustomization.yaml` after building, then `argocd app sync jobsync`.

## Related

- [[ollama]] — AI backend for resume tailoring
- [[ringtail]] — Host node
- [[deploy-jobsync]] — Deployment how-to
- [[build-jobsync-container]] — Container build guide
- [[apps]] — ArgoCD application registry
