---
title: CV on Indri
modified: 2026-04-29
last-reviewed: 2026-04-29
tags:
  - how-to
  - operations
---

# CV on Indri

How the CV/resume static site (`cv.eblu.me`) is deployed on indri natively. Replaces the prior minikube Deployment; mirrors the rationale of [[devpi-on-indri]].

## Why native, not Kubernetes

CV is a tiny static site (HTML + CSS + PDF). It needs no daemon, no database, no auth. Caddy on indri can serve the extracted tarball directly via `file_server`. Removing the minikube Deployment shrinks the cluster's footprint and removes a network hop (Fly → indri Caddy → ProxyGroup ingress → minikube pod becomes Fly → indri Caddy → local files).

## Layout

| Concern | Path / detail |
|---|---|
| Content dir | `/Users/erichblume/blumeops/cv/content/` |
| Version sentinel | `/Users/erichblume/blumeops/cv/.installed-version` |
| Caddy entry | `cv` service in `ansible/roles/caddy/defaults/main.yml` (`kind: static`) |
| Public URL | `https://cv.eblu.me` (via [[flyio-proxy]]) |
| Private URL | `https://cv.ops.eblu.me` (Caddy on indri) |
| Tarball source | Forgejo generic package `cv` (`forge.eblu.me/eblume/-/packages`) |

The role is driven by `cv_version` in `ansible/roles/cv/defaults/main.yml`. The download and extract steps only fire when the on-disk sentinel doesn't match `cv_version` — i.e. after a version bump.

## Deploy

Two paths:

**From a release workflow** (most common):

1. Run the `Release CV` workflow in the cv repo → produces a new generic package
2. Run the blumeops `Deploy CV` workflow → bumps `cv_version` in `ansible/roles/cv/defaults/main.yml` and pushes to main
3. From gilbert: `mise run provision-indri -- --tags cv`
4. From gilbert: `fly ssh console -a blumeops-proxy -C "sh -c 'rm -rf /tmp/cache && nginx -s reload'"` to purge the public-edge cache

**Manual** (e.g., reverting): edit `cv_version` in the role defaults yourself, then steps 3–4.

## Verify

```fish
ssh indri 'cat ~/blumeops/cv/.installed-version'
ssh indri 'ls -la ~/blumeops/cv/content/'
curl -fsSI https://cv.ops.eblu.me/                          # private
curl -fsSI https://cv.eblu.me/                              # public
curl -fsSI https://cv.eblu.me/resume.pdf | grep -i disposition
```

The PDF response should include `content-disposition: attachment; filename="erich-blume-resume.pdf"`.

## Bumping the cv version

Edit `cv_version` in `ansible/roles/cv/defaults/main.yml` and re-run `mise run provision-indri -- --tags cv`. The role recreates the content dir from the new tarball; the sentinel update triggers the next idempotent skip.

## Backup

The content dir is **not** in `borgmatic_source_directories`. The tarball is re-downloadable from the Forgejo generic package store on every deploy, and the source is in the cv repo — recovery is just re-running the role.

## Rollback

If a bad version is published, set `cv_version` back to the previous tag in `ansible/roles/cv/defaults/main.yml` and re-run the role. The full minikube manifest set is preserved in git history (commits prior to the migration cleanup) for the worst case.

## Related

- [[devpi-on-indri]] — same shape, different upstream
- [[restart-indri]] — graceful indri restart procedure
- [[cv]] — service reference
