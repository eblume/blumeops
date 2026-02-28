---
title: Build Authentik Web UI
modified: 2026-02-28
status: active
requires:
  - authentik-api-client-generation
tags:
  - how-to
  - authentik
  - nix
---

# Build Authentik Web UI

Build the Lit-based TypeScript web frontend for authentik.

## Context

The web UI lives in `web/` in the authentik repo. It's built with Rollup and uses Lit web components. The nixpkgs derivation builds this in two phases:

1. **`webui-deps`** — Fixed-output derivation that runs `npm ci` to fetch Node dependencies. Uses platform-specific output hashes (aarch64-linux vs x86_64-linux).
2. **`webui`** — Patches in the generated TypeScript API client (`client-ts`), then runs `npm run build`. Output includes `dist/` and `authentik/` static directories.

There's also a **`website`** derivation (Docusaurus-based API docs at `website/`) that produces the `/help` endpoint. This is optional but included in the nixpkgs build.

## What to Do

1. Create a fixed-output derivation for `npm ci` in `web/` (platform-specific hashes)
2. Patch the generated TypeScript client into `web/node_modules/@goauthentik/api/`
3. Build with `npm run build` — produces `dist/` and `authentik/` directories
4. Optionally build the Docusaurus website (`website/`) for the `/help` endpoint
5. Verify: static assets exist and reference correct paths

## Key Details

- Build tool: Rollup (via npm scripts)
- Node.js version: `nodejs_24` in current nixpkgs (check upstream requirements)
- The TypeScript API client must be patched in before the build
- Fixed-output hashes break on any npm dependency change — will need updating per release
- Output is consumed by both `authentik-django` (email templates) and the Go server (static serving)

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-api-client-generation]] — Provides TypeScript client (prerequisite)
