---
title: Talos v0.5 — landing gate (instance)
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
---

# Landing gate (instance)

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

The generic queue design is in talos
[landing-queue.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/landing-queue.md):
advisory PR CI, one required `queue-gate` status posted by a gate workflow
that runs main's definitions, a talos queue brain that is read-only on the
forge, and Forgejo's scheduled merge as the last hop. This page covers how
this instance builds the gate (row V5-28a) and the inputs it feeds the
queue brain (V5-28b).

## Rollout: every managed repo, from `repos.json`

The gate applies to every repo listed in `argocd/manifests/talos/repos.json`
(after V5-62, every repo marked managed). It is not hand-wired per repo:
`forge-reconcile` places the gate's caller workflow, the queue issue and the
branch-protection change on each repo, and `forge-reconcile --check` reports
any managed repo missing one. Adding a repo to `repos.json` is the only step.

The gate's logic lives once, in a reusable workflow in blumeops. Each managed
repo carries a thin caller at `.forgejo/workflows/queue-gate.yaml` (placed by
reconcile) that runs on `issue_comment`, checks the trigger, and calls it.

**Gap found while writing this:** `agents` and `cv` have no rule in
`forge/branch-protections.json` today (12 rules, 14 managed repos). The gate
needs a protection rule on every managed repo to make `queue-gate` required,
so V5-28a adds the two.

## The per-repo queue issue

Each managed repo has one open issue titled `talos landing queue`, created by
reconcile. The talos bot (or eblume) triggers a gate run by commenting a PR
number on it. A comment on a plain issue runs main's workflow definitions
with the repo's write token and secrets, which the gate needs to post a
status.

Checked live 2026-10-21 on a throwaway repo (`eblume/drill-v528`, deleted
after): an `issue_comment` by eblume ran main's workflow with
`ref=refs/heads/main`, the repo secret was visible, and the run's token
created a label (HTTP 201). The case of a read-only commenter (the talos
bot) triggering the run is checked at the Wave 3 checkpoint.

## What the gate checks, in this instance

1. **Trigger author:** the comment is from `talos` or `eblume`; anyone else
   is ignored. The body is parsed for a PR number only.
2. **Approval before candidate code:** eblume has an approving review on the
   PR at its current head SHA. This runs before any candidate code executes,
   because the gate always holds write and secrets (Forgejo ignores
   `permissions:`).
3. **Gate files untouched:** the PR changes none of the gate's own files (the
   reusable workflow, the caller, `forge/branch-protections.json`). Those
   are merged by eblume by hand.
4. **Overlap re-ask:** if main changed any file the PR touches since the
   approval, the approval is stale; the gate refuses and the review ask
   returns.
5. **Test main + PR:** build the merge of current main and the PR head and
   run the repo's checks on it, plus the aspect suite from blumeops main.
6. **Main didn't move:** re-check main's SHA, then post `queue-gate`
   success on the PR head.

A second job runs on push to main and resets `queue-gate` to pending on
every PR the queue holds, so a green status can't outlive the main it was
tested against.

**Serialization:** a workflow-level `concurrency:` group per repo
(`queue-gate-<repo>`, `cancel-in-progress: false`), so gate runs queue
oldest first. Forgejo supports this at workflow level only.

## Branch protection

- `queue-gate` becomes the only required status context on each managed
  repo's `main` rule in `forge/branch-protections.json`. The existing
  PR-triggered checks keep running as advisory runs. `queue-gate` is a
  literal name that no workflow run can produce (Actions statuses are always
  `<workflow> / <job> (<event>)`), so only the gate's API post satisfies it.
- `required_approvals: 1` with the eblume approvals whitelist and
  `dismiss_stale_approvals` is live on all 12 rules (a6013481), so a
  scheduled merge can't land commits pushed after the approval.
- `apply_to_admins: false` is live (5313d0c4), so eblume can "merge anyway"
  his own PRs.
- `block_on_outdated_branch` comes off after the Wave 3 checkpoint, once a
  harmless PR has landed through the gate. Until then it stays, and the gate
  runs alongside today's flow.

## Scheduled merge: the release-kit#8 non-fire

The flow is: eblume approves and schedules "merge when checks succeed";
`queue-gate` arrives later. On release-kit#8, Forgejo's scheduled merge did
not fire when the approval landed after the last status (scheduled, green,
0 behind, approved, never merged); Forgejo re-evaluates a schedule on status
events. Required fix in V5-28a: the gate's final step posts `queue-gate`
only after confirming the approval exists, and if the approval arrives after
`queue-gate` is green, the engine's landing-deadline ask (V5-28b) catches it.
The gate must not depend on the order in which approval and status arrive.

## Main-settled rule: this instance's inputs

The queue brain does not trigger the next gate while any `push` run on
`main` is queued or running, or while the latest run of any auto-apply
workflow failed. In blumeops, the runs that count:

| Workflow | Fires on | What it applies |
|---|---|---|
| `ringtail-rebuild.yaml` | push to main, `nixos/ringtail/**` and friends | all of main to ringtail ([[auto-apply]]) |
| `provision-indri.yaml` | push to main, `darwin/indri/**` and friends | all of main to indri ([[auto-apply]]) |
| `build-container.yaml` | push to main, `containers/**` | images to zot; horkos then opens pin PRs |
| ArgoCD auto-sync | merge touching `argocd/manifests/**` | the app, within the reconcile interval (not a forge run) |

The `paths:` lists in those workflows are the authority; the queue brain
reads them from main rather than this table. ArgoCD auto-sync is not a forge
run, so the rule can't see it; an auto-sync failure surfaces through
`agent-health`, not the queue.

Other managed repos have no auto-apply workflows today; their `push` runs
(release workflows) still count toward "main settled".

## Related

- [[runners-and-trust]] — why the gate never runs PR-chosen runners
- [[aspects]] — the suite the gate runs
- [[warrant-approval-gated-runs]], [[auto-apply]]
