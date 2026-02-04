---
title: docs
tags:
  - service
  - documentation
---

# Docs (Quartz)

Documentation site built with [Quartz](https://quartz.jzhao.xyz/) and served via nginx.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://docs.ops.eblu.me |
| **Namespace** | `docs` |
| **Container** | `registry.ops.eblu.me/blumeops/quartz:v1.0.0` |
| **Source** | `docs/` directory in blumeops repo |
| **Build** | Forgejo workflow `build-blumeops.yaml` |

## Architecture

1. **Source**: Markdown files in `docs/` with Obsidian-compatible wiki-links
2. **Build**: Forgejo workflow builds Quartz static site on push to main
3. **Release**: Built assets published as Forgejo release attachments
4. **Deploy**: Container downloads release bundle on startup, serves via nginx

## Release Process

Documentation is automatically built and released when changes are pushed to main:

1. Workflow detects changes in `docs/` directory
2. Quartz builds static HTML/CSS/JS
3. Assets uploaded as release attachment
4. ArgoCD deployment updated with new `DOCS_RELEASE_URL`
5. Pod restarts and downloads new bundle

## Configuration

- **Quartz config**: `quartz.config.ts`
- **Layout**: `quartz.layout.ts`
- **ArgoCD app**: `argocd/apps/docs.yaml`
- **Manifests**: `argocd/manifests/docs/`

## Related

- [[argocd]] - Deployment management
- [[forgejo]] - Build workflows
