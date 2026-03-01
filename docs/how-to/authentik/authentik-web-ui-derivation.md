---
title: Build Authentik Web UI
modified: 2026-03-01
requires:
  - authentik-api-client-generation
tags:
  - how-to
  - authentik
  - nix
---

# Build Authentik Web UI

Build the Lit-based TypeScript web frontend for authentik.

## Overview

The web UI lives in `web/` in the authentik repo. As of 2026.2.0, the main build uses **esbuild** (via wireit) and the SFE sub-package uses **rollup**. The Nix build uses a two-phase approach:

1. **`webui-deps.nix`** — Fixed-output derivation that runs `npm ci` to fetch Node dependencies. Platform-specific output hash (npm downloads architecture-specific native binaries for esbuild, rollup, and SWC).
2. **`webui.nix`** — Copies deps, patches in the generated TypeScript API client (`client-ts`), patches shebangs, then runs `npm run build` (wireit/esbuild) and `npm run build:sfe` (rollup). Output includes `dist/` and `authentik/` static directories.

## Build Details

- **Node.js:** `nodejs_24` (authentik requires Node >= 24, npm >= 11.6.2)
- **Build time:** ~33s on ringtail (x86_64-linux)
- **FOD hash:** Platform-specific — will need updating on each authentik version bump
- **Output:** `$out/dist/` (JS/CSS bundles) and `$out/authentik/` (static SVG/PNG icons)
- **Consumed by:** Go server (`authentik-server.nix` via `webui` parameter) for static file serving, and `authentik-django.nix` for email template icon paths
- **Docusaurus website** (`/help` endpoint) is not built — optional and can be added later

## Key Lessons

- The 2026.2.0 build switched from rollup to esbuild for the main frontend. Only the SFE sub-package still uses rollup.
- The version string in `packages/core/version/node.js` uses a JSON import-with-assertion that doesn't resolve in the Nix sandbox — must be patched to hardcode the version.
- `NODE_OPTIONS=--openssl-legacy-provider` is needed for compatibility.
- Workspace packages have separate `node_modules/` directories — the FOD must collect all of them via `find`.

## Related

- [[build-authentik-from-source]] — Parent goal
- [[authentik-api-client-generation]] — Provides TypeScript client (prerequisite)
