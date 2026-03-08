---
title: Build JobSync Container
modified: 2026-03-08
tags:
  - how-to
  - jobsync
  - nix
---

# Build JobSync Container

Build and release the JobSync nix container image.

```fish
mise run container-release jobsync 1.1.4
```

The derivation is at `containers/jobsync/default.nix`. It uses `buildNpmPackage` for the Next.js app and `dockerTools.buildLayeredImage` for the container. The entrypoint (`containers/jobsync/entrypoint.sh`) runs `prisma migrate deploy` then starts `node server.js`.

## Upgrading JobSync

1. Update the forge mirror: `mise run mirror-sync jobsync`
2. Update `version` in `default.nix` to match the new upstream tag
3. Clear `hash` in `fetchgit` (set to `""`), build, grab the correct hash from the error
4. Clear `npmDepsHash` (set to `""`), build again, grab the correct hash
5. Check if `postPatch` still applies — the Google Fonts import may change between versions
6. `mise run container-release jobsync <new-version>`
7. Update `newTag` in `argocd/manifests/jobsync/kustomization.yaml`

## Nix + Prisma + Next.js Pitfalls

### Prisma engine downloads blocked by sandbox

Prisma tries to download platform-specific engine binaries during `prisma generate`. The nix sandbox blocks network access at build time.

**Fix:** Use `pkgs.prisma-engines` from nixpkgs and set env vars pointing at the nix store paths: `PRISMA_QUERY_ENGINE_LIBRARY`, `PRISMA_QUERY_ENGINE_BINARY`, `PRISMA_SCHEMA_ENGINE_BINARY`, `PRISMA_FMT_BINARY`. Set `PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1` to tolerate minor version mismatch.

### Google Fonts blocked by sandbox

`next/font/google` fetches from `fonts.googleapis.com` during `next build`.

**Fix:** Patch `src/app/layout.tsx` in `postPatch` to replace the Google font import with a no-op object. The app falls back to system sans-serif.

### Missing FHS paths in nix containers

Nix containers lack `/usr/bin/env`, `/tmp`, etc. `npx`-downloaded packages use `#!/usr/bin/env node` shebangs.

**Fix:** In `extraCommands`: `mkdir -p tmp data usr/bin` and `ln -s ${pkgs.coreutils}/bin/env usr/bin/env`.

### Runtime migrations via npx

The nix sandbox blocks network at build time, but runtime has full network access. Use `npx -y prisma@<version> migrate deploy` in the entrypoint — npx downloads the prisma CLI on first run.

### Build on ringtail, not via Dagger

The Dagger `build-nix` pipeline runs in host architecture. On macOS (arm64), this produces arm64 images. Build on ringtail (x86_64) using the CI workflow or `mise run container-release`.

## Related

- [[deploy-jobsync]]
- [[build-container-image]]
