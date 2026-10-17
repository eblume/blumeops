---
title: Docs
modified: 2026-10-17
last-reviewed: 2026-10-17
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
| **Deployment** | Ansible role `docs` on indri (no daemon — Caddy serves files directly) |
| **Content dir** | `~/blumeops/docs/content/` on indri |
| **Source** | `docs/` directory in blumeops repo |
| **Build** | Forgejo workflow `release.yaml` (on the release PR's merge) |

Migrated from minikube to indri-native on 2026-04-29 (see [[docs-on-indri]]).

## Architecture

1. **Source**: Markdown files in `docs/` with Obsidian-compatible wiki-links
2. **Build**: the `release.yaml` workflow builds Quartz on the release PR's merge and publishes the tarball as a release asset; the `docs_version` bump rides the release PR itself ([[update-documentation]])
3. **Deploy**: ansible role downloads the tarball into `~/blumeops/docs/content/` on indri; Caddy serves the directory directly with Quartz-style `try_files` (path → path/ → path.html → 404.html)

## Configuration

- **Quartz config**: `quartz.config.yaml` (v5 — single file for config, plugins, and layout)
- **Ansible role**: `ansible/roles/docs/`
- **Caddy entry**: `ansible/roles/caddy/defaults/main.yml` (`kind: static`, `try_html: true`)

## Release flow

1. Cut a release PR ([[update-documentation]]) — merging it builds the docs tarball and creates the Forgejo release; the release PR itself bumps `docs_version`
2. Run `mise run provision-indri -- --tags docs` from gilbert
3. Purge the Fly.io proxy cache so the new content is fetched

## Related

- [[docs-on-indri]] — Operations how-to
- [[cv]] — Similar architecture
- [[forgejo]] — Build workflows
