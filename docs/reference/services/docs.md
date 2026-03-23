---
title: Docs
modified: 2026-03-23
last-reviewed: 2026-03-23
tags:
  - service
  - documentation
---

# Docs (Quartz)

Documentation site built with [Quartz](https://quartz.jzhao.xyz/) and served via nginx.

## Quick Reference

| Property | Value |
|----------|-------|
| **Public URL** | https://docs.eblu.me |
| **Private URL** | `docs.ops.eblu.me` (tailnet only, via [[caddy]]) |
| **Namespace** | `docs` |
| **Image** | `registry.ops.eblu.me/blumeops/quartz` (see `argocd/manifests/docs/kustomization.yaml` for current tag) |
| **Source** | `docs/` directory in blumeops repo |
| **Build** | Forgejo workflow `build-blumeops.yaml` |
| **Public proxy** | [[flyio-proxy]] (Fly.io → Tailscale tunnel) |

## Architecture

1. **Source**: Markdown files in `docs/` with Obsidian-compatible wiki-links
2. **Build**: Forgejo workflow builds Quartz static site on push to main
3. **Release**: Built assets published as Forgejo release attachments
4. **Deploy**: Container downloads release bundle on startup, serves via nginx

## Release Process

Documentation is built and released via the `build-blumeops` Forgejo workflow (manual dispatch):

1. Quartz builds static HTML/CSS/JS
2. Assets uploaded as Forgejo release attachment
3. Workflow updates `DOCS_RELEASE_URL` in `argocd/manifests/docs/deployment.yaml` and commits to main
4. ArgoCD syncs the updated deployment; new pod downloads the release bundle at startup

## Configuration

- **Quartz config**: `quartz.config.ts`
- **Layout**: `quartz.layout.ts`
- **ArgoCD app**: `argocd/apps/docs.yaml`
- **Manifests**: `argocd/manifests/docs/`

## Related

- [[argocd]] - Deployment management
- [[forgejo]] - Build workflows
