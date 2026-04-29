---
title: Docs on Indri
modified: 2026-04-29
last-reviewed: 2026-04-29
tags:
  - how-to
  - operations
---

# Docs on Indri

How the Quartz documentation site (`docs.eblu.me`) is deployed on indri natively. Replaces the prior minikube Deployment; same shape as [[cv-on-indri]] with one extra wrinkle for Quartz's clean URLs.

## Why native, not Kubernetes

The docs site is fully static HTML produced by Quartz. Caddy can serve the extracted tarball directly. The Quartz-specific behavior the previous nginx container provided (`try_files $uri $uri/ $uri.html =404` and a custom `/404.html`) maps cleanly to Caddy's `try_files` and `handle_errors`.

## Layout

| Concern | Path / detail |
|---|---|
| Content dir | `/Users/erichblume/blumeops/docs/content/` |
| Version sentinel | `/Users/erichblume/blumeops/docs/.installed-version` |
| Caddy entry | `docs` service in `ansible/roles/caddy/defaults/main.yml` (`kind: static`, `try_html: true`) |
| Public URL | `https://docs.eblu.me` (via [[flyio-proxy]]) |
| Private URL | `https://docs.ops.eblu.me` (Caddy on indri) |
| Tarball source | Forgejo release asset on the blumeops repo (`docs-<version>.tar.gz`) |

`docs_version` in `ansible/roles/docs/defaults/main.yml` is the blumeops release tag (e.g. `v1.16.0`). The role's download/extract is gated by an on-disk sentinel.

## Deploy

1. Run the `Build BlumeOps` Forgejo workflow → builds the tarball, creates a release, bumps `docs_version` in the ansible role, pushes to main
2. From gilbert: `mise run provision-indri -- --tags docs`
3. From gilbert: `fly ssh console -a blumeops-proxy -C "sh -c 'rm -rf /tmp/cache && nginx -s reload'"`

The Caddy block uses `try_files {path} {path}/ {path}.html` and a `handle_errors 404 → /404.html` rewrite, matching the original nginx behavior so Quartz's clean URLs continue to work.

## Verify

```fish
ssh indri 'cat ~/blumeops/docs/.installed-version'
ssh indri 'ls ~/blumeops/docs/content/'
curl -fsSI https://docs.ops.eblu.me/                                # private
curl -fsSI https://docs.eblu.me/                                    # public
curl -fsSI https://docs.eblu.me/explanation/agent-change-process    # clean URL → .html fallback
curl -fsSI https://docs.eblu.me/no-such-path-exists/                # → /404.html
```

## Bumping the docs version

Normally driven by the workflow. If you need to pin manually, edit `docs_version` in `ansible/roles/docs/defaults/main.yml` and re-run `mise run provision-indri -- --tags docs`.

## Backup

Content dir is not borgmatic-backed. Source is in this repo; release tarballs are on the forge.

## Rollback

Set `docs_version` back to the previous release tag in the role defaults and re-run. Older release tarballs remain available as Forgejo release assets.

## Related

- [[cv-on-indri]] — sibling service, simpler (no `try_html`)
- [[devpi-on-indri]] — pattern reference for indri-native services
- [[docs]] — service reference
