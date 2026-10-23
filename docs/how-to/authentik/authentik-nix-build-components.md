---
title: Authentik Nix Build Components
modified: 2026-10-23
last-reviewed: 2026-10-01
tags:
  - how-to
  - authentik
  - nix
---

# Authentik Nix Build Components

Detailed reference for the Nix derivations that make up the custom authentik from-source build, which replaces the `pkgs.authentik` nixpkgs dependency so releases can be targeted directly instead of waiting on the nixpkgs cycle. `containers/authentik/default.nix` assembles the image from the components below plus an `ak` wrapper script (sets `PATH`/`VIRTUAL_ENV`, delegates to upstream `lifecycle/ak`, which dispatches `server` to the Go binary and everything else to Python/Django).

## API Client Generation

Go and TypeScript API client bindings generated from authentik's OpenAPI spec (`schema.yml`).

Authentik maintains a separate repo ([`goauthentik/client-go`](https://github.com/goauthentik/client-go)) with pre-generated Go client code. The nixpkgs derivation fetches this and injects it into the Go vendor directory via a setup hook (`apiGoVendorHook`). The TypeScript client is generated inline from `schema.yml` using `openapi-generator-cli`.

**What to do:**

1. Create a Nix derivation (`client-go`) that generates Go API client bindings from `schema.yml` using `openapi-generator-cli`
2. Create a Nix derivation (`client-ts`) that generates TypeScript fetch client bindings from the same spec
3. Create a setup hook (`apiGoVendorHook`) that replaces `goauthentik.io/api/v3` in the vendor directory with the generated client
4. Verify the generated code compiles (Go: `go build`, TypeScript: type-check with `tsc`)

**Key details:**

- Source spec: `schema.yml` in the authentik repo root
- Go client replaces `vendor/goauthentik.io/api/v3/` in the server build (via `api-go-vendor-hook.nix`)
- TypeScript client replaces `web/node_modules/@goauthentik/api/` in the web UI build (symlinked in `webui.nix`)

## Python Backend

`authentik-django` — the Python/Django application that forms the core backend.

Authentik 2026.2.0 requires Python 3.14 (`requires-python = "==3.14.*"`). Instead of carrying individual overrides for each broken nixpkgs python314 package, dependencies are installed from PyPI, where upstream maintainers have already published Python 3.14-compatible wheels.

### Approach: uv2nix venv + autoPatchelfHook

`python-deps.nix` builds the dependency venv **without a FOD** (see [[aspects]] — `fod-only-downloads`; nothing fetched may execute while it has network on the build host): **uv2nix** (pyproject.nix ecosystem) parses `uv.lock` and the workspace `pyproject.tomls` in pure Nix at eval time, and every artifact becomes a hashed `fetchurl` (wheel) or a hashed sdist fetched and built as an ordinary sandboxed PEP 517 derivation (`uv build --no-build-isolation`). There are no generated Nix files to check in and no hash to recompute when `uv.lock` changes — the lock's hashes are the pins.

1. **`python-deps.nix`** — loads the uv2nix workspace from the authentik source pin, resolves the root project's dependency closure, and `mkVirtualEnv`s it. The venv excludes the local workspace projects, so it contains exactly the third-party closure `uv sync --no-install-project --no-install-workspace` used to install.
2. **`authentik-django.nix`** — copies the venv and repoints its interpreter and the console-script shebangs: the make-venv hook ships `bin/python*` as a compiled shim (and the scripts' shebangs) that identify the venv's *own* store path, so a plain copy would resolve `sys.prefix` to `python-deps` at runtime and drop the workspace packages off `sys.path` (crashloop, not build failure). It then copies in-tree workspace packages, runs `autoPatchelfHook` to fix the RPATHs of the compiled sdist extensions, and carries a `doInstallCheck` that asserts the interpreter resolves to the final package with the workspace packages importable, so a layout regression fails the build.

**Why not `uv sync` in a FOD?** The FOD pattern (retired here) ran `uv sync --frozen` with network, then needed `remove-references-to`, `bin/`/`.pyc` deletion, DWARF stripping, and RECORD rewrites to keep the output deterministic and self-contained. uv2nix removes the whole class of problem: plain sandboxed derivations, lock-hashed fetches.

**What to do:**

1. `python-deps.nix`: pin `pyproject.nix` / `uv2nix` / `build-system-pkgs` via `pkgs.fetchgit`, `loadWorkspace` from the source pin, resolve the root project's closure, exclude the local workspace projects, `overrideScope` with the build-systems overlay + per-sdist C-library fixups, `mkVirtualEnv`
2. `authentik-django.nix`: copy the venv, repoint the venv's interpreter and console-script shebangs to the final package, copy in-tree workspace packages, apply path patches, `autoPatchelfHook`, `doInstallCheck`
3. Verify: the `doInstallCheck` runs from `/` and requires `sys.prefix == $out` with all four workspace packages importable; a manual `$out/bin/python3.14 -c "import authentik"` succeeds too

**Key details:**

- Nix provides: `python314`, `uv`, system libraries (`libxml2`, `libxslt`, `openssl`, `libffi`, `zlib`, etc.)
- PyPI provides: all Python packages (via pre-built `cp314` wheels where available, sdist builds otherwise)
- The nixpkgs `python314` interpreter ships no setuptools, so every setuptools-backend sdist gets the `setuptools` (and, for gssapi, `Cython`) build-system package from the build-systems overlay — under `uv build --no-build-isolation` there is no implicit isolation env
- The `[tool.uv] no-binary-package` entries (`lxml`, `xmlsec`) are honored — they build from sdist against the system `libxml2`/`xmlsec`
- The 4 in-tree packages (`ak-guardian`, `django-channels-postgres`, `django-dramatiq-postgres`, `django-postgres-cache`) and the root `authentik` package are installed from monorepo source by `authentik-django.nix`, not via the venv
- The one exception to PyPI-sourced deps is `opencontainers` — an upstream `uv` git dependency; uv2nix fetches it with `fetchGit` at the locked rev and builds its wheel sandboxed (see [[mirror-authentik-build-deps]])
- Standard `djangorestframework` 3.16.1 from PyPI (no longer forked as of 2026.2.0)

### Lessons Learned

| Issue | Fix |
|-------|-----|
| `pg_config` not found for psycopg-c | Use `pkgs.postgresql.pg_config` (separate derivation), not `pkgs.postgresql` |
| gssapi `gss_acquire_cred_impersonate_name` undeclared | `NIX_CFLAGS_COMPILE="-include gssapi/gssapi_ext.h"` |
| gssapi `No module named 'Cython'` under `--no-build-isolation` | Add the `Cython` build-system package to nativeBuildInputs (uv's isolated builds used to pull it in implicitly) |
| xmlsec linker error `-lltdl` | Add `pkgs.libtool` to buildInputs (provides libltdl) |
| psycopg-c needs `libpq` | Add `pkgs.libpq` to buildInputs |
| autoPatchelfHook can't find libraries | `buildInputs` in main derivation must include all libraries that `.so` files link against |
| `FieldError: Cannot resolve keyword 'group_id'` | Django migration ordering bug — add explicit dependency via `substituteInPlace`. Upstream [#19616](https://github.com/goauthentik/authentik/issues/19616) |

(Pre-uv2nix history: the FOD pattern needed dynamic store-reference discovery, DWARF stripping, and RECORD rewrites for determinism; `autoPatchelfHook` in the main derivation has always resolved all NEEDED entries.)

## Web UI

Lit-based TypeScript web frontend built with esbuild + rollup.

As of 2026.2.0, the main build uses **esbuild** (via wireit) and the SFE sub-package uses **rollup**. Two-phase Nix build:

1. **`webui-deps.nix`** — Fixed-output derivation that runs `npm ci` to fetch Node dependencies. Platform-specific output hash.
2. **`webui.nix`** — Copies deps, patches in the generated TypeScript API client (`client-ts`), patches shebangs, runs `npm run build` (wireit/esbuild) and `npm run build:sfe` (rollup).

**Key details:**

- **Node.js:** `nodejs_24` (authentik requires Node >= 24, npm >= 11.6.2)
- **Build time:** ~33s on ringtail (x86_64-linux)
- **FOD hash:** Platform-specific — updates needed on each version bump
- **Output:** `$out/dist/` (JS/CSS bundles) and `$out/authentik/` (static icons)
- **Docusaurus website** (`/help` endpoint) is not built — optional

**Key lessons:**

- The 2026.2.0 build switched from rollup to esbuild for the main frontend
- The version string in `packages/core/version/node.js` uses a JSON import-with-assertion that must be patched to hardcode the version
- `NODE_OPTIONS=--openssl-legacy-provider` is needed for compatibility
- Workspace packages have separate `node_modules/` — the FOD must collect all of them

## Go Server

The Go HTTP server binary (`cmd/server`) that serves the web UI, REST API, and spawns gunicorn for the Django backend.

**What to do:**

1. Create a `buildGoModule` derivation for `cmd/server` from the authentik source
2. Inject the generated Go API client into the vendor directory (via `apiGoVendorHook`)
3. Apply `substituteInPlace` patches to hardcode Nix store paths for lifecycle scripts and web assets
4. Compute the `vendorHash` — the hook replaces vendored API code *after* hash verification
5. Rename the output binary from `server` to `authentik`

**Key details:**

- Go module: `goauthentik.io`, subpackage: `./cmd/server`
- CGO: disabled
- The `vendorHash` must be computed with the vendor replacement hook excluded (`overrideModAttrs`)
- Outpost binaries (`cmd/ldap`, `cmd/proxy`, `cmd/radius`) are separate and not needed for basic deployment

## Updating to a New Version

1. Update `version` in `sources.nix` and `default.nix`
2. Update the `src` and `client-go-src` hashes in `sources.nix` (`nix-prefetch-git` on ringtail)
3. `python-deps` needs no hash update — uv2nix reads the artifact hashes from the new `uv.lock`
4. Recompute the `webui-deps.nix` FOD hash — changes when `package-lock.json` or platform-specific npm binaries change
5. Recompute `vendorHash` in `authentik-server.nix` if Go dependencies changed
6. Test on ringtail (below)
7. Build and push the container via CI ([[build-container-image]])

## Testing on Ringtail

The `test-build.nix` harness in `containers/authentik/` supports individual component builds:

```fish
set tmpdir (ssh ringtail 'mktemp -d /tmp/authentik-test.XXXXXX')
scp containers/authentik/*.nix ringtail:$tmpdir/
ssh ringtail "cd $tmpdir && nix-build test-build.nix -A client-go --extra-experimental-features 'nix-command flakes'"
ssh ringtail "cd $tmpdir && nix-build test-build.nix -A assembled --extra-experimental-features 'nix-command flakes'"
ssh ringtail "rm -rf $tmpdir"
```

## Related

- [[build-container-image]] — Container build and release pipeline
- [[mirror-authentik-build-deps]] — Supply chain mirrors for source repos
- [[authentik]] — Authentik reference
