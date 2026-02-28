---
title: Build Authentik Go Server
modified: 2026-02-28
status: active
requires:
  - authentik-api-client-generation
  - authentik-python-backend-derivation
tags:
  - how-to
  - authentik
  - nix
---

# Build Authentik Go Server

Build the Go HTTP server binary (`cmd/server`) that serves the web UI, REST API, and spawns gunicorn for the Django backend.

## Context

The Go server is built with `buildGoModule` from the `cmd/server` subpackage. It's a Cobra-based binary that:

- Serves static web assets and the REST API
- Runs an embedded reverse proxy outpost
- Spawns `gounicorn` (gunicorn) to run the Django application
- Manages health checks

The nixpkgs derivation patches store paths into two Go source files so the compiled binary can find Python lifecycle scripts and web assets at runtime.

## What to Do

1. Create a `buildGoModule` derivation for `cmd/server` from the authentik source
2. Inject the generated Go API client into the vendor directory (via `apiGoVendorHook`)
3. Apply `substituteInPlace` patches to hardcode Nix store paths:
   - `internal/gounicorn/gounicorn.go`: `./lifecycle` → `${authentik-django}/lifecycle`
   - `web/static.go`: `./web` → `${authentik-django}/web`
4. Compute the `vendorHash` — note that the hook replaces vendored API code *after* hash verification, so the hash reflects `go.sum` only
5. Rename the output binary from `server` to `authentik`
6. Verify: `./authentik --help` runs successfully

## Key Details

- Go module: `goauthentik.io`
- Subpackage: `./cmd/server`
- CGO: disabled
- The `vendorHash` must be computed with the vendor replacement hook excluded (`overrideModAttrs`)
- Outpost binaries (`cmd/ldap`, `cmd/proxy`, `cmd/radius`) are separate and not needed for basic deployment

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-api-client-generation]] — Provides Go client (prerequisite)
- [[authentik-python-backend-derivation]] — Provides lifecycle scripts and web assets (prerequisite)
