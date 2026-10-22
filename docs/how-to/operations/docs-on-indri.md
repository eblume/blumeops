---
title: Docs on Indri
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - how-to
  - operations
---

# Docs on Indri

How the Quartz documentation site (`docs.eblu.me`) is hosted on indri natively. Content is host-resident: Caddy serves the content dir directly, and there is no role and no daemon — the install is a documented manual procedure (same shape as [[cv-on-indri]]). The Quartz-specific behavior the previous nginx container provided (`try_files $uri $uri/ $uri.html =404` and a custom `/404.html`) is preserved by the Caddy block's `try_files {path} {path}/ {path}.html` plus a `handle_errors 404 → /404.html` rewrite, so clean URLs keep working.

## Layout

| Concern | Path / detail |
|---|---|
| Content dir | `/Users/erichblume/blumeops/docs/content/` |
| Version sentinel | `/Users/erichblume/blumeops/docs/.installed-version` |
| Caddy entry | `docs` service in `ansible/roles/caddy/defaults/main.yml` (`kind: static`, `try_html: true`) |
| Public URL | `https://docs.eblu.me` (via [[flyio-proxy]]) |
| Private URL | `https://docs.ops.eblu.me` (Caddy on indri) |
| Tarball source | Forgejo release asset on the blumeops repo (`docs-<version>.tar.gz`) |

The version is pinned by `caddy_docs_version` in `ansible/roles/caddy/defaults/main.yml` — there is no role, so the pin lives with the Caddy service that serves the content. The `cut-release` repo hook (`.forgejo/scripts/cut-release`) bumps this pin on every blumeops release PR, so the pin on main is always the last released docs version — the pin and the tarball land in the same release PR.

## Install / bump (manual, on indri)

Run from a tailnet host (e.g. gilbert). Indri's login shell is fish, so the block is a non-interactive bash run — paste the whole thing:

```bash
ssh indri bash -s <<'EOF'
set -euo pipefail
# version to install: $1 when provided (rollback), else the caddy_docs_version pin
# on blumeops main, fetched from forge (a local blumeops checkout on indri lags
# main after a pin merge), so this doc's block needs no per-release edit.
version=${1:-$(curl -fsSL "https://forge.ops.eblu.me/eblume/blumeops/raw/branch/main/ansible/roles/caddy/defaults/main.yml" \
  | sed -n 's/^caddy_docs_version: "\(.*\)"$/\1/p')}
[ -n "$version" ] || { echo "docs version not determined: no argument and caddy_docs_version pin not found on blumeops main" >&2; exit 1; }
home=/Users/erichblume/blumeops/docs
[ "$(cat $home/.installed-version 2>/dev/null || true)" = "$version" ] && echo current || {
  rm -rf $home/content && mkdir -p $home/content
  curl -fsSL "https://forge.ops.eblu.me/eblume/blumeops/releases/download/$version/docs-$version.tar.gz" -o $home/docs.tar.gz
  tar -xzf $home/docs.tar.gz -C $home/content
  rm -f $home/docs.tar.gz
  printf '%s\n' "$version" > $home/.installed-version
}
EOF
```

The version comes from the argument when one is given (rollback) and otherwise from the pin on main, so the block stays current across releases — no per-release edit of this doc. The rest is the role's former download recipe (the deleted `ansible/roles/docs` tasks did exactly this: curl the release tarball, extract into the content dir, write the sentinel); the sentinel was previously written by ansible, now by this script.

## Release flow

1. Cut a release PR ([[update-documentation]]) — the kit's `cut-release` repo hook bumps `caddy_docs_version` in the caddy role defaults, so the pin rides the release PR.
2. Merging it is the release: `release.yaml` builds the docs tarball and publishes the Forgejo release (`docs-<version>.tar.gz` as the asset).
3. Run the install block above from a tailnet host.
4. Purge the fly edge cache from gilbert: `fly ssh console -a blumeops-proxy -C "sh -c 'rm -rf /tmp/cache && nginx -s reload'"`.

## Verify

```fish
ssh indri 'cat ~/blumeops/docs/.installed-version'
ssh indri 'ls ~/blumeops/docs/content/'
curl -fsSI https://docs.ops.eblu.me/                                # private
curl -fsSI https://docs.eblu.me/                                    # public
curl -fsSI https://docs.eblu.me/explanation/agent-change-process    # clean URL → .html fallback
curl -fsSI https://docs.eblu.me/no-such-path-exists/                # → /404.html
```

## Rollback

Run the install block with the previous version passed to `bash -s` — `ssh indri bash -s v1.20.1 <<'EOF'` instead of `ssh indri bash -s <<'EOF'`, the same block — then run the same edge purge.

## Backup

The content dir is not in `borgmatic_source_directories`. Recovery is re-running the install block — the tarball stays on the forge as a release asset, so nothing else is needed.

## Related

- [[cv-on-indri]] — sibling service, same shape (its artifact is a zot OCI layer; docs' is a Forgejo release asset)
- [[devpi-on-indri]] — pattern reference for indri-native services
- [[docs]] — service reference
- The docs ansible role is retired (V5-83, eblume/blumeops#1760).
