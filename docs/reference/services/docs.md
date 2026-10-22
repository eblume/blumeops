---
title: Docs
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - service
  - documentation
---

# Docs (Quartz)

Documentation site built with [Quartz](https://quartz.jzhao.xyz/).

## Quick Reference

| Property | Value |
|----------|-------|
| **Public URL** | https://docs.eblu.me (via [[flyio-proxy]]) |
| **Private URL** | `docs.ops.eblu.me` (Caddy on indri) |
| **Deployment** | Manual on-host install into `~/blumeops/docs/content/` on indri (no daemon — Caddy serves files directly) |
| **Content dir** | `~/blumeops/docs/content/` on indri |
| **Source** | `docs/` directory in blumeops repo |
| **Build** | Forgejo workflow `release.yaml` (on the release PR's merge) |

Migrated from minikube to indri-native on 2026-04-29 (see [[docs-on-indri]]).

## Architecture

1. **Source**: Markdown files in `docs/` with Obsidian-compatible wiki-links
2. **Build**: the `release.yaml` workflow builds Quartz on the release PR's merge and publishes the tarball as a release asset; the `caddy_docs_version` pin bump rides the release PR itself ([[update-documentation]])
3. **Deploy**: manual install (see [[docs-on-indri]]) downloads the pinned Forgejo release tarball into `~/blumeops/docs/content/` on indri; Caddy serves the directory directly with Quartz-style `try_files` (path → path/ → path.html → 404.html)

## Configuration

- **Quartz config**: `quartz.config.yaml` (v5 — single file for config, plugins, and layout)
- **Caddy entry**: `ansible/roles/caddy/defaults/main.yml` — pinned `caddy_docs_version` and `caddy_docs_content_dir`, plus the `docs` service entry (`kind: static`, `try_html: true`)
- `docs/how-to/operations/docs-on-indri.md` — sentinel-gated manual install (curl the pinned Forgejo release tarball into the content dir, write the sentinel)

## Release flow

1. Cut a release PR ([[update-documentation]]) — merging it builds the docs tarball and creates the Forgejo release; the release PR itself bumps the `caddy_docs_version` pin
2. Run the manual install block in [[docs-on-indri]] on indri (from a tailnet host)
3. Purge the Fly.io proxy cache so the new content is fetched

## Related

- [[docs-on-indri]] — Operations how-to
- [[cv]] — Similar architecture
- [[forgejo]] — Build workflows
