---
title: CV on Indri
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - how-to
  - operations
---

# CV on Indri

How the CV/resume static site (`cv.eblu.me` via the [[flyio-proxy]] edge, `cv.ops.eblu.me` direct) is hosted on indri. Content is host-resident: Caddy serves the content dir directly, and there is no role and no daemon. Same shape as [[devpi-on-indri]] on the ops side, with the install itself manual rather than ansible-driven.

## Layout

| Concern | Path / detail |
|---|---|
| Content dir | `/Users/erichblume/blumeops/cv/content/` |
| Version sentinel | `/Users/erichblume/blumeops/cv/.installed-version` |
| Caddy entry | `cv` service in `ansible/roles/caddy/defaults/main.yml` (`kind: static`) |
| Public URL | `https://cv.eblu.me` (via [[flyio-proxy]]) |
| Private URL | `https://cv.ops.eblu.me` (Caddy on indri) |
| OCI artifact | `registry.ops.eblu.me/blumeops/cv:<caddy_cv_version>`, pushed by the horkos release publisher |

The version is pinned by `caddy_cv_version` in `ansible/roles/caddy/defaults/main.yml` — there is no role, so the pin lives with the Caddy service that serves the content.

## Install / bump (manual, on indri)

Run on indri (`ssh indri`); the block is idempotent and sentinel-gated — it skips when the installed version already matches the pin:

```bash
set -euo pipefail
version="v1.0.6"                      # caddy_cv_version in ansible/roles/caddy/defaults/main.yml
home=/Users/erichblume/blumeops/cv
[ "$(cat $home/.installed-version 2>/dev/null || true)" = "$version" ] && echo current || {
  rm -rf $home/content && mkdir -p $home/content
  digest=$(curl -fsSL -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    "https://registry.ops.eblu.me/v2/blumeops/cv/manifests/$version" | jq -r '.layers[0].digest')
  curl -fsSL "https://registry.ops.eblu.me/v2/blumeops/cv/blobs/$digest" -o $home/cv.tar.gz
  tar -xzf $home/cv.tar.gz -C $home/content
  rm -f $home/cv.tar.gz
  printf '%s\n' "$version" > $home/.installed-version
}
```

This is the role's former download recipe; the sentinel was previously written by ansible, now by this script. `registry.ops.eblu.me` is tailnet-only (run from indri or a tailnet host), which is why the install is manual.

## Release flow

1. The cv repo release publishes the asset.
2. The horkos publisher pushes the zot OCI artifact and opens the pin PR — it bumps `caddy_cv_version` in `ansible/roles/caddy/defaults/main.yml` per `argocd/manifests/horkos/release-targets.json`.
3. After the pin PR merges, run the install block above on indri (the pin PR's thread carries that as a Human steps item).
4. Purge the fly edge cache from gilbert: `fly ssh console -a blumeops-proxy -C "sh -c 'rm -rf /tmp/cache && nginx -s reload'"`.

## Verify

```fish
ssh indri 'cat ~/blumeops/cv/.installed-version'
ssh indri 'ls -la ~/blumeops/cv/content/'
curl -fsSI https://cv.ops.eblu.me/                          # private
curl -fsSI https://cv.eblu.me/                              # public
curl -fsSI https://cv.eblu.me/resume.pdf | grep -i disposition
```

The PDF response should include `content-disposition: attachment; filename="erich-blume-resume.pdf"`.

## Rollback

Install the previous version with the block above, pinning the old version, then run the same edge purge.

## Backup

The content dir is **not** in `borgmatic_source_directories`. Recovery is re-running the install block — the artifact stays in zot, so nothing else is needed.

## Related

- [[devpi-on-indri]] — same shape, different upstream
- [[restart-indri]] — graceful indri restart procedure
- [[cv]] — service reference
- The cv ansible role is retired (V5-83, eblume/blumeops#1760).
