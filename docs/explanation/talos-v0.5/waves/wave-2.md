---
title: Talos v0.5 — Wave 2 bodies (blumeops)
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
---

# Wave 2 — blumeops bodies

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

Issue bodies for the blumeops rows of Wave 2, drafted before filing. The
wave's full row list and checkpoint are in talos
[waves/wave-2.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/waves/wave-2.md).

## V5-62 — One fork model + complete `repos.json`

**Repo:** blumeops (+ talos audit). Talos half: a check only, below.
**Blocked on:** V5-65 (eligible repos trusted first)
**Design:** [[runners-and-trust]] §One fork model

**Why:** canonical-write repos let talos push branches next to main and run
CI with no consent; a repo absent from `repos.json` is silently unmanaged.

**Scope:**
- `repos.json`: replace `access`/`pool` with one `managed` marker (keep
  `horkos_forge`, `release_hook`, `principals`); add `excluded` (e.g.
  `dotfiles`, archived repos).
- forge-reconcile: talos gets read + a fork on every managed repo, write on
  none; it owns fork creation and fork sync; `--check` fails on any eblume
  repo in neither list.
- The talos entrypoint's pool clone loop reads the new shape (talos PR,
  same Issue): every pool repo is `origin = talos/<repo>`,
  `upstream = eblume/<repo>`.
- Re-confirm the 2026-10-18 audit: no talos server call needs write
  (labels, assignees, statuses, dispatch).
- Update [[principals]] and the `_comment` block.

**Done when:** `forge-reconcile --check` is green with talos at read on all
14 managed repos; a talos PR on a former canonical-write repo comes from
`talos/<repo>` and runs CI under always-trust.

**Out of scope:** the gate (V5-28a); horkos-forge grants.

**Notes for the checkpoint:** after this, every talos PR is a fork PR.
Watch for any former canonical-write repo whose CI needed same-repo
secrets.

**Filed:** —

## V5-32 — Aspect suite skeleton + three pilots

**Repo:** blumeops
**Blocked on:** V5-68, V5-25 (both closed in Wave 0)
**Design:** [[aspects]]

**Why:** durable rules (no new Ansible, no instance config in components,
FODs only download) live in review today and fail silently.

**Scope:**
- `aspects/` with the layout in [[aspects]], a `conftest.py` that
  parametrizes aspects × target repo, and the red-fixture meta-test.
- Pilots, each with red and green fixtures: `no-new-ansible` (ratchet over
  new roles, task files and files under `ansible/`; baseline = today),
  `instance-config-out-of-components` (invariant over talos/horkos `src/`
  and prompt strings), `fod-only-downloads` (invariant).
- `mise run aspects [--repo PATH]` runs the suite locally; a blumeops PR job
  runs it against blumeops itself on `indri-build`.
- Budgets enforced (10 s/test, 2 min/repo).

**Done when:** each pilot's red fixture goes red and green goes green in CI;
the meta-test fails an aspect with no red fixture; the suite runs clean on
blumeops main (ratchet at baseline).

**Out of scope:** other repos' CI wiring (V5-33); the nightly sweep (V5-33).

**Notes for the checkpoint:** V5-83 children must stay under the ratchet
(removal only).

**Filed:** —
