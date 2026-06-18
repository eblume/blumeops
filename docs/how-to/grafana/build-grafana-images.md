---
title: Build Grafana Images
modified: 2026-06-17
last-reviewed: 2026-06-17
tags:
  - how-to
  - grafana
  - containers
---

# Build Grafana Images

Home-built container images for Grafana and its dashboard sidecar, published to `registry.ops.eblu.me/blumeops/`.

## Grafana

**Build:** `containers/grafana/default.nix`
**Image:** `registry.ops.eblu.me/blumeops/grafana`

Downloads the official Grafana OSS release tarball from `dl.grafana.com` (amd64), patches it with `autoPatchelfHook`, installs it into `/usr/share/grafana`, and layers it with `dockerTools.buildLayeredImage`.

```fish
# Update version = "..." in containers/grafana/default.nix

mise run container-build-and-release grafana
```

**Gotchas:**

- **Tarball directory name:** Extracts to `grafana-<version>` (e.g. `grafana-12.4.2`), *not* `grafana-v<version>`.
- **`homepath`:** The entrypoint points grafana at the real store path, not the `/usr/share/grafana` symlink — grafana's core-plugin walker resolves symlinks and refuses to start otherwise.
- **UID 472:** Matches the official Grafana image for PVC ownership compatibility (`chown 472:472` on the config/data/log dirs).
- **amd64 only:** The fetched tarball is `linux-amd64`; this nix build targets ringtail (x86_64).

## Grafana Sidecar

**Build:** `containers/grafana-sidecar/default.nix`
**Image:** `registry.ops.eblu.me/blumeops/grafana-sidecar`

Fetches the [kiwigrid/k8s-sidecar](https://github.com/kiwigrid/k8s-sidecar) source from the forge mirror, builds a `python3.withPackages` environment (dependency versions come from nixpkgs, not upstream's pins), and layers it with `buildLayeredImage`.

```fish
# Update version = "..." in containers/grafana-sidecar/default.nix

mise run container-build-and-release grafana-sidecar
```

**Gotchas:**

- **UID 65534:** Runs as `nobody:nobody` (`User = "65534:65534"`) for non-root execution.
- **Forge mirror name:** `mirrors/kiwigrid-grafana-sidecar` (not `k8s-sidecar`).
- **Health endpoint:** 2.x exposes `/healthz` on port 8080 (liveness + readiness probes configured in deployment).

## Related

- [[grafana]] — Service reference card
- [[upgrade-grafana]] — Migration context and future upgrade steps
- [[kustomize-grafana-deployment]] — Kustomize manifest structure
- [[build-container-image]] — Standard container build workflow
