---
title: CV
modified: 2026-10-21
last-reviewed: 2026-10-21
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
| **Deployment** | Manual on-host install into `~/blumeops/cv/content/` on indri (no daemon — Caddy serves files directly) |
| **Content dir** | `~/blumeops/cv/content/` on indri |
| **Source repo** | `forge.eblu.me/eblume/cv` (private, not mirrored to GitHub) |
| **Content packages** | zot OCI artifact `registry.ops.eblu.me/blumeops/cv:<caddy_cv_version>` (pushed by the horkos release publisher) |

Migrated from minikube to indri-native on 2026-04-29 (see [[cv-on-indri]]).

## Architecture

1. **Source**: `resume.yaml` (content) + `template.html` (Jinja2) + `style.css` in the cv repo
2. **Build**: `render.py` (uv script runner) generates `index.html`; WeasyPrint generates `resume.pdf`
3. **Release**: Dagger `build` function packages `index.html`, `style.css`, `resume.pdf` into a tarball, uploaded to Forgejo generic packages
4. **Deploy**: manual install (see [[cv-on-indri]]) pulls the pinned zot OCI layer into `~/blumeops/cv/content/` on indri; Caddy serves the directory directly

## Endpoints

| Path | Description |
|------|-------------|
| `/` | Resume HTML page |
| `/resume.pdf` | PDF download (Caddy adds `Content-Disposition: attachment`) |

## Configuration

**Key files (blumeops):**

- `ansible/roles/caddy/defaults/main.yml` — pinned `caddy_cv_version` and `caddy_cv_content_dir`, plus the `cv` service entry (`kind: static`, `download_paths` for the PDF)
- `docs/how-to/operations/cv-on-indri.md` — sentinel-gated manual install (curl the pinned zot OCI layer into the content dir, write the sentinel)

**Key files (cv repo):**

- `resume.yaml` — Resume content (YAML)
- `template.html` — Jinja2 HTML template
- `style.css` — CSS with screen/print media queries
- `render.py` — uv script runner (PEP 723) that renders YAML → HTML
- `src/cv_ci/main.py` — Dagger pipeline (alpine + uv + WeasyPrint)
- `.forgejo/workflows/cv-release.yaml` — Release workflow

## Release flow

1. Run the `Release CV` workflow in the cv repo → produces a new release asset
2. The pin is the horkos publisher's PR — merging it bumps `caddy_cv_version` in `ansible/roles/caddy/defaults/main.yml` (see the horkos#17 release flow); then run the manual install block in [[cv-on-indri]] on indri
3. Purge the Fly.io proxy cache so the new content is fetched

## Related

- [[cv-on-indri]] — Operations how-to
- [[docs]] — Similar architecture (Caddy serving a tarball-extracted dir)
- [[flyio-proxy]] — Exposes `cv.eblu.me` publicly via Tailscale tunnel
