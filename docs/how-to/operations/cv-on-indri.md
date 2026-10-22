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

Run from a tailnet host (e.g. gilbert). Indri's login shell is fish, so the block is a non-interactive bash run — paste the whole thing:

```bash
ssh indri bash -s <<'EOF'
set -euo pipefail
# version to install: $1 when provided (rollback), else the caddy_cv_version pin
# on blumeops main, fetched from forge (a local blumeops checkout on indri lags
# main after a pin merge), so this doc's block needs no per-release edit.
version=${1:-$(curl -fsSL "https://forge.ops.eblu.me/eblume/blumeops/raw/branch/main/ansible/roles/caddy/defaults/main.yml" \
  | sed -n 's/^caddy_cv_version: "\(.*\)"$/\1/p')}
[ -n "$version" ] || { echo "cv version not determined: no argument and caddy_cv_version pin not found on blumeops main" >&2; exit 1; }
home=/Users/erichblume/blumeops/cv
[ "$(cat $home/.installed-version 2>/dev/null || true)" = "$version" ] && echo current || {
  # stage + swap: a failed download/extract never wipes the live content, and
  # the sentinel is written last, so a bad run cannot strand it pointing at a wiped tree
  mkdir -p "$home"
  tmp=$(mktemp -d "$home/.staging.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT
  digest=$(curl -fsSL -H "Accept: application/vnd.oci.image.manifest.v1+json" \
    "https://registry.ops.eblu.me/v2/blumeops/cv/manifests/$version" | jq -r '.layers[0].digest')
  curl -fsSL "https://registry.ops.eblu.me/v2/blumeops/cv/blobs/$digest" -o "$tmp/a.tar.gz"
  mkdir "$tmp/content" && tar -xzf "$tmp/a.tar.gz" -C "$tmp/content"
  rm -rf "$home/content.old"
  if [ -d "$home/content" ]; then mv "$home/content" "$home/content.old"; fi
  mv "$tmp/content" "$home/content" && rm -rf "$home/content.old"
  printf '%s\n' "$version" > $home/.installed-version
}
EOF
```

The version comes from the argument when one is given (rollback) and otherwise from the pin on main, so the block stays current across releases — no per-release edit of this doc. The rest is the role's former download recipe; the sentinel was previously written by ansible, now by this script. `registry.ops.eblu.me` is tailnet-only, which is why the install is manual.

## Release flow

1. The cv repo release publishes the asset.
2. The horkos publisher pushes the zot OCI artifact and opens the pin PR — it bumps `caddy_cv_version` in `ansible/roles/caddy/defaults/main.yml` per `argocd/manifests/horkos/release-targets.json`.
3. After the pin PR merges (and the zot artifact for the pinned version exists — the install block's download fails closed if it does not), run the install block above from a tailnet host, then step 4. The pin PR's deploy line is horkos-generated from the release target's `deploy_note` and points at this doc's manual install procedure.
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

Run the install block with the previous pin passed to `bash -s` — `ssh indri bash -s v1.0.5 <<'EOF'` instead of `ssh indri bash -s <<'EOF'`, the same block — then run the same edge purge.

## Backup

The content dir is **not** in `borgmatic_source_directories`. Recovery is re-running the install block — the artifact stays in zot, so nothing else is needed.

## Related

- [[devpi-on-indri]] — same shape, different upstream
- [[restart-indri]] — graceful indri restart procedure
- [[cv]] — service reference
- The cv ansible role is retired (V5-83, eblume/blumeops#1760).
