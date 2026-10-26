---
title: Planned Version Development
modified: 2026-10-26
last-reviewed: 2026-10-26
tags:
  - explanation
  - ai
  - process
---

# Planned Version Development

> **Note:** This article was drafted by AI and is pending Erich's review. It
> describes a general process for any planned version of a talos-built component.
> It was distilled from the first series to use it, talos v0.5, which appears
> below **only as an example**. Like every series, v0.5 keeps its own record
> (rows, waves, checkpoints, retrospectives) privately; see *Where things live*.

Planned Version Development (PVD) is how a large, named change to a component
gets built when it's too big for issue-by-issue work (for example, talos v0.5). It
runs in three parts: a **shaping phase** that turns ideas into a dependency-ordered
list of rows, a **write-up** that records the design and the first waves'
issue bodies, and a series of **waves**. Each wave is filed at
once, worked by talos, and closed with a **checkpoint ceremony** in which the
next wave is reshaped against what actually shipped.

This card describes the process only. Each series keeps its own record in
the places listed under *Where things live*.

## Roles

- **Erich** decides: theme, rows, plan go's (or delegates them), merges,
  approvals, and every ceremony outcome.
- **The Claude CLI session** (interim; see below) proposes with a lean, vets talos's plans and
  PRs before they reach Erich, gathers checkpoint stats, and writes up the
  ceremony record. It never crosses a gate that belongs to Erich.
- **Talos** plans and implements each filed Issue: plan → go → PRs → deploy check.
- **horkos** and CI enforce the mechanical gates (pins, warrants, required checks).

### The Claude CLI role is interim

The CLI's role exists because talos can't yet run this process itself. The goal
(talos 1.0, roughly) is a process that unfolds inside talos. Talos would surface
its own queue, vet its own work to the standard the CLI applies today, gather
the checkpoint stats, and walk Erich through each ceremony in the talos UI. When
Erich has a question about talos, he'd ask talos.

Until then, the CLI fills the gaps. Each piece of today's scaffolding is
expected to move:

| Today (Claude CLI) | Expected home in talos |
|---|---|
| `/talos-triage`: the queue walk, one yes/no question at a time | the talos queue and asks in the PWA (engine-written asks with evidence) |
| CLI vetting of plans and PRs before they reach Erich | talos review roles (planner / reviewer models) plus the aspect suite and CI gates |
| Fleet watcher and handler subagents | talos's own event log and transitions (webhook- and classifier-driven) |
| Checkpoint stats gathered by scripts | talos metrics and panels, plus a stats report talos produces at close-out |
| Ceremonies run as CLI sessions | a ceremony flow in the talos UI, writing the series record |
| "Ask the CLI how talos works" | ask talos about itself |

Write each step of this card in terms of *what has to happen*, not *who
does it today*. Then the steps stay valid as their owner moves from the CLI
to talos.

## Where things live

Decided 2026-10-26: **public docs carry the process; the private notes system
(heph) carries every series' specifics.**

The repos are public. A series' working record is full of things that shouldn't
be: spend and budget figures, purchase analysis, private links, and candid notes
about what went wrong. A rule that says "publish, but remember to scrub" fails
the first time someone forgets, so the split is structural.

| Place | Holds |
|---|---|
| This card (public) | The general process: phases, ceremonies, stats definitions, conventions |
| Component repo docs (public) | Design docs for shipped components, written as normal maintained docs. They describe how the thing works, never the series that built it |
| heph (private) | **Every series-specific record:** the series card (theme, principles), the issue list, the wave plan, the issue bodies (drafted per wave), each wave's notes and watch list, checkpoint records and stats, retrospectives, and the live progress log |
| Forge Issues and PRs | Execution: each row is filed as an Issue from its heph body, written so the Issue stands on its own (public repos see it); Human steps live on the Issue |
| Claude memory | Pointers and working-style rules; never the only copy of a decision |

Filing an Issue copies a body from heph into a public tracker, so write bodies
to be publishable: scope, design and done-when, without budget figures or
private links.

> **Example:** talos v0.5 first put its design snapshot and per-wave issue bodies
> into repo docs (2026-10-21), then moved series records back to heph on
> 2026-10-26 when the checkpoint material proved unfit to publish.

## Phase 1: Shaping

Shaping turns "what should change" into rows that can be filed. Most of a
series' leverage comes from it, so give it real time (talos v0.5, for example,
spent about eight days here).

1. **Theme and principles.** One sentence on what the version changes, plus
   the principles every design choice is checked against. (Example, from talos
   v0.5: "talos goes from a clever reader of threads to a system of record with
   hard edges", with the principle that *operator attention and context are
   budgeted resources*.)
2. **Cases.** Real incidents, written as reproducible failure stories. They
   become the characterization fixtures that later rows must turn green.
3. **Scenarios.** End-to-end walkthroughs of real uses, today vs the new version.
   This is where missing rows show up.
4. **Facts.** Source-checked facts about the platform the design depends on
   (e.g. Forgejo's merge, trust and status semantics). A design built on an
   unverified platform claim gets rewritten later.
5. **Brainstorm.** Erich's free-form list of what he wants changed. Each idea is
   mapped into a row, onto existing coverage, or out. **Gate: no filing before
   the brainstorm is walked.**
6. **The issue list.** Rows with stable ids (e.g. `V5-nn` for v0.5), repo, title, blockers and
   status: `ready` / `shape` / `decide` / `decided` / `agreed` / `later` /
   `dropped` / `done`, plus a **Wave** column and a **Filed** column.
7. **The wave plan.** Layer the dependency graph into waves of 3–6 rows, apply
   edge fixes and row splits, name a capability checkpoint after each wave, and
   review it with Erich. After review, the issue list's Wave column becomes
   authoritative.
8. **Clean slate.** Every managed repo reaches no competing major change in
   flight: finish or close what's open. Routine crons keep firing.
9. **Live checks.** Verify the few platform assumptions that can only be
   checked live (in v0.5, for example: the approve-and-run drill, token writes
   and secrets).

## Phase 2: Write-up (Wave 0)

- Write the design notes and **issue bodies a few waves ahead** (v0.5 wrote
  four waves), so early course corrections show up before filing. Both are
  series records, so they live in heph.
- Each body has the same shape: **Repo**, **Blocked on**, **Design**,
  **Assumes** (optional), **Why**, **Scope**, **Done when**, **Out of scope**,
  **Filed**.
- **Assumes** lists the premises the body takes from earlier work, one
  checkable line each (a function, a file, a config value, an earlier row).
  It is a hint for later reconciliation, not a contract: talos doesn't parse or
  rely on it. Like the rest of the body, it is filed publicly, so it stays
  publishable. This convention applies to series bodies only. Ordinary Issues
  stay freeform.
- Wave 0's checkpoint confirms the write-up merged and the live checks hold.
  Then kickoff.

## Phase 3: The wave cycle

Each wave runs **kickoff → execution → close-out → checkpoint ceremony →
reshape**, then the next kickoff.

### Kickoff

1. **Reconcile the bodies against what shipped** (see *Reconciling bodies*
   below). Rewrite any body whose assumptions the last wave changed.
2. **Add the rows the last checkpoint produced.** Write their bodies on the
   wave's card, and add them to the issue list with the wave number.
3. **Apply the tick/tock rule:** everything on the list at kickoff belongs to
   Wave N, including debt carried in from the last wave. Only what comes up
   *during* Wave N becomes Wave N.5.
4. **Write the wave notes at the top of the wave's card:**
   - a *READ FIRST* block for every Claude CLI session in the wave;
   - the **watch list**, with baselines from the last checkpoint;
   - any extra completion-gate checks.
5. **File the whole wave at once.** Express in-wave dependencies with the
   `!!blocked-on: <repo>#<n>` pragma (or its successor), not by filing in
   stages. Waves exist to keep any one dependency chain short.
6. **Record each filing:** replace the body's **Filed** line with the forge link,
   and fill the issue list's Filed column.

### Execution

- Talos plans each Issue. Plan go's come from Erich, or from the CLI under his
  delegation when the plan matches the body. Deviations escalate.
- The CLI vets every plan and PR before it reaches Erich. Each item reaches him as
  one yes/no question with a lean. Hard gates (merges, approvals,
  approve-and-run, warrants) stay his.
- **Fix debt in the wave that found it.** A bug or debt uncovered during Wave N
  is filed and worked in Wave N, labelled N.5, and logged with what uncovered it,
  so per-wave stats stay attributable. Don't propose deferring it.
- Live notes go to the heph progress log: decisions in flight, model and
  capability observations (e.g. the Haiku miss list), cost surprises. Each
  checkpoint harvests them.
- Watch the series' budget line, measured from the provider's bill.

### Close-out gate

- Every Wave N and N.5 Issue is closed or explicitly parked, with a named reason
  and owner.
- Deploys are verified (`argocd app get`, health checks), and the first runs of
  any new scheduled job are green.
- Any extra completion-gate checks listed at kickoff have been run.

### Checkpoint ceremony (introspection)

Run it as its own session, not interleaved with queue triage.

1. **Stats**, the same rows every wave so waves compare (see below), from the
   forge API, Actions runs, talos metrics and session listings.
2. **Reconcile spend against the provider bill.** Never report the internal
   metric alone; an internal estimate can be wrong in either direction.
3. **What's true now:** Erich picks the capability statements the wave made true.
   There's no fixed count.
4. **Checks before the next wave:** the capability checks the wave's card named,
   plus the **control-group line**, if the series has a control lane (v0.5 used the V5-83 lane: "better / same / worse,
   and why").
5. **Reflection items.** Each one ends as exactly one of:
   - a next-wave row;
   - a process change (this card, a skill, a template);
   - a rule (memory or AGENTS.md);
   - a watch-list item;
   - "keep as is" with its data.
6. **Model and budget decisions** against the threshold, with a measured basis
   for the next wave.

### Reconciling bodies

Run this at every kickoff for the wave being filed, and at every checkpoint for
the wave after next, so drift shows up a wave early:

1. **Group the bodies by area,** so reviewers that read the same code share a run.
2. **Fan out one read-only reviewer per group** with a standard brief:
   - the body text, and its **Assumes** lines if any;
   - pointers to what shipped (merged PRs, repos, deployed config).

   The reviewer infers any further premises from the prose and checks each one
   against the code and live state. It reports:
   - what still holds;
   - what's stale, with file and line evidence;
   - concrete replacement text;
   - questions only the operator can answer.

   It posts nothing.
3. **Synthesize** into one table (keep / revise / reshape per body) plus any
   cross-cutting findings.
4. **Apply the mechanical fixes as one batch,** then take the real decisions one
   at a time. Record the table and decisions on the wave's card, then refresh each
   body's **Assumes** lines to match its final shape.

> **Example:** at the talos v0.5 Wave 3 kickoff, five reviewers found that a
> store shipped in the previous wave was never switched on in the server. That
> one finding re-ordered three bodies.

### Reshape

Fold the outcomes into the next wave's card and the issue list, reconcile the
following wave's bodies (*Reconciling bodies*), update the
wave plan if waves move, and revise this card if the process changed. Then
kick off the next wave.

## Standard checkpoint stats

| Row | Source |
|---|---|
| Wave Issues filed / closed (planned, N.5, recurring) | forge issues created in the window, classified |
| Wave PRs (non-pin): merged / abandoned, by repo, per Issue | forge PRs in the window |
| Pin PRs: merged / superseded; release tags | forge PRs, tags |
| Operator acts: approvals, steer reviews, merges, schedules, Update-branch pushes | reviews and timelines by the operator account |
| Approve-and-run clicks | Actions runs with `approved_by` set |
| Plan go's (direct vs delegated) | operator comments matching "Go" |
| Spend: internal metric **and** provider bill, per model and per day | `talos_spend_usd_total`; OpenRouter `/api/v1/activity` (usage + BYOK) |
| Tokens; sessions; turns; turn time | `talos_tokens_total`, `talos_sessions_started_total`, `talos_turn_duration_seconds` |
| Bot prose to read (count, chars, median) | talos comments and PR bodies |
| Red on first completed CI; steer reviews per PR; open → merge time | Actions runs per PR head, reviews |
| CI-failure-triggered sessions | session origins with sender `forgejo-actions` |
| Process restarts (metric caveat) | `resets(talos_process_cpu_seconds_total)` |

Keep the stats scripts in the repo (a mise task), so every checkpoint runs the
same code and nobody has to rediscover them.

## Conventions

- Erich decides; the CLI proposes with a lean. Every decision is recorded
  with its date where it lives (a row, a body, a section of a wave's card).
- One question at a time. A ceremony is a sequence of small decisions, not a
  survey.
- Fetch the data before forming the lean. A reasonable-sounding lean is often
  reversed by the numbers.
- The safe default ships first; relax it later with evidence.
- Prefer removing a mismatch over policing it (e.g. give CI the same userland as
  the agent, rather than lint for the difference).

## Related

- [[agent-change-process]]: how a single agent change lands.
- [[aspects]]: the rule suite waves extend.
- [[warrant-approval-gated-runs]]: the privileged-action gates.
