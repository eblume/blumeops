---
title: Build Authentik from Source
modified: 2026-03-01
requires:
  - authentik-go-server-derivation
  - authentik-web-ui-derivation
  - authentik-python-backend-derivation
tags:
  - how-to
  - authentik
  - nix
---

# Build Authentik from Source

Custom Nix derivation that builds authentik from source, replacing the `pkgs.authentik` nixpkgs dependency. This gives full version control independent of the nixpkgs release cycle.

## Motivation

The nix-container-builder runner on ringtail resolves `nixpkgs` via the NixOS nix registry, which pins to `nixos-25.11`. That channel lags behind upstream authentik releases. Building from source lets us target any release by updating `sources.nix`.

## Architecture

Authentik has four build components assembled by `containers/authentik/default.nix`:

1. **API client generation** (`client-go.nix`, `client-ts.nix`) — Go and TypeScript bindings generated from `schema.yml` (OpenAPI)
2. **Python backend** (`authentik-django.nix`) — Django application with 60+ Python dependencies installed via `uv` from PyPI (see [[authentik-python-backend-derivation]])
3. **Web UI** (`webui.nix`) — Lit-based TypeScript frontend built with esbuild + rollup
4. **Go server** (`authentik-server.nix`) — HTTP server binary that serves the web UI and spawns gunicorn for Django

The `ak` wrapper script in `default.nix` sets PATH/VIRTUAL_ENV and delegates to `lifecycle/ak`, which dispatches `server` to the Go binary and everything else to Python/Django.

**Python packaging strategy:** Nix provides the Python 3.14 interpreter and system libraries. Python packages are installed from PyPI using `uv`, locked by authentik's `uv.lock`. This avoids nixpkgs' Python 3.14 compatibility issues and aligns with upstream's build process.

## Source

All derivations fetch from forge mirrors for supply chain control:
- https://forge.ops.eblu.me/mirrors/authentik (upstream: `goauthentik/authentik`)
- https://forge.ops.eblu.me/mirrors/authentik-client-go (upstream: `goauthentik/client-go`)

Version and hashes are centralized in `containers/authentik/sources.nix`.

## Updating to a New Version

1. Update `version` in `sources.nix` and `default.nix`
2. Update `src` and `client-go-src` hashes in `sources.nix` (use `nix-prefetch-git` on ringtail)
3. Rebuild `python-deps.nix` FOD — hash changes when `uv.lock` changes
4. Rebuild `webui-deps.nix` FOD — hash changes when `package-lock.json` or platform-specific npm binaries change
5. Recompute `vendorHash` in `authentik-server.nix` if Go dependencies changed
6. Test on ringtail: `nix-build test-build.nix -A assembled`
7. Build and push the container via CI

## Testing

Nix derivations target `x86_64-linux`. Test incrementally on ringtail:

```fish
set tmpdir (ssh ringtail 'mktemp -d /tmp/authentik-test.XXXXXX')
scp containers/authentik/*.nix ringtail:$tmpdir/
ssh ringtail "cd $tmpdir && nix-build test-build.nix -A assembled --extra-experimental-features 'nix-command flakes'"
ssh ringtail "rm -rf $tmpdir"
```

`test-build.nix` provides both individual component targets and a fully-wired `assembled` target.

## Related

- [[build-authentik-container]] — Container build reference
- [[deploy-authentik]] — Parent deployment goal
- [[agent-change-process]] — C2 methodology
