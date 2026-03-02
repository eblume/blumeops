---
title: Generate Authentik API Clients
modified: 2026-03-01
last-reviewed: 2026-03-01
requires:
  - mirror-authentik-build-deps
tags:
  - how-to
  - authentik
  - nix
---

# Generate Authentik API Clients

Build Go and TypeScript API client bindings from authentik's OpenAPI spec (`schema.yml`). These are build-time inputs for the Go server and web UI respectively.

## Context

Authentik maintains a separate repo ([`goauthentik/client-go`](https://github.com/goauthentik/client-go)) with pre-generated Go client code. The nixpkgs derivation fetches this and injects it into the Go vendor directory via a setup hook (`apiGoVendorHook`). The TypeScript client is generated inline from `schema.yml` using `openapi-generator-cli`.

Both clients are generated from the same `schema.yml` OpenAPI spec in the main authentik repo.

## What to Do

1. Create a Nix derivation (`client-go`) that generates Go API client bindings from `schema.yml` using `openapi-generator-cli`
2. Create a Nix derivation (`client-ts`) that generates TypeScript fetch client bindings from the same spec
3. Create a setup hook (`apiGoVendorHook`) that replaces `goauthentik.io/api/v3` in the Go vendor directory with the generated client
4. Verify the generated code compiles (Go: `go build`, TypeScript: type-check with `tsc`)

## Key Details

- Source spec: `schema.yml` in the authentik repo root
- Go client replaces `vendor/goauthentik.io/api/v3/` in the server build (via `api-go-vendor-hook.nix`)
- TypeScript client replaces `web/node_modules/@goauthentik/api/` in the web UI build (symlinked in `webui.nix`)

## Testing on Ringtail

The `test-build.nix` harness in `containers/authentik/` supports individual component builds:

```fish
set tmpdir (ssh ringtail 'mktemp -d /tmp/authentik-test.XXXXXX')
scp containers/authentik/*.nix ringtail:$tmpdir/
ssh ringtail "cd $tmpdir && nix-build test-build.nix -A client-go --extra-experimental-features 'nix-command flakes'"
ssh ringtail "cd $tmpdir && nix-build test-build.nix -A client-ts --extra-experimental-features 'nix-command flakes'"
ssh ringtail "rm -rf $tmpdir"
```

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-go-server-derivation]] — Consumer of Go client
- [[authentik-web-ui-derivation]] — Consumer of TypeScript client
