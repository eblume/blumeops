---
title: Paperless-ngx
modified: 2026-06-12
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
| **Manifests** | `argocd/manifests/paperless-ringtail/` |
| **Container source** | `containers/paperless/default.nix` (Nix image) |
| **Upstream** | [paperless-ngx/paperless-ngx](https://github.com/paperless-ngx/paperless-ngx) |
| **Database** | `paperless` on [[postgresql|blumeops-pg]] |
| **Storage** | NFS on [[sifaka]] at `/volume1/paperless` |
| **Auth** | [[authentik]] OIDC + local admin |

## Architecture

- **Web server**: Granian (ASGI), port 8000
- **Task queue**: Celery worker + beat (Redis sidecar)
- **OCR**: Tesseract (English)
- **Process model**: no supervisor — one pod, four app containers (web,
  worker, beat, consumer) sharing the Nix image with different commands,
  plus a redis native sidecar and a migrate initContainer

**Scratch dir must be shared.** API uploads are written by the *web*
container into `PAPERLESS_SCRATCH_DIR` and read back by the *worker*'s
`consume_file` task — in the upstream single-container image that's free,
but in this multi-container pod it requires a shared emptyDir. The worker
also never creates the dir (only web does), so `PAPERLESS_SCRATCH_DIR`
points at the mount root, which always exists. The Nix image additionally
ships no `/tmp`, which made Python's `tempfile.gettempdir()` fall back to
the cwd (`/`) — a `/tmp` emptyDir is mounted to keep general temp usage
(celery multiprocessing, etc.) off the container overlay.

## Secrets

1Password item "Paperless (blumeops)" in vault `blumeops`:
- `secret-key`: Django SECRET_KEY
- `postgresql-password`: database credential
- `admin-password`: initial admin account password
- `socialaccount-providers`: OIDC provider JSON (includes Authentik client secret)

## Related

- [[adding-a-service]] — Deployment tutorial
- [[authentik]] — SSO provider
