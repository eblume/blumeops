---
title: CV
modified: 2026-03-27
last-reviewed: 2026-03-27
tags:
  - service
  - resume
---

# CV (Resume)

Personal resume/CV served as a static HTML page with PDF download, built from YAML source via Jinja2 and WeasyPrint.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | `cv.eblu.me` (public, via [[flyio-proxy]]) |
| **Namespace** | `cv` |
| **Container** | `registry.ops.eblu.me/blumeops/cv` ([kustomization](https://forge.eblu.me/eblume/blumeops/src/branch/main/argocd/manifests/cv/kustomization.yaml)) |
| **Source repo** | `forge.eblu.me/eblume/cv` (private, not mirrored to GitHub) |
| **Content packages** | `forge.eblu.me/eblume/-/packages` (generic package `cv`) |
| **ArgoCD App** | `cv` |

## Architecture

1. **Source**: `resume.yaml` (content) + `template.html` (Jinja2) + `style.css` in the cv repo
2. **Build**: `render.py` (uv script runner) generates `index.html`; WeasyPrint generates `resume.pdf`
3. **Release**: Dagger `build` function packages `index.html`, `style.css`, `resume.pdf` into a tarball, uploaded to Forgejo generic packages
4. **Deploy**: nginx container downloads the tarball at startup via `CV_RELEASE_URL` env var

## Endpoints

| Path | Description |
|------|-------------|
| `/` | Resume HTML page |
| `/resume.pdf` | PDF download (Content-Disposition: attachment) |
| `/healthz` | Health check (200 OK) |

## Configuration

**Key files (blumeops):**

- `containers/cv/Dockerfile` — nginx:alpine container
- `containers/cv/start.sh` — tarball download + extraction
- `containers/cv/default.conf` — nginx config (gzip, caching, PDF headers)
- `argocd/manifests/cv/deployment.yaml` — `CV_RELEASE_URL` env var
- `argocd/apps/cv.yaml` — ArgoCD Application

**Key files (cv repo):**

- `resume.yaml` — Resume content (YAML)
- `template.html` — Jinja2 HTML template
- `style.css` — CSS with screen/print media queries
- `render.py` — uv script runner (PEP 723) that renders YAML → HTML
- `src/cv_ci/main.py` — Dagger pipeline (alpine + uv + WeasyPrint)
- `.forgejo/workflows/cv-release.yaml` — Release workflow

## Secrets

| Secret | Repo | Source | Description |
|--------|------|--------|-------------|
| `FORGE_TOKEN` | cv | 1Password (via Ansible) | Forgejo API token for package uploads |

Provisioned via `forgejo_actions_secrets` Ansible role. See [[create-release-artifact-workflow]].

## Related

- [[docs]] — Similar architecture (nginx container + content tarball)
- [[flyio-proxy]] — Exposes `cv.eblu.me` publicly via Tailscale tunnel
- [[create-release-artifact-workflow]] — How to set up release artifact workflows
- [[deploy-k8s-service]] — General k8s deployment guide
