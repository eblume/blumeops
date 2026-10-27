---
title: Landing gate (queue-gate pilot)
modified: 2026-10-27
last-reviewed: 2026-10-27
tags:
  - explanation
  - ai
  - design
  - security
---

# Landing gate (queue-gate pilot)

An advisory pilot on `eblume/talos` only (V5-28a, [eblume/talos#473](https://forge.ops.eblu.me/eblume/talos/issues/473)).
A gate that tests main plus an approved PR once, at landing, is what would let
`block_on_outdated_branch` come off: today every merge stales every other open
PR. The pilot proves the mechanism on one busy repo before anything else.

## What it does

- **Trigger:** an `issue_comment` on the repo's `talos landing queue` issue whose
  body is a bare PR number. Other comments start a run whose `decide` job skips.
- **Decide (before any candidate code):** the commenter's user id is checked
  against repo variables (`QUEUE_GATE_OWNER_ID`, `QUEUE_GATE_BOT_ID`); the PR must be
  open against main and must not touch a gate file; eblume's newest decisive review
  must be a non-dismissed approval at exactly the head SHA; the PR must not overlap
  files main changed since the merge-base.
- **Candidate:** lint, test and typecheck on `indri-build` only, against main plus the
  approved SHA. The PR head is fetched by ref and refused unless it equals the
  approved SHA. Token variables are blanked per step and asserted empty.
- **Post:** re-reads main, head and approval; posts the `queue-gate` status only if
  none moved. A push to main resets green `queue-gate` statuses on open PRs to pending
  (`queue-gate-reset`, also hourly as a safety net).
- **Concurrency:** `queue-gate-talos`, `cancel-in-progress: false`.

`queue-gate` is **not** a required context. Branch protection is unchanged.

## Forgejo facts (v16.0.6)

The earlier design cited v16.0.2. These are re-read against the v16.0.6 source;
the live drills confirm them.

| Fact | Source reading (v16.0.6) | Live drill |
|------|--------------------------|------------|
| Comment-triggered runs use the default branch's workflow | `services/actions/notifier_helper.go` | pending |
| The notifier does not gate on the commenter's permission, so a read-only bot comment starts a run | `services/actions/notifier_helper.go` | pending (drill c) |
| A run from a non-fork-PR task gets a write token; fork-PR tasks do not | `models/perm/access/repo_permission.go` | pending (drill d) |
| A run whose jobs all skip does not queue or supersede in a `cancel-in-progress: false` group | `services/actions` concurrency handling | pending |

## Pilot log

One row per talos landing while the pilot runs. Columns: PR, trigger → status
time, gate outcome, whether the gate caught something CI on the PR did not.

| PR | Trigger → status | Gate outcome | Caught something CI missed? |
|----|------------------|--------------|-----------------------------|
| — | — | — | — |

## Drills

Recorded on [eblume/talos#473](https://forge.ops.eblu.me/eblume/talos/issues/473):

- (a) harmless talos PR, green `queue-gate` on its approved SHA, scheduled after green, lands.
- (b) forged trigger from a non-allowlisted user: the run may appear, but refuses before any candidate job and posts no status.
- (c) talos-bot (read-only) trigger comment: runs the gate, or the failure is documented.
- (d) `queue-gate` status posting on a fork-PR head works from the base repo.

The pilot runs for at least a week of talos landings before the Wave 3 ceremony
decides what comes next.
