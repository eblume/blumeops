---
title: Build Authentik Container Image
modified: 2026-02-20
tags:
  - how-to
  - authentik
---

# Build Authentik Container Image

Build and publish a Nix-based container image for Authentik to the local registry.

## Context

Discovered while attempting [[deploy-authentik]]: the deployment references `registry.ops.eblu.me/blumeops/authentik:v1.0.0-nix` which doesn't exist. Authentik's nixpkgs package (`pkgs.authentik`) provides the `ak` wrapper which orchestrates a Go server binary and Python Django worker.

## What to Do

1. Verify `containers/authentik/default.nix` builds on ringtail (the Nix builder runs there)
2. The `ak` entrypoint needs bash (included via `bashInteractive`) and orchestrates both `server` and `worker` subcommands
3. Tag and release: `mise run container-tag-and-release authentik v1.0.0`
4. Verify the `-nix` tagged image appears in the registry

## What We Learned

- The entrypoint is `ak` (bash wrapper), not `authentik` (Go binary)
- `ak server` runs the Go HTTP server, `ak worker` runs the Python Django worker
- `pkgs.authentik` bundles Go binary, Python environment, and static assets via `wrapProgram`
- nixpkgs has v2025.10.1, upstream latest is 2025.12.4 — acceptable for initial deployment
- Container needs `bashInteractive` since `ak` is a bash script

## Related

- [[deploy-authentik]] — Parent goal
