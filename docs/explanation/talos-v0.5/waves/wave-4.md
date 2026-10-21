---
title: Talos v0.5 — Wave 4 bodies (blumeops)
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
---

# Wave 4 — blumeops bodies

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

Issue bodies for the blumeops rows of Wave 4, drafted before filing. The
wave's full row list and checkpoint are in talos
[waves/wave-4.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/waves/wave-4.md).

**Overlap flag:** V5-33 and V5-28a both write every repo's CI through
reconcile, which is why they sit a wave apart.

## V5-33 — Aspects in every managed repo's PR CI, plus a nightly sweep

**Repo:** blumeops (rolled to every managed repo by reconcile)
**Blocked on:** V5-32, V5-62
**Design:** [[aspects]] §How it reaches every repo

**Why:** an aspect that only runs in blumeops can't hold a rule that spans
repos. A new repo must be covered with no extra step.

**Scope:**
- A reusable advisory workflow in blumeops, and a caller on every managed
  repo placed by forge-reconcile: on `pull_request`, check out blumeops
  `aspects/` at main and run the aspects whose filters match. Runs on
  `indri-build`, read token, no secrets.
- The gate (V5-28a) runs the same suite on the candidate.
- Nightly sweep: every aspect against every managed repo's main. Output per
  [[aspects]]'s open question; lean: a Grafana panel of violations by
  aspect and repo, until the tally board (V5-53) takes findings.
- `forge-reconcile --check` reports a managed repo missing the caller.

**Done when:** a PR in a non-blumeops repo that adds an Ansible role fails
`no-new-ansible`; a repo added to `repos.json` gets the caller on the next
reconcile; the sweep runs nightly within budget.

**Out of scope:** new aspects; the tally board.

**Filed:** —

## V5-88 — Session loop and stall detection (blumeops half: panels)

**Repo:** blumeops. Talos half: see talos `docs/design/v0.5/waves/wave-4.md`
(the guard, the fixture).
**Blocked on:** V5-01, V5-06
**Design:** talos [context-and-prompts.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/context-and-prompts.md) §Loop and stall detection

**Scope:**
- Talos dashboard panels: max identical-call run per session (distribution),
  sessions ended without a step result, guard nudges and parks over time.

**Done when:** the panels show the replayed blumeops#1628 fixture's 209-call
run in a test environment or the live guard's first nudge.

**Out of scope:** ntfy alerts (metrics, not alerts).

**Filed:** —
