---
title: "Runbook: Authentik Blueprint Error"
modified: 2026-10-13
last-reviewed: 2026-10-13
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Authentik Blueprint Error

**Alert names:** `AuthentikBlueprintError`, `AuthentikBlueprintCollectorDown`, `AuthentikBlueprintInstanceCountLow`

An authentik blueprint instance failed to apply, or the collector that watches blueprint state is not reporting. The alert summary carries the blueprint `path` (e.g. `custom/argocd.yaml`).

## Diagnostic Steps

1. **Read the failing instance's task log.** First find the instance's pk:
   ```fish
   curl -s -H "Authorization: Bearer $(op read 'op://blumeops/Authentik (blumeops)/ci-authentik-blueprints-token')" \
     "https://authentik.ops.eblu.me/api/v3/managed/blueprints/" | jq '.results[] | select(.path == "<path>") | {pk, name, status, last_applied}'
   ```
   then fetch its most recent apply task and its logs:
   ```fish
   curl -s -H "Authorization: Bearer $(op read 'op://blumeops/Authentik (blumeops)/ci-authentik-blueprints-token')" \
     "https://authentik.ops.eblu.me/api/v3/tasks/tasks/?rel_obj_id=<instance pk>" | jq '.results[0] | {state, logs}'
   ```
   The last `error`-level line in `logs` is the cause. Note the apply task itself reports `state: done` even when the blueprint failed — the error only exists in the log lines.
2. **Check the collector itself** (for `CollectorDown` / `InstanceCountLow`):
   ```fish
   kubectl -n authentik logs -l app=blueprint-exporter --tail=30 --context=k3s-ringtail
   ```
   `poll failed` lines are the cause; an empty-results poll means the token's RBAC role stopped binding (the list endpoint filters by object permission, so an unbound role returns 200 with 0 results, not 403).

## Common Causes

- **Invalid blueprint path** — the file moved or was deleted; the path guard rejects anything resolving outside the blueprints dir.
- **A `!Find` / `!KeyOf` that resolves to nothing** — the referenced object no longer exists or is ordered after its dependents in the blueprint doc (entries apply in list order; `!KeyOf` only resolves already-applied entries).
- **A missing `!Env` var** — a worker env var referenced by the blueprint doc is unset; the worker restart applies the blueprint, so a missing secret property renders an empty value.
- **RBAC role unbound** (collector alerts) — the `ci-authentik-blueprints` role-to-group binding failed; verify with the curl above (expected `count` >= 30), and fall back to a one-off UI bind of the role to the group if needed.

## After fixing

The blueprint re-applies on the next hourly discovery pass (or immediately if its file hash changed). Verify the instance flipped to `successful` in the API, and watch `authentik_blueprint_status{status="error"}` resolve in Prometheus. How long until the alert clears: the error alert is recency-based over a 75m window, and the exporter stops reporting a path's error as soon as it sees it healthy again — so once the fix lands, the alert resolves within ~75m. Worst case, if the blueprint file was deleted rather than fixed, the exporter carries the path's error state for 2h, so resolution can take up to ~2h15m. `clear_failed_blueprints` (hourly) deletes failing instances and discovery re-creates them, so an in-error `path` may briefly be absent from the API between cycles.

## Related

- [[deploy-infra-alerting]] — Alerting pipeline overview
