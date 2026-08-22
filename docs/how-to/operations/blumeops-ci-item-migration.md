---
title: Blumeops-CI Item Migration
modified: 2026-08-22
last-reviewed: 2026-08-22
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

**Status (2026-08-22): executed.** All four migration steps landed in one
PR; `warrant-bot-drift` and `agent-repo-access` keep `FORGE_ADMIN_TOKEN`
pending its collaborator-scoped replacement (heph `01KZ5ESS2G…`).

## The audit: who consumes what (2026-08-22, from main)

The 2026-08-03 audit predates the [[horkos]] extraction; talos and horkos
release CI now consume `ZOT_CI_API_KEY` and `RELEASE_FORGE_TOKEN` too.

| Workflow | Actions secret | Backing vault item (blumeops) | Verdict |
|----------|----------------|-------------------------------|---------|
| `argocd-deploy` | `ARGOCD_AUTH_TOKEN` | `w3663ffn…/argocd_token` (workflow-bot, get/sync/update) | **migrated** (pilot) → `blumeops-ci/argocd-workflow-bot` |
| `build-container`; talos + horkos `release.yaml` | `ZOT_CI_API_KEY` | `w3663ffn…/zot-ci-api` | **migrated** → `blumeops-ci/zot-ci` |
| `deploy-fly` | `FLY_DEPLOY_TOKEN` | `on5slfay…/deploy-token` | **migrated** → `blumeops-ci/fly-deploy` |
| `build-blumeops`, `cv-deploy` | `MAIN_PUSH_TOKEN` | `blumeops-main-push-token/token` (eblume PAT, write:repository) | **migrated, eyes open** — it pushes protected `main` → `blumeops-ci/forge-main-push` |
| talos + horkos `release.yaml` | `RELEASE_FORGE_TOKEN` | `warrant-dispatch-token/token` (warrant-bot PAT, write on blumeops — branch push + PR open, cannot merge or dispatch) | **stays an Actions secret** — already a narrow, drift-checked bot identity; migrate only if rotation friction shows up |
| `agent-repo-access`, `warrant-bot-drift` | `FORGE_ADMIN_TOKEN` | `w3663ffn…/api-token` (**eblume admin PAT**) | **flag, do not migrate yet** — heaviest credential in CI; mint a narrower token first (admin scope is needed only for collaborator ops) |
| all | `GITHUB_TOKEN` | forge-injected | n/a |

## The one-CI-trust-tier decision (2026-08-21)

All CI in `eblume/*` repos is **one trust tier** — no per-repo
stratification. Sharing `BLUMEOPS_CI_OP_TOKEN` (full `blumeops-ci` vault
read) with talos/horkos release CI is by-design: it is *CI* reading the
vault, not the services themselves, and workflow definitions reach main
only through a human merge (bots can't merge or dispatch). Consciously
accepted: the tier transitively includes push-to-blumeops-`main`
(auto-sync deploys + policy/workflow edits); `forge-main-push` being an
account-wide eblume PAT is a pre-existing narrowing task, not a blocker.
Red-teaming this model is its own task (heph `01M0MX04Y8…`).

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

Costs: runners need the `op` CLI (`_1password-cli` in the priv and
nix-container-builder runners' hostPackages on ringtail; homebrew-installed
on indri), and jobs make a network call to 1Password at runtime. With
`OP_SERVICE_ACCOUNT_TOKEN` set, `op` ignores the desktop-app integration,
so the host-mode indri runner never trips a biometric prompt.

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

## The migration (executed 2026-08-22, one PR + human item-copies)

The item map — each a value-copy from the blumeops vault (same
credential, per-purpose item; rotation to fresh values is the easy
follow-up now that it needs no provisioning):

| blumeops-ci item | field | copied from (blumeops) | consumed by |
|------------------|-------|------------------------|-------------|
| `argocd-workflow-bot` | `token` | `w3663ffn…/argocd_token` | `argocd-deploy.yaml` |
| `zot-ci` | `api-key` | `w3663ffn…/zot-ci-api` | `build-container.yaml`; talos + horkos `release.yaml` |
| `fly-deploy` | `token` | `on5slfay…/deploy-token` | `deploy-fly.yaml` |
| `forge-main-push` | `token` | `blumeops-main-push-token/token` | `build-blumeops.yaml`, `cv-deploy.yaml` |

`FORGE_ADMIN_TOKEN`: **not migrated** — first mint a collaborator-scoped
token for agent-repo-access (heph `01KZ5ESS2G…`), then revisit.

**Rotation after migration:** the blumeops-vault originals stay the
human-tier master copies (`mise run fly-deploy` still reads the fly one;
the rest are provenance). Rotating a credential now means updating **both**
copies — the service/master side as before, plus `op item edit` on the
`blumeops-ci` item, which takes effect on the next CI run with no
provisioning. Keep item titles unique in `blumeops-ci`: `op read` resolves
by name, and a duplicate title breaks every consumer of that item (the
`warrant-bot-login` duplicate demonstrated this live).

Rollout order after the PR merges: run
`mise run provision-ringtail` (puts `op` on both ringtail runners), then
`mise run provision-indri -- --tags forgejo_actions_secrets` (syncs
`BLUMEOPS_CI_OP_TOKEN` to talos/horkos, stops syncing the migrated
secrets), verify one dispatch per workflow, and finally delete the stale
Actions secrets (`ARGOCD_AUTH_TOKEN`, `ZOT_CI_API_KEY`,
`FLY_DEPLOY_TOKEN`, `MAIN_PUSH_TOKEN`) from the forge UI or API — the
ansible role only creates/updates, never deletes.

## Related

- [[warrant-approval-gated-runs]] — the program
- [[request-a-privileged-run]] — the request loop these workflows serve
- heph `01KZ0G21JS…` — the tracking task
