---
title: Authentik Nix Build Components
modified: 2026-03-15
last-reviewed: 2026-03-15
tags:
  - how-to
  - authentik
  - nix
---

# Authentik Nix Build Components

Detailed reference for the four Nix derivations that make up the authentik from-source build. See [[build-authentik-from-source]] for the parent overview and version update workflow.

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

Authentik 2026.2.0 requires Python 3.14 (`requires-python = "==3.14.*"`). Instead of carrying individual overrides for each broken nixpkgs python314 package, we use **`uv`** to install Python dependencies from PyPI, where upstream maintainers have already published Python 3.14-compatible wheels.

### Approach: uv sync FOD + autoPatchelfHook

Nix builds are sandboxed with no network access. The pattern is:

1. **Fixed-output derivation (FOD)** — `uv sync --frozen` fetches and installs all dependencies into a venv. FODs are allowed network access because the output hash is declared upfront. Compiled `.so` files reference Nix store paths (RPATHs to libxml2, krb5, etc.), which FODs must not contain, so we strip references with `remove-references-to` and delete `bin/` and `.pyc` files.
2. **Main derivation** — copies the FOD's `lib/python3.14/site-packages/`, recreates `bin/` with proper python symlinks, restores `pyvenv.cfg`, and runs `autoPatchelfHook` to re-link `.so` files against the correct Nix store libraries.

**Why not `uv pip download` + `uv pip install --no-index`?** `uv pip download` does not exist in uv 0.9.29 (nixpkgs). And the download-only approach has further complications with sdist-only packages (psycopg-c, gssapi) that must be compiled anyway.

**What to do:**

1. Create the FOD (`python-deps.nix`) that runs `uv sync --frozen --no-install-project --no-install-workspace --no-dev`, then strips all Nix store references from the output
2. Create the main derivation (`authentik-django.nix`) that copies the FOD's site-packages, recreates venv, runs `autoPatchelfHook`, copies in-tree workspace packages, and applies path patches
3. Verify: `$out/bin/python3.14 -c "import authentik"` succeeds

**Key details:**

- Nix provides: `python314`, `uv`, system libraries (`libxml2`, `libxslt`, `openssl`, `libffi`, `zlib`, etc.)
- PyPI provides: all Python packages (via pre-built `cp314` wheels where available, sdist builds otherwise)
- The FOD hash must be recomputed when `uv.lock` changes
- The 4 in-tree packages are installed from monorepo source, not PyPI
- Standard `djangorestframework` 3.16.1 from PyPI (no longer forked as of 2026.2.0)

### Lessons Learned

| Issue | Fix |
|-------|-----|
| `pg_config` not found for psycopg-c | Use `pkgs.postgresql.pg_config` (separate derivation), not `pkgs.postgresql` |
| gssapi `gss_acquire_cred_impersonate_name` undeclared | `NIX_CFLAGS_COMPILE="-include gssapi/gssapi_ext.h"` |
| xmlsec linker error `-lltdl` | Add `pkgs.libtool` to buildInputs (provides libltdl) |
| psycopg-c needs `libpq` | Add `pkgs.libpq` to buildInputs |
| Static `refTargets` list missed 6 store refs | Dynamic discovery: `grep -aohE '/nix/store/...'` finds all refs |
| autoPatchelfHook can't find libraries | `buildInputs` in main derivation must include all libraries that `.so` files link against |
| `FieldError: Cannot resolve keyword 'group_id'` | Django migration ordering bug — add explicit dependency via `substituteInPlace`. Upstream [#19616](https://github.com/goauthentik/authentik/issues/19616) |

The `uv sync` completes in ~3.5 minutes. Dynamic reference discovery finds 19 unique store paths. `autoPatchelfHook` in the main derivation resolves all NEEDED entries with 0 unsatisfied dependencies.

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

- [[build-authentik-from-source]] — Parent overview and version update workflow
- [[mirror-authentik-build-deps]] — Supply chain mirrors for source repos
- [[deploy-authentik]] — Deployment goal
