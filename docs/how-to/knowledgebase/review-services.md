---
title: Review Services
modified: 2026-02-19
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
mise run service-review -- --limit 30
```

To filter by service type:

```bash
mise run service-review -- --type argocd
mise run service-review -- --type ansible
mise run service-review -- --type hybrid
```

## Review Process by Service Type

### ArgoCD Services

1. Check the upstream releases page for new versions
2. Compare to the image tag or Helm chart version in `argocd/manifests/<service>/`
3. Review the upstream changelog for breaking changes
4. If upgrading, update the manifest and follow [[deploy-k8s-service]]

### Helm Chart Services

Same as ArgoCD, but also check for new chart versions in the mirrored chart repos under `argocd/manifests/<service>/charts/`.

### Hybrid Services (Custom Container + ArgoCD)

1. Check the upstream project for new releases
2. Check the base image for security updates
3. If rebuilding, follow [[build-container-image]] to tag and release
4. Update the ArgoCD manifest with the new image tag

### Ansible Services

1. Check the upstream releases page for new versions
2. Review the role's vars/defaults for version pins in `ansible/roles/<service>/`
3. If upgrading, update the version and dry-run: `mise run provision-indri -- --tags <service> --check --diff`
4. Follow [[add-ansible-role]] patterns for role changes

## Version Tracking Convention

The `current-version` field in `service-versions.yaml` tracks the **upstream application version**, not the container image tag. For hybrid services, the container image tag (e.g., `v1.0.0`) is decoupled from the contained app version (e.g., `v1.10.1`). This allows container rebuilds (base image updates, build fixes) without implying an upstream version change.

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
