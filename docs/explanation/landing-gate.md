---
title: Landing gate (queue-gate)
modified: 2026-10-27
last-reviewed: 2026-10-27
tags:
  - explanation
  - ai
  - design
  - security
---

# Landing gate (queue-gate)

`queue-gate` is an advisory landing check on `eblume/talos`, not a required
check. It tests main plus an approved PR once, at landing. Tracking issue:
[eblume/talos#473](https://forge.ops.eblu.me/eblume/talos/issues/473).

## What it checks, in order

- **Trigger:** an `issue_comment` run. `decide` runs only when
  `github.event.issue.number == vars.QUEUE_GATE_ISSUE`, the action is `created` and the
  comment is not on a PR. The issue is identified by the `QUEUE_GATE_ISSUE` repo
  variable, not by its title. Every other comment starts a run whose jobs all skip.
  The three repo variables are `QUEUE_GATE_OWNER_ID`, `QUEUE_GATE_BOT_ID` and
  `QUEUE_GATE_ISSUE`.
- **Decide (before any candidate code):** the commenter's user id must be
  `QUEUE_GATE_OWNER_ID` or `QUEUE_GATE_BOT_ID`. The body must be a bare PR number. The
  PR must be open against main and must not touch a gate file. eblume's newest
  decisive review must be a non-dismissed approval at exactly the head SHA. The PR
  must not overlap files main changed since the merge-base of the head and main. That
  is a superset of "since the approval", so it can only refuse more.
- **Candidate:** lint, test and typecheck run on `indri-build` only, against main plus
  the approved SHA. The PR head is fetched by ref and refused unless it equals the
  approved SHA. Token variables are blanked per step and asserted empty.
- **Post:** re-reads main, head and approval, and posts the `queue-gate` status only if
  none of them moved.

Every refusal prints `REFUSED: <why>` to the run log and posts no status.

**Reset** (`queue-gate-reset`) runs on push to main and hourly at :17. It shares the
`queue-gate-talos` concurrency group and moves only a *green* newest `queue-gate` on
an open PR to pending, so a scheduled merge cannot ride a stale green.

A green `queue-gate` means "tested against main M and approved at A". The engine's
scheduling rule decides what to do with it.

**Concurrency:** `queue-gate-talos`, `cancel-in-progress: false`.

`queue-gate` is **not** a required context. Branch protection is unchanged.

## Known limit

Candidate code shares the `indri-build` user and home with the gate's write-token
jobs. That makes `queue-gate` advisory against approved-but-hostile code. This is a
design limit, not a bug. It must be revisited before any required-check rollout.

## Forgejo facts

| Fact | Source (v16.0.6) |
|------|------------------|
| Comment-triggered runs use the default branch's workflow | `services/actions/notifier_helper.go` |
| The notifier does not gate on the commenter's permission, so a read-only bot comment starts a run | `services/actions/notifier_helper.go` |
| A run from a non-fork-PR task gets a write token; fork-PR tasks do not | `models/perm/access/repo_permission.go` |
| A run whose jobs all skip does not queue or supersede in a `cancel-in-progress: false` group | [PR eblume/talos#483, fix at 19fd249 and 4d2d717](https://forge.ops.eblu.me/eblume/talos/pulls/483#issuecomment-35220) |
