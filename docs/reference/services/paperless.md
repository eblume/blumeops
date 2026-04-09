---
title: Paperless-ngx
modified: 2026-04-08
tags:
  - service
---

# Paperless-ngx

Self-hosted document management system with OCR, tagging, and full-text search.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://paperless.ops.eblu.me |
| **Tailscale URL** | https://paperless.tail8d86e.ts.net |
| **Namespace** | `paperless` |
| **Image** | `registry.ops.eblu.me/blumeops/paperless` |
| **Manifests** | `argocd/manifests/paperless/` |
| **Container source** | `containers/paperless/Dockerfile` |
| **Upstream** | [paperless-ngx/paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) |
| **Database** | `paperless` on [[postgresql|blumeops-pg]] |
| **Storage** | NFS on [[sifaka]] at `/volume1/paperless` |
| **Auth** | [[authentik]] OIDC + local admin |

## Architecture

- **Web server**: Granian (ASGI), port 8000
- **Task queue**: Celery worker + beat (Redis sidecar)
- **OCR**: Tesseract (English)
- **Process supervisor**: s6-overlay

## Secrets

1Password item "Paperless (blumeops)" in vault `blumeops`:
- `secret-key`: Django SECRET_KEY
- `postgresql-password`: database credential
- `admin-password`: initial admin account password
- `socialaccount-providers`: OIDC provider JSON (includes Authentik client secret)

## Related

- [[adding-a-service]] — Deployment tutorial
- [[authentik]] — SSO provider
