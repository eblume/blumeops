---
title: Container Versioning and Tags
modified: 2026-06-18
tags:
  - how-to
  - containers
  - ci
  - zot
---

# Container Versioning and Tags

How container versions are declared, kept in sync, and turned into immutable
registry tags. Since [[retire-minikube]] every container is nix-built
(`containers/<name>/default.nix`); the older Dockerfile / `container.py` build
types and their `ARG CONTAINER_APP_VERSION` / `VERSION` conventions are gone.

## Version source

Each container's version lives in `version = "..."` in its `default.nix`,
asserted against the built package (e.g. `assert app.version == version;`). That
single declaration is the source of truth — no separate VERSION file or build
ARG.

## Sync check

`mise run container-version-check` validates, per container under `containers/`:

1. a `default.nix` exists and yields a version (parsed from `version = "..."`,
   or via `dagger call nix-version` for unmodified nixpkgs packages), and
2. a matching `service-versions.yaml` entry exists with a non-null
   `current-version` that agrees (leading `v` ignored).

It runs as a `prek.toml` hook scoped to `containers/` and `service-versions.yaml`
— checking only changed containers by default (`--all-files` checks everything).
The `kubectl` utility image is exempt; `kiwix-serve` → `kiwix` maps the dir name
to its service name.

## Build and tag

`mise run container-build-and-release <name>` dispatches the
`build-container.yaml` workflow, which builds `default.nix` with `nix-build` and
pushes via `skopeo copy` on the `nix-container-builder` runner ([[ringtail]]).
Images are tagged:

```
registry.ops.eblu.me/blumeops/<name>:<version>-<short-sha>-nix
```

e.g. `v2.17.0-abc1234-nix` — the bundled app version plus the 7-char source
commit SHA, so every image is traceable to an exact tree. Tags are immutable:
CI's `artifact-workloads` group has only `create` (not `update`), so re-pushing
an existing tag is rejected server-side (see [[enforce-tag-immutability]]).
`mise run container-list` shows recent tags, annotated `[main]` / `[branch]`.

## Local evaluation

Build or inspect a nix container without going through CI:

```fish
dagger call build-nix --src=. --container-name=ntfy export --path=./ntfy.tar
dagger call nix-version --package=ntfy-sh
```

`build-nix` produces a docker-archive tarball (`docker load`-able);
`nix-version` is also the fallback the sync check uses for unmodified nixpkgs
packages.

## Related

- [[build-container-image]] — Full container creation workflow
- [[harden-zot-registry]] — Registry auth + access control
- [[enforce-tag-immutability]] — Why tags can't be overwritten
- [[dagger]] — Dagger reference
