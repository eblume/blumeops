---
title: CV
modified: 2026-04-29
last-reviewed: 2026-04-29
tags:
  - service
  - resume
---

# CV (Resume)

Personal resume/CV served as a static HTML page with PDF download, built from YAML source via Jinja2 and WeasyPrint.

## Quick Reference

| Property | Value |
|----------|-------|
| **Public URL** | `cv.eblu.me` (via [[flyio-proxy]]) |
| **Private URL** | `cv.ops.eblu.me` (Caddy on indri) |
| **Deployment** | Ansible role `cv` on indri (no daemon — Caddy serves files directly) |
| **Content dir** | `~/blumeops/cv/content/` on indri |
| **Source repo** | `forge.eblu.me/eblume/cv` (private, not mirrored to GitHub) |
| **Content packages** | `forge.eblu.me/eblume/-/packages` (generic package `cv`) |

Migrated from minikube to indri-native on 2026-04-29 (see [[cv-on-indri]]).

## Architecture

1. **Source**: `resume.yaml` (content) + `template.html` (Jinja2) + `style.css` in the cv repo
2. **Build**: `render.py` (uv script runner) generates `index.html`; WeasyPrint generates `resume.pdf`
3. **Release**: Dagger `build` function packages `index.html`, `style.css`, `resume.pdf` into a tarball, uploaded to Forgejo generic packages
4. **Deploy**: ansible role downloads the tarball into `~/blumeops/cv/content/` on indri; Caddy serves the directory directly

## Endpoints

| Path | Description |
|------|-------------|
| `/` | Resume HTML page |
| `/resume.pdf` | PDF download (Caddy adds `Content-Disposition: attachment`) |

## Configuration

**Key files (blumeops):**

- `ansible/roles/cv/defaults/main.yml` — pinned `cv_version` and tarball URL
- `ansible/roles/cv/tasks/main.yml` — sentinel-gated download + extract
- `ansible/roles/caddy/defaults/main.yml` — `cv` service entry (`kind: static`, `download_paths` for the PDF)

**Key files (cv repo):**

- `resume.yaml` — Resume content (YAML)
- `template.html` — Jinja2 HTML template
- `style.css` — CSS with screen/print media queries
- `render.py` — uv script runner (PEP 723) that renders YAML → HTML
- `src/cv_ci/main.py` — Dagger pipeline (alpine + uv + WeasyPrint)
- `.forgejo/workflows/cv-release.yaml` — Release workflow

## Release flow

1. Release a new package from the cv repo (`Release CV` workflow)
2. Run the blumeops `Deploy CV` workflow → bumps `cv_version` in the ansible role and pushes
3. Run `mise run provision-indri -- --tags cv` from gilbert
4. Purge the Fly.io proxy cache so the new content is fetched

## Related

- [[cv-on-indri]] — Operations how-to
- [[docs]] — Similar architecture (Caddy serving a tarball-extracted dir)
- [[flyio-proxy]] — Exposes `cv.eblu.me` publicly via Tailscale tunnel
