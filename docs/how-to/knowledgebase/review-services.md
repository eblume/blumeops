---
title: Review Services
modified: 2026-03-24
last-reviewed: 2026-03-07
tags:
  - how-to
  - maintenance
  - services
---

# Review Services

How to periodically review BlumeOps services for version freshness and upgrade opportunities.

## Review by Staleness

Show services sorted by when they were last reviewed (most stale first):

```bash
mise run service-review
```

This reads the tracking file at `service-versions.yaml` (repo root) and sorts by the `last-reviewed` field. Services without a review date float to the top. The script shows a staleness table and then displays the most stale service with a review checklist.

To show more entries in the table:

```bash
mise run service-review --limit 30
```

To filter by service type:

```bash
mise run service-review --type argocd
mise run service-review --type ansible
mise run service-review --type hybrid
```

## Review Process by Service Type

For all service types, start by reading the service's reference card (`docs/reference/services/<service>.md`) for architecture, configuration, and endpoint details.

### ArgoCD Services (`type: argocd`)

1. Check the upstream releases page for new versions
2. Compare to the image tag in `argocd/manifests/<service>/kustomization.yaml` (`images[].newTag`)
3. Review the upstream changelog for breaking changes
4. If the service uses a custom-built container, also check the base image for security updates and follow [[build-container-image]] to rebuild
5. If upgrading, update the manifest and follow [[deploy-k8s-service]]

### Ansible Services (`type: ansible`)

1. Check the upstream releases page for new versions
2. Review the role's vars/defaults for version pins in `ansible/roles/<service>/`
3. If upgrading, update the version and dry-run: `mise run provision-indri -- --tags <service> --check --diff`
4. Follow [[add-ansible-role]] patterns for role changes

### NixOS Services (`type: nixos`)

Versioned NixOS services (forgejo-runner, snowflake, k3s) are pinned via a `nixpkgs-services` overlay in `nixos/ringtail/flake.nix`. This prevents `nix flake update` from silently upgrading them — they only change when the `nixpkgs-services` input is deliberately updated.

1. Check the upstream project for new releases
2. Check what version nixpkgs has: `ssh ringtail 'nix eval nixpkgs#<pkg>.version'`
3. To upgrade, update the `nixpkgs-services` rev in `flake.nix` to a nixpkgs commit that includes the desired version, then run `nix flake update nixpkgs-services` from `nixos/ringtail/`
4. Deploy via `mise run provision-ringtail`
5. Update `service-versions.yaml` with the new version

### Private Forge Repos (`upstream-source` under `forge.eblu.me/eblume/`)

Some services are built from private repos on the forge rather than tracking an external upstream project. When `upstream-source` points to a `forge.eblu.me/eblume/` repo:

1. Clone the repo to `~/code/personal/` if not already checked out
2. Review the repo's dependency pins — uv script metadata, `pyproject.toml`, `package.json`, `flake.nix` inputs, etc.
3. Update stale dependencies and rebuild locally to verify nothing breaks
4. If changes were made, commit, push, and trigger a new release from that repo
5. Back in blumeops, update the container image or release artifact reference as needed

This extends the service review into the source repo's build-time dependencies, which would otherwise be a blind spot — the blumeops-side review only covers the deployment manifest and container base image.

## Attached Services

Some services have auxiliary dependencies that run as separate containers — caches, sidecars, init helpers. These are tracked as **attached services** with a naming convention and an optional `parent` field:

```yaml
- name: authentik-redis
  type: argocd
  parent: authentik
  current-version: "8.2.3"
  upstream-source: https://github.com/redis/redis/releases
  notes: >-
    Attached service: Redis cache/broker for Authentik.
```

**Conventions:**

- **Naming:** `<parent>-<component>` (e.g., `authentik-redis`, `grafana-sidecar`)
- **`parent` field:** points to the parent service entry. Currently informational — the review task doesn't use it yet, but it enables future grouping/dependency-aware reviews.
- **`notes` field:** always starts with "Attached service:" to make the relationship clear at a glance.
- **Version tracking:** attached services that use nixpkgs packages should include a version assertion in `default.nix` (`assert pkgs.<pkg>.version == version;`) so that `flake.lock` updates that change the package version break the build and force explicit acknowledgment.

Existing attached services: `grafana-sidecar`, `authentik-redis`.

## Version Tracking Convention

The `current-version` field in `service-versions.yaml` tracks the **upstream application version**, not the container image tag. For services with custom-built containers, the container image tag (e.g., `v1.0.0`) is decoupled from the contained app version (e.g., `v1.10.1`). This allows container rebuilds (base image updates, build fixes) without implying an upstream version change.

## Marking a Service as Reviewed

After reviewing, edit `service-versions.yaml` (repo root) and update the service entry:

```yaml
- name: prometheus
  type: argocd
  last-reviewed: 2026-02-16
  current-version: "v3.9.1"
  upstream-source: https://github.com/prometheus/prometheus/releases
```

Commit this change alongside any upgrades you make during the review.

## Related

- [[review-documentation]] - Periodically review documentation cards
- [[deploy-k8s-service]] - Deploy changes to Kubernetes services
- [[build-container-image]] - Build and release custom container images
- [[add-ansible-role]] - Add or modify Ansible roles
