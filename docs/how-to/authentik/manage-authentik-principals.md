---
title: Manage Authentik Principals
modified: 2026-10-17
last-reviewed: 2026-10-17
tags:
  - how-to
  - authentik
  - principals
---

# Manage Authentik Principals

How to add and retire the identities Authentik serves. The Authentik side of the [[principals]] naming scheme.

## The model

`argocd/manifests/authentik/principals.yaml` is the roster of record for every `authentik_core.user`, `authentik_core.group`, and `authentik_policies.policybinding` entry in the blueprint ConfigMap (`argocd/manifests/authentik/configmap-blueprint.yaml`): groups with their per-app `access` bindings, and the users that belong to them.

`argocd/manifests/authentik/retiring.yaml` is the deletion queue — normally empty. An entry renders an `is_active: false` user record (plus its group, when declared) into the blueprint, so the blueprint keeps owning the record until the principal is deleted from live Authentik.

`mise run reconcile-authentik-principals` is the live side of that loop: it diffs live Authentik (and Grafana JIT users) against the two files, and `--delete --apply` empties the queue by deleting what it names — the only thing that deletes a principal from live Authentik.

`mise run render-authentik-principals --write` regenerates the principal entries in the ConfigMap from these two files; the prek hook of the same name (`--check` mode) fails Lint on drift between them and the ConfigMap. The blueprint ConfigMap is rendered output — never edit its principal entries by hand. New entries start as a minimal skeleton block in the ConfigMap — model line plus identifiers — and the renderer fills in the exact body.

## Add a principal

1. Add the group(s) under `groups:` — `blueprint:` names the data key that should own the group entry; `access:` lists the bindings. Each `access` entry's `app` is the app slug whose blueprint key is `<app>.yaml`; `order` is normally omitted (the renderer derives the next slot from the highest pinned order in that app); `ref: find` is optional for bindings that need a `!Find` instead of the default `!KeyOf` (the default is `keyof` when the binding and its group share a data key, else `find`).
2. Add the user under `principals:` — `username` MUST start with the naming-scheme tier prefix (`talos-`/`horkos-`/`ci-`/`cli-`, see [[principals]]); `type: service_account` for machines, omit for internal users; `groups:` lists membership.
3. Add a minimal skeleton entry block for each new identity under the owning data key's `entries:` in `configmap-blueprint.yaml` — the renderer fills in the exact body. The binding skeleton's `order: 0` is a placeholder the renderer corrects; its `group` may use the `!Find` form.

   Group (under the group's `blueprint:` key):

   ```yaml
         - model: authentik_core.group
           id: <name>-group
           identifiers:
             name: <name>
   ```

   User (under its home data key):

   ```yaml
         - model: authentik_core.user
           id: <username>-user
           identifiers:
             username: <username>
   ```

   Binding (under `<app>.yaml`):

   ```yaml
         - model: authentik_policies.policybinding
           identifiers:
             order: 0
             target: !KeyOf <app>-app
             group: !KeyOf <group>-group
   ```

4. `mise run render-authentik-principals --write`.
5. Commit both the yaml edit and the rendered ConfigMap in one PR — Lint fails if they drift. ArgoCD auto-sync applies the blueprint.

For a zot identity, the zot accessControl grant (the `ansible/roles/zot` template) and the first key rotation ([[zot]] / [[register-zot-oidc-client]]) are separate companion changes.

## Retire a principal

1. Revoke service-side credentials first — for a zot identity, revoke its zot API keys ([[zot]] §Retiring an identity) and record it as `keys_revoked: true`.
2. Delete the user (and its groups/access) from `principals.yaml`.
3. Append a `retiring.yaml` entry — `username`, `name`, `retired`, `issue`, `type`/`group` when the record has one, `keys_revoked: true` for zot.
4. Render and commit in a PR. The blueprint keeps owning the record as `is_active: false` from that point, so a skipped delete cannot silently revive it.
5. After merge, a human runs the reconcile: `mise run reconcile-authentik-principals --delete` to preview, then `--delete --apply` to delete the user (and its paired group) from live Authentik and sweep the principal's Grafana JIT user (the Grafana row keyed on the login name) in the same pass. The task refuses a zot identity without `keys_revoked: true`, so step 1 is enforced, not a ritual.
6. Follow-up PR: remove the queue entry and re-render.

## Never rename in place

Changing a username or group name creates a new Authentik object and orphans the old one (eblume/blumeops#1039 cycle 4; the 2026-09 #1419 blueprint apply is how the `talos-heph-stray` duplicate came to exist). A rename is a retire + add.

## Related

- [[principals]] — the naming scheme this roster implements
- [[zot]] — registry identities and API-key rotation
- [[register-zot-oidc-client]] — zot OIDC client registration
