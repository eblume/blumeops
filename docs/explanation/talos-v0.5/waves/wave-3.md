---
title: Talos v0.5 — Wave 3 bodies (blumeops)
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
---

# Wave 3 — blumeops bodies

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

Issue bodies for the blumeops rows of Wave 3, drafted before filing. The
wave's full row list and checkpoint are in talos
[waves/wave-3.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/waves/wave-3.md).

**Overlap flag:** V5-05 edits the borgmatic role that V5-83 group 8 retires.
Keep the two apart: if group 8 is open, V5-05 waits.

## V5-05 — Back up the talos store with a consistent snapshot

**Repo:** blumeops (+ talos if the engine writes the snapshot)
**Blocked on:** V5-04 (store interface)
**Design:** talos [event-log.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/event-log.md) §Retention; [[borgmatic]]

**Why:** the store is WAL-mode SQLite; tarring the live file can tear. The
retention pillar requires the snapshot in the forever archive.

**Scope:**
- Get a consistent snapshot (`.backup` or `VACUUM INTO`) into the
  `talos-data` borgmatic config (forever, append-only, never pruned), not the
  rotating operational one.
- Decide in the plan: (a) the engine writes `VACUUM INTO` a snapshot file on
  a schedule and the existing `talos-data` tar carries it, with the live DB
  files excluded; or (b) a `borgmatic_k8s_sqlite_dumps`-style entry for
  talos-data (the talos image may lack `sqlite3`/`python3` for the
  endpoint's in-pod `.backup`). Lean: (a).
- Restore drill documented on [[talos]]: restore the snapshot into a scratch
  dir and open it.

**Done when:** a nightly `talos-data-*` archive contains a snapshot that
opens and passes `PRAGMA integrity_check`; the restore drill ran once.

**Out of scope:** reading backups from any feature (backups are never on the
critical path).

**Filed:** —

## V5-28a — Gate workflow (`queue-gate`) on every managed repo

**Repo:** blumeops (rolled to every managed repo by reconcile)
**Blocked on:** V5-25, V5-27 (Wave 0), V5-62
**Design:** [[landing-gate]]; talos [landing-queue.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/landing-queue.md)

**Why:** every merge makes every other open PR stale, and each rebase costs
a click, a wait and a re-approval. The gate tests main + PR once, at landing.

**Scope:**
- A reusable gate workflow in blumeops and a thin `queue-gate.yaml` caller
  on `issue_comment`, placed on every managed repo by forge-reconcile.
- Per-repo `talos landing queue` issue, created by reconcile.
- Checks in order: trigger author (talos or eblume, number only); eblume's
  approval at head **before** any candidate code runs; gate files untouched;
  overlap re-ask (main changed a touched file since approval → refuse);
  test main + PR plus aspects; main unmoved → post `queue-gate`.
- Push-to-main job resets `queue-gate` to pending on queued PRs.
- Workflow-level `concurrency: queue-gate-<repo>`, `cancel-in-progress:
  false`.
- `forge/branch-protections.json`: `queue-gate` added as a required context;
  add rules for `agents` and `cv` (missing today).
- The release-kit#8 fix: approval and `queue-gate` may arrive in either
  order; the gate must not assume approval first.

**Done when:** a harmless PR lands through the gate with the approval given
*after* `queue-gate` went green; a forged trigger comment from another user
starts nothing; a talos-bot (read-only) trigger comment runs the gate.

**Out of scope:** the engine queue brain (V5-28b, Wave 9); dropping
`block_on_outdated_branch` (after the Wave 3 checkpoint).

**Notes for the checkpoint:** from here, v0.5 PRs land through the gate
(eblume or talos comments the PR number by hand).

**Filed:** —

## V5-58 — Next aspects: log-only handlers, red fixtures for every guard

**Repo:** blumeops
**Blocked on:** V5-32
**Design:** [[aspects]] §Next aspects

**Scope:**
- `no-log-only-error-handlers` (ratchet): semgrep over horkos/talos
  TypeScript; a catch that only logs must re-raise, alert or return an
  error. Baseline = today.
- `every-guard-has-a-red-fixture` (ratchet): over `prek.toml` and
  `.forgejo/` in pool repos, each hook/check has a test showing it fail.
- Red and green fixtures for both.

**Done when:** both red fixtures go red in CI; both run clean at baseline on
every repo they target.

**Out of scope:** fixing existing violations (the baseline holds them).

**Filed:** —

## V5-94 — Event log mirrored to Loki (blumeops half)

**Repo:** blumeops. Talos half: see talos `docs/design/v0.5/waves/wave-3.md`.
**Blocked on:** V5-04
**Design:** talos [event-log.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/event-log.md) §Loki mirror

**Scope:**
- Confirm `alloy-ringtail` already ships talos pod stdout to Loki (it
  collects pod logs cluster-wide); add a `stage.json` / label rule only if
  needed so event lines are queryable by `event_kind` without Issue or ask
  ids becoming Loki labels.
- A saved Grafana Explore query or dashboard panel: "events by kind, last
  7 days".

**Done when:** a LogQL query returns one line per recorded event with the
JSON fields parsed; Loki labels stay bounded.

**Out of scope:** any talos read path from Loki.

**Filed:** —
