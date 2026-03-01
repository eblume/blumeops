---
title: Generate Authentik API Clients
modified: 2026-02-28
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
- Go client replaces `vendor/goauthentik.io/api/v3/` in the server build
- TypeScript client replaces `web/node_modules/@goauthentik/api/` in the web UI build
- The nixpkgs derivation patches the generated Go client (`client-go-config.patch`) — check if still needed

## Testing on Ringtail

Use this ad-hoc `test-build.nix` harness (not committed to the repo):

```nix
# test-build.nix
let
  pkgs = (builtins.getFlake "nixpkgs").legacyPackages.x86_64-linux;
  sources = import ./sources.nix { inherit pkgs; };
in
{
  client-go = import ./client-go.nix { inherit pkgs sources; };
  client-ts = import ./client-ts.nix { inherit pkgs sources; };
  api-go-vendor-hook = import ./api-go-vendor-hook.nix { inherit pkgs sources; };
}
```

```fish
set tmpdir (ssh ringtail 'mktemp -d /tmp/authentik-test.XXXXXX')
scp containers/authentik/*.nix ringtail:$tmpdir/
ssh ringtail "cd $tmpdir && nix-build test-build.nix -A client-go --extra-experimental-features 'nix-command flakes'"
ssh ringtail "rm -rf $tmpdir"
```

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-go-server-derivation]] — Consumer of Go client
- [[authentik-web-ui-derivation]] — Consumer of TypeScript client
