---
title: "Plan: Upgrade Grafana Helm Chart"
modified: 2026-02-17
tags:
  - how-to
  - plans
  - grafana
  - observability
---

# Plan: Upgrade Grafana Helm Chart

> **Status:** Planned (not yet executed)
> **Phases:** 3 (execute sequentially, each as a separate PR)

## Background

Grafana is deployed via ArgoCD at Helm chart version **8.8.2** (Grafana app ~11.5.x). The latest chart is **11.1.7** (Grafana app 12.3.3). The chart has moved from the original `grafana/helm-charts` repository (deprecated 2026-01-30) to `grafana-community/helm-charts`.

### Current Deployment

| Property | Value |
|----------|-------|
| **Chart version** | `grafana-8.8.2` |
| **Grafana app** | ~11.5.x |
| **Source** | Forge mirror `eblume/grafana-helm-charts` of `grafana/helm-charts` |
| **ArgoCD app** | `argocd/apps/grafana.yaml` |
| **Values** | `argocd/manifests/grafana/values.yaml` |
| **Namespace** | `monitoring` |
| **Storage** | SQLite on 1Gi PVC |

Datasources: [[prometheus]], [[loki]], PostgreSQL (TeslaMate). 32 dashboard ConfigMaps provisioned via sidecar.

### Breaking Change Summary

| Boundary | What Changes | Impact on Us |
|----------|-------------|--------------|
| **Chart 9.0 (Grafana 12.0)** | Angular plugins removed, datasource UID format enforced, annotation table migration | **Main risk** — but dashboards already use React panels and UIDs are compliant |
| Chart 10.0 | Alert file templating via `tpl` | None — we don't use file-based alerts |
| Chart 11.0 | Min K8s version raised to 1.25, removed old API version fallbacks | None — minikube is modern |
| **Repo migration** | Chart moved to `grafana-community/helm-charts` | Must update forge mirror for 11.x |

### Grafana 12.0 Application Changes (Detail)

- **Angular plugin removal:** All AngularJS panels are force-migrated to React at load time. Our dashboards already use only React panel types (`timeseries`, `stat`, `gauge`, `table`, `geomap`, `barchart`, `bargauge`, `logs`, `piechart`, `state-timeline`). No action needed.
- **Datasource UID format enforcement (`failWrongDSUID`):** UIDs must be alphanumeric + dash/underscore, ≤40 chars. Our UIDs (`prometheus`, `loki`, `TeslaMate`) are compliant. Built-in references like `"-- Grafana --"` in dashboard JSON are handled internally and unaffected.
- **Annotation table migration:** Upgrading to 12.x triggers a full-table rewrite of the `annotation` table (adds `dashboard_uid` column). For our small SQLite database this should be fast, but back up the PVC first.
- **`editors_can_admin` removed:** We don't use this setting. No action needed.

Overall risk: **Low.** No `values.yaml` changes required across any phase.

### Forge Mirror Situation

The forge mirror `eblume/grafana-helm-charts` tracks `https://github.com/grafana/helm-charts`. Forgejo mirrors are managed via its built-in async mirror framework — you cannot manually push tags. To update the mirror upstream or pick up new tags, **delete and re-create the mirror** in Forgejo.

- The old repo (`grafana/helm-charts`) contains tags through `grafana-10.5.15`
- The new repo (`grafana-community/helm-charts`) contains tags for 11.x+
- The community repo was forked from the original, so it should also contain all historical tags

---

## Phase 1: Upgrade to Chart 8.15.0 (Grafana 11.6.1)

**Goal:** Validate the upgrade mechanism with zero breaking changes. Stay on Grafana 11.x.

### Pre-flight

1. **Sync forge mirror** to pick up tag `grafana-8.15.0`:
   - Go to forge.ops.eblu.me → `eblume/grafana-helm-charts` → Settings → Mirror
   - Trigger a sync, or if the tag is already present, skip this step
   - Verify tag `grafana-8.15.0` exists in the forge repo tags list
   - If the tag is not present and sync doesn't fetch it, delete the mirror and re-create it from `https://github.com/grafana/helm-charts` (this should pull all tags including 8.15.0)

### Steps

1. Create feature branch `upgrade/grafana-8.15.0`
2. Edit `argocd/apps/grafana.yaml`:
   - Change `targetRevision: grafana-8.8.2` → `targetRevision: grafana-8.15.0`
3. Add changelog fragment `docs/changelog.d/upgrade-grafana-8.15.0.infra.md`
4. Commit, push, create PR via `tea pr create`
5. **Deploy on branch:**
   ```fish
   argocd app set grafana --revision upgrade/grafana-8.15.0
   argocd app diff grafana
   argocd app sync grafana
   ```
6. **Verify** (see Verification Checklist below)
7. After merge:
   ```fish
   argocd app set grafana --revision main
   argocd app sync grafana
   ```

### Files Modified

- `argocd/apps/grafana.yaml` (targetRevision)
- `docs/changelog.d/upgrade-grafana-8.15.0.infra.md` (new)

---

## Phase 2: Upgrade to Chart 9.4.5 (Grafana 12.1.1)

**Goal:** Cross the Grafana 11→12 boundary. This is the main breaking change phase — triggers Angular removal, UID enforcement, and annotation table migration.

### Pre-flight

1. **Back up Grafana PVC** before upgrading:
   ```fish
   kubectl --context=minikube-indri -n monitoring exec deploy/grafana -- \
     sqlite3 /var/lib/grafana/grafana.db ".backup '/var/lib/grafana/grafana-backup.db'"
   ```
2. Verify forge mirror has tag `grafana-9.4.5` (should exist — it's in the old repo)

### Steps

1. Create feature branch `upgrade/grafana-9.4.5`
2. Edit `argocd/apps/grafana.yaml`:
   - Change `targetRevision: grafana-8.15.0` → `targetRevision: grafana-9.4.5`
3. Add changelog fragment `docs/changelog.d/upgrade-grafana-9.4.5.infra.md`
4. Commit, push, create PR
5. **Deploy on branch:**
   ```fish
   argocd app set grafana --revision upgrade/grafana-9.4.5
   argocd app sync grafana
   ```
6. **Thorough verification:**
   - Watch pod logs for annotation table migration messages:
     ```fish
     kubectl --context=minikube-indri -n monitoring logs -f deploy/grafana | head -100
     ```
   - Verify all 3 datasources connect: Grafana UI → Settings → Datasources → Test each
   - Spot-check key dashboards: macOS System, Services Health, TeslaMate Overview
   - Check pod logs for UID format errors (unlikely but possible)
   - Run `mise run services-check`
7. **If issues:** Restore backup and roll back `targetRevision`:
   ```fish
   kubectl --context=minikube-indri -n monitoring exec deploy/grafana -- \
     cp /var/lib/grafana/grafana-backup.db /var/lib/grafana/grafana.db
   # Then set targetRevision back to grafana-8.15.0 and sync
   ```
8. After successful verification, clean up backup:
   ```fish
   kubectl --context=minikube-indri -n monitoring exec deploy/grafana -- \
     rm /var/lib/grafana/grafana-backup.db
   ```
9. After merge: set revision to main and sync

### Files Modified

- `argocd/apps/grafana.yaml` (targetRevision)
- `docs/changelog.d/upgrade-grafana-9.4.5.infra.md` (new)

---

## Phase 3: Upgrade to Chart 11.1.7 (Grafana 12.3.3)

**Goal:** Get to the latest chart from the new community repository. No new breaking changes — this is a repo migration + version bump.

### Pre-flight: Update Forge Mirror

The `grafana-community/helm-charts` repo is a fork of the original, so it should contain all historical tags plus the new 11.x tags.

1. **Delete the existing forge mirror** `eblume/grafana-helm-charts`
2. **Re-create it** as a mirror of `https://github.com/grafana-community/helm-charts`
3. Wait for the initial mirror sync to complete
4. Verify tag `grafana-11.1.7` exists in the forge repo tags list
5. Also verify that older tags (e.g., `grafana-9.4.5`) are still present — if the community repo doesn't carry old tags, we need to handle that before proceeding

> **Fallback:** If the community repo doesn't have old tags, create a second forge mirror (e.g., `eblume/grafana-community-helm-charts`) and update the ArgoCD app's `repoURL` to point to it.

### Steps

1. Create feature branch `upgrade/grafana-11.1.7`
2. Edit `argocd/apps/grafana.yaml`:
   - Change `targetRevision: grafana-9.4.5` → `targetRevision: grafana-11.1.7`
   - Update comment: `# Chart mirrored from https://github.com/grafana-community/helm-charts to forge`
   - If a new mirror repo was created (fallback), also update `repoURL`
3. Edit `argocd/manifests/grafana/values.yaml`:
   - Update comment: `# Chart: https://github.com/grafana-community/helm-charts/tree/main/charts/grafana`
4. Update `docs/reference/services/grafana.md`:
   - Note chart version and new upstream source
5. Update `docs/reference/services/forgejo.md`:
   - Update mirror reference if repo name changed
6. Add changelog fragment `docs/changelog.d/upgrade-grafana-11.1.7.infra.md`
7. Commit, push, create PR
8. Deploy on branch and verify (standard check — no new breaking changes)
9. After merge: set revision to main and sync

### Files Modified

- `argocd/apps/grafana.yaml` (targetRevision, comment, possibly repoURL)
- `argocd/manifests/grafana/values.yaml` (comment only)
- `docs/reference/services/grafana.md`
- `docs/reference/services/forgejo.md` (if mirror name changed)
- `docs/changelog.d/upgrade-grafana-11.1.7.infra.md` (new)

---

## Verification Checklist (All Phases)

After each phase:

- [ ] Pod is running: `kubectl --context=minikube-indri -n monitoring get pods -l app.kubernetes.io/name=grafana`
- [ ] UI loads at `https://grafana.ops.eblu.me` and/or `https://grafana.tail8d86e.ts.net`
- [ ] Admin login works
- [ ] Datasources healthy: Settings → Datasources → Test each (Prometheus, Loki, TeslaMate)
- [ ] Key dashboards render: macOS System, Services Health, TeslaMate Overview
- [ ] Sidecar loaded all 32 dashboard ConfigMaps (check dashboard list)
- [ ] `mise run services-check` passes
- [ ] No errors in pod logs: `kubectl --context=minikube-indri -n monitoring logs deploy/grafana --tail=50`

## Open Questions

- **Forge mirror tags:** Will the `grafana-community/helm-charts` mirror include all historical tags from the original repo? Verify during Phase 3 pre-flight. If not, use the fallback approach (separate mirror).
- **Chart pinning strategy:** After reaching 11.1.7, decide whether to track the latest tag going forward or continue pinning to specific versions. Pinning is safer for GitOps.

## Reference Files

| File | Purpose |
|------|---------|
| `argocd/apps/grafana.yaml` | ArgoCD Application (chart source + version) |
| `argocd/apps/grafana-config.yaml` | ArgoCD Application (dashboards, ingress, secrets) |
| `argocd/manifests/grafana/values.yaml` | Helm values |
| `argocd/manifests/grafana-config/` | ConfigMaps, ExternalSecrets, Ingress |
| `docs/reference/services/grafana.md` | Service reference card |
| `docs/reference/services/forgejo.md` | Forge mirror inventory |

## Related

- [[grafana]] — Service reference card
- [[prometheus]] — Metrics datasource
- [[loki]] — Logs datasource
- [[apps]] — ArgoCD application inventory
