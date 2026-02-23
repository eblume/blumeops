---
title: Build Grafana Container
status: active
modified: 2026-02-23
tags:
  - how-to
  - grafana
  - containers
---

# Build Grafana Container

Build a home-built Grafana 12.x container image and publish to the forge registry.

## Context

Grafana currently uses the upstream `docker.io/grafana/grafana:11.4.0` image via the Helm chart. Per supply-chain policy, this should be replaced with a locally built image pushed to `forge.ops.eblu.me/eblume/grafana`.

## Steps

1. Add a Grafana container build to Dagger (or Nix, following existing patterns)
2. Base on the official Grafana source or use a Nix derivation
3. Tag and push to `forge.ops.eblu.me/eblume/grafana:<version>`
4. Add to `mise run container-list` inventory

## Reference

- Follow [[build-container-image]] for the standard container build workflow
- See existing container builds in `.dagger/` for patterns
- The k8s-sidecar image (`quay.io/kiwigrid/k8s-sidecar`) is a secondary concern — address after the main Grafana image

## Related

- [[upgrade-grafana]] — Goal card
