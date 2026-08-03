---
title: Blumeops-CI Item Migration
modified: 2026-08-03
last-reviewed: 2026-08-03
tags:
  - how-to
  - operations
  - security
---

# Blumeops-CI Item Migration

The audit and migration plan for the `blumeops-ci` vault tier
([[warrant-approval-gated-runs]] Phase 2; heph `01KZ0G21JS…`). The vault
exists and `BLUMEOPS_CI_OP_TOKEN` is provisioned; this doc decides *what
moves in* and — more importantly — what never does.

## The audit: who consumes what (2026-08-03, from main)

| Workflow | Actions secret | Backing vault item (blumeops) | Verdict |
|----------|----------------|-------------------------------|---------|
| `argocd-deploy` | `ARGOCD_AUTH_TOKEN` | `w3663ffn…/argocd_token` (workflow-bot, get/sync/update) | **migrate** (pilot) |
| `build-container` | `ZOT_CI_API_KEY` | `w3663ffn…/zot-ci-api` | **migrate** |
| `deploy-fly` | `FLY_DEPLOY_TOKEN` | `on5slfay…/deploy-token` | **migrate** |
| `build-blumeops`, `cv-deploy` | `MAIN_PUSH_TOKEN` | `blumeops-main-push-token/token` (eblume PAT, write:repository) | **migrate, eyes open** — it pushes protected `main` |
| `agent-repo-access` | `FORGE_ADMIN_TOKEN` | `w3663ffn…/api-token` (**eblume admin PAT**) | **flag, do not migrate yet** — heaviest credential in CI; mint a narrower token first (admin scope is needed only for collaborator ops) |
| all | `GITHUB_TOKEN` | forge-injected | n/a |

## What migration actually means

Not "copy items to another vault" — a **consumption change**: privileged
workflows stop receiving per-secret Actions secrets and instead
`op read op://blumeops-ci/<item>/<field>` **at job time** using
`BLUMEOPS_CI_OP_TOKEN` (the only Actions secret they keep needing).

Won:

- **Rotation without provisioning** — `op item edit` in `blumeops-ci` takes
  effect on the next run; no `provision-indri` round-trip, no more
  minikube-era-token rot (the run-703 failure mode).
- **Per-item audit** — 1Password access logs show which run's token read
  which item, per invariant 5.
- **Shrinking Actions-secret surface** — repo-wide-readable secrets drop to
  one revocable token.
- **Untangling `w3663ffn…`** — the migrated copies become per-purpose items,
  which is the fix for the multi-field-item overwrite hazard noted on the
  heph task.

Costs: runners need the `op` CLI (`_1password-cli` in the priv runner's
hostPackages; mise-installed on indri), and jobs make a network call to
1Password at runtime.

## What never migrates: the provision-* verdict

`provision-indri` / `provision-ringtail` pre_tasks read **the breadth of
the blumeops vault** — borgmatic/borgbase keys, every forgejo internal
secret, OIDC client secrets for zot/jellyfin/…, the Gandi PAT, 1Password
Connect credentials, the agents SA credential itself. Migrating that set
into a CI-readable vault would recreate the keys to the kingdom behind
`BLUMEOPS_CI_OP_TOKEN` — the exact thing the vault split exists to prevent.

**Verdict: wholesale `provision-*` workflows stay `class: deny`**
(warrant-policy.yaml) indefinitely. The path to agent-requestable
provisioning is **decomposition**: narrow, per-role actions
(`provision-indri --tags forgejo_runner` needs only the runner identity
items) added one at a time, each with its own policy entry and its own
deliberate item copy. If a role's secret set is too broad to be comfortable
in `blumeops-ci`, that role stays human-run — that is the system working.

## Migration order (each its own small PR + human item-copy)

1. **Pilot: `argocd_token`** — create `blumeops-ci/argocd-workflow-bot`
   (field `token`), switch `argocd-deploy.yaml` to job-time `op read`,
   verify a dispatch, then delete the `ARGOCD_AUTH_TOKEN` Actions secret.
2. `zot-ci-api` → `blumeops-ci/zot-ci` (also closes the standing
   key-cycling chore's provisioning friction).
3. `fly deploy-token` → `blumeops-ci/fly-deploy`.
4. `main-push` PAT → `blumeops-ci/forge-main-push` — last, because its
   blast radius (protected-`main` push) deserves the most-proven pattern.
5. `FORGE_ADMIN_TOKEN`: **not migrated** — first mint a
   collaborator-scoped token for agent-repo-access, then revisit.

## Related

- [[warrant-approval-gated-runs]] — the program
- [[request-a-privileged-run]] — the request loop these workflows serve
- heph `01KZ0G21JS…` — the tracking task
