---
title: Build Authentik from Source
modified: 2026-02-28
status: active
branch: mikado/authentik-source-build
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

Replace `pkgs.authentik` from nixpkgs with a custom Nix derivation that builds authentik from source. This removes the dependency on the nixpkgs packaging timeline and gives full version control.

## Motivation

The nix-container-builder runner on ringtail resolves `nixpkgs` via the NixOS nix registry, which pins to `nixos-25.11`. That channel lags behind upstream authentik releases — e.g. nixos-25.11 has 2025.10.1 while upstream is at 2025.12.4+. Building from source lets us target any release.

This also serves as practice for packaging services from source using Nix, relying on nixpkgs only for satellite dependencies (Python interpreter, Node.js, Go toolchain, system libraries).

## Architecture

Authentik has four build components that must be assembled:

1. **API client generation** — Go and TypeScript bindings generated from `schema.yml` (OpenAPI)
2. **Python backend** (`authentik-django`) — Django application with 60+ Python dependencies, including 4 in-tree packages and a forked `djangorestframework`
3. **Web UI** — Lit-based TypeScript frontend built with Rollup
4. **Go server** — HTTP server binary (`cmd/server`) that serves the web UI and spawns gunicorn for Django

The final package is the `ak` bash wrapper that orchestrates Go server + Python worker.

## Source

Forge mirror: https://forge.ops.eblu.me/mirrors/authentik (upstream: `goauthentik/authentik`)

Reference derivation: [nixpkgs `pkgs/by-name/au/authentik/package.nix`](https://github.com/NixOS/nixpkgs/tree/master/pkgs/by-name/au/authentik)

## What to Do

Once all prerequisites are complete:

1. Assemble the component derivations into a final `ak`-wrapped package in `containers/authentik/`
2. Update `containers/authentik/default.nix` to use the custom derivation instead of `pkgs.authentik`
3. Build and push the container: `mise run container-build-and-release authentik`
4. Update `argocd/manifests/authentik/kustomization.yaml` with the new image tag
5. Update `service-versions.yaml` with the new version
6. Verify deployment: ArgoCD sync, UI login, OAuth2 flows

## Related

- [[build-authentik-container]] — Current nixpkgs-based build (to be replaced)
- [[deploy-authentik]] — Parent deployment goal
- [[agent-change-process]] — C2 methodology
