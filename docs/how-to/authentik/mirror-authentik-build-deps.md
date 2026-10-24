---
title: Mirror Authentik Build Dependencies
modified: 2026-10-23
last-reviewed: 2026-10-23
tags:
  - how-to
  - authentik
---

# Mirror Authentik Build Dependencies

Mirror the external repositories needed to build authentik from source onto the forge, ensuring full supply chain control.

## Context

Building authentik from source fetches two GitHub repos — `goauthentik/authentik` and `goauthentik/client-go` — from forge mirrors via `pkgs.fetchgit` with SRI hashes (URLs centralized in `containers/authentik/sources.nix`), for supply chain control. The main repo was already mirrored; one companion repo needed mirroring:

- **`goauthentik/client-go`** — Go API client bindings, versioned in lockstep with authentik (e.g. `v3.2026.2.0` matches `version/2026.2.0`). Used by the Go server build.

Previously, `goauthentik/django-rest-framework` (authentik's DRF fork) was also required. Since authentik [PR 16594](https://github.com/goauthentik/authentik/pull/16594) (2025-10-21) it is dropped in favor of standard `djangorestframework` 3.16.1 from PyPI, so no forge mirror of the fork was ever created (verified 2026-09-29 — no such repo in the `mirrors/` org; the upstream fork itself is now archived).

## What to Do

1. Mirror `goauthentik/client-go`:
   ```fish
   mise run mirror-create https://github.com/goauthentik/client-go.git \
     --name authentik-client-go \
     --description "Go API client for authentik (lockstep versioned)"
   ```
   New mirrors land in the `mirrors/` Forgejo org.
2. Verify the mirror syncs: check tags appear on forge (e.g. `mirrors/authentik-client-go` carries the `v3.2026.x.y` tags)

Done as of 2026-09-29: the mirror is live and `containers/authentik/sources.nix` fetches `client-go-src` from it (currently pinned to `v3.2026.2.1`).

## The uv2nix toolchain trio (2026-10-23)

The uv2nix rebuild of `python-deps` (blumeops#1813) adds three eval-time `import (fetchgit …)` pins, currently pointing at github.com. They are the official `pyproject-nix/*` repos and are hash-pinned (integrity is fine), but they are not on the forge yet:

| repo | rev |
|------|-----|
| `pyproject-nix/pyproject.nix` | `ddc400a6883b042646d0940e65971bb7f7e96107` |
| `pyproject-nix/uv2nix` | `7aba73a3d85454f1118f8cf9de97979b4d26bcac` |
| `pyproject-nix/build-system-pkgs` | `a17819c85163988e063806ffc4f6d2716bc8ead8` |

To move them to the forge:

1. Mirror all three:
   ```fish
   mise run mirror-create https://github.com/pyproject-nix/pyproject.nix.git --name pyproject.nix
   mise run mirror-create https://github.com/pyproject-nix/uv2nix.git --name uv2nix
   mise run mirror-create https://github.com/pyproject-nix/build-system-pkgs.git --name build-system-pkgs
   ```
2. Repoint the three `fetchgit` URLs in `containers/authentik/python-deps.nix` at `forge.ops.eblu.me/mirrors/…` (ideally centralized in `sources.nix`) in a blumeops PR.

These are not flake inputs — `flake.lock` is not involved. The rev/hash pins are plain expressions and get bumped by hand on upgrade.

**`opencontainers`** (the `vsoch/oci-python` git dependency) is different: its source URL comes from the `uv.lock` entry, and uv2nix fetches it with `fetchGit` at the locked rev. Mirroring it would need a URL override of the lock entry, and it was GitHub-sourced before the uv2nix migration too — not a regression.

As of 2026-10-24 (eblume/blumeops#1867) the consumer landed — the trio is no longer imported at eval time; the pins are plain data in `python-deps.nix`, read only by `mise run generate-authentik-venv-lock` (pure eval, forge-mirror fetches), which keeps the vendored `make-venv.py` byte-exact with the pinned pyproject-nix. The forge-mirror URLs remain the authoritative upstream for generation.

## Related

- [[authentik]] — Authentik reference
- [[authentik-nix-build-components]] — Consumes client-go mirror
- [[manage-forgejo-mirrors]] — Mirror creation, PAT rotation
