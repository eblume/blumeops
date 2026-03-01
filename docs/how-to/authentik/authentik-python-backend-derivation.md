---
title: Build Authentik Python Backend
modified: 2026-03-01
requires:
  - mirror-authentik-build-deps
tags:
  - how-to
  - authentik
  - nix
---

# Build Authentik Python Backend

Build `authentik-django` — the Python/Django application that forms the core backend of authentik.

## Context

Authentik 2026.2.0 requires Python 3.14 (`requires-python = "==3.14.*"`). The nixpkgs reference derivation (2025.12.4) builds all 60+ Python deps through nix's `python3.override` with `packageOverrides`. This approach breaks on Python 3.14 because many nixpkgs python314 packages haven't been updated — astor, dacite, exceptiongroup, and pydantic-core all fail to build.

Instead of carrying individual overrides for each broken package, we use **`uv`** to install Python dependencies from PyPI, where upstream maintainers have already published Python 3.14-compatible wheels. Nix provides only the Python interpreter and system libraries.

## Approach: uv sync FOD + autoPatchelfHook

Nix builds are sandboxed with no network access. The pattern is:

1. **Fixed-output derivation (FOD)** — `uv sync --frozen` fetches and installs all dependencies into a venv. FODs are allowed network access because the output hash is declared upfront. Compiled `.so` files reference Nix store paths (RPATHs to libxml2, krb5, etc.), which FODs must not contain, so we strip references with `remove-references-to` and delete `bin/` and `.pyc` files.
2. **Main derivation** — copies the FOD's `lib/python3.14/site-packages/`, recreates `bin/` with proper python symlinks, restores `pyvenv.cfg`, and runs `autoPatchelfHook` to re-link `.so` files against the correct Nix store libraries.

**Why not `uv pip download` + `uv pip install --no-index`?** `uv pip download` does not exist in uv 0.9.29 (nixpkgs). And the download-only approach has further complications with sdist-only packages (psycopg-c, gssapi) that must be compiled anyway.

## What to Do

1. Create the FOD (`python-deps.nix`) that runs `uv sync --frozen --no-install-project --no-install-workspace --no-dev`, then strips all Nix store references from the output
2. Create the main derivation (`authentik-django.nix`) that:
   - Copies the FOD's site-packages
   - Recreates venv `bin/` and `pyvenv.cfg`
   - Runs `autoPatchelfHook` to restore `.so` RPATHs
   - Copies 4 in-tree workspace packages directly into site-packages
   - Copies `authentik/` and `lifecycle/` into site-packages
   - Copies `opencontainers` from `fetchFromGitHub` into site-packages
3. Apply `substituteInPlace` patches for Nix store paths in `settings.py`, `default.yml`, `email/utils.py`
4. Copy lifecycle scripts, `manage.py`, blueprints into the output
5. Verify: `$out/bin/python3.14 -c "import authentik"` succeeds

## Key Details

- Nix provides: `python314`, `uv`, system libraries (`libxml2`, `libxslt`, `openssl`, `libffi`, `zlib`, etc.)
- PyPI provides: all Python packages (via pre-built `cp314` wheels where available, sdist builds otherwise)
- The FOD hash must be recomputed when `uv.lock` changes
- `manylinux` wheels bundle some `.so` files — acceptable for a container image
- The 4 in-tree packages are installed from monorepo source, not PyPI
- Standard `djangorestframework` 3.16.1 from PyPI (no longer forked as of 2026.2.0)

## Lessons Learned

Build issues encountered and resolved:

| Issue | Fix |
|-------|-----|
| `pg_config` not found for psycopg-c | Use `pkgs.postgresql.pg_config` (separate derivation), not `pkgs.postgresql` |
| gssapi `gss_acquire_cred_impersonate_name` undeclared | `NIX_CFLAGS_COMPILE="-include gssapi/gssapi_ext.h"` — function is in `gssapi_ext.h`, not auto-included |
| xmlsec linker error `-lltdl` | Add `pkgs.libtool` to buildInputs (provides libltdl) |
| psycopg-c needs `libpq` | Add `pkgs.libpq` to buildInputs |
| Static `refTargets` list missed 6 store refs | Replaced with dynamic discovery: `grep -aohE '/nix/store/...'` finds all refs, `remove-references-to` strips them |
| `xargs grep` exit code 123 under `pipefail` | Wrap pipeline in `{ ... \|\| true; }` — grep returning 1 (no match) causes xargs to return 123 |
| `grep -aoE` includes filename prefix in output | Use `grep -aohE` (`-h` suppresses filenames) to get clean store paths |
| autoPatchelfHook can't find libraries | `buildInputs` in main derivation must include all libraries that `.so` files link against |

The `uv sync` completes in ~3.5 minutes. Dynamic reference discovery finds 19 unique store paths and strips all of them. After stripping, `remove-references-to` mangles hashes to `eeee...` bytes — about 40 files still "contain" `/nix/store/` strings but with invalid hashes, which is expected and harmless. `autoPatchelfHook` in the main derivation resolves all NEEDED entries with 0 unsatisfied dependencies.

Build verified: `$out/bin/python3.14 -c "import authentik"` succeeds, along with all key dependencies (django 5.2.11, lxml, xmlsec, psycopg, guardian, opencontainers).

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-go-server-derivation]] — Depends on this for lifecycle scripts and web assets
