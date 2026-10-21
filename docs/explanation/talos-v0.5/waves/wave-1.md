---
title: Talos v0.5 — Wave 1 bodies (blumeops)
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
---

# Wave 1 — blumeops bodies

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

Issue bodies for the blumeops rows (and blumeops halves) of Wave 1, drafted
before filing. At filing, each section is replaced by its forge link. The
wave's full row list and checkpoint are in talos
[waves/wave-1.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/waves/wave-1.md).

## V5-65 — Approve-and-run: always trust talos on eligible repos

**Repo:** blumeops (docs) + forge UI clicks. Talos half: none.
**Blocked on:** —
**Design:** [[runners-and-trust]]; talos [landing-queue.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/landing-queue.md)

**Why:** approve-and-run on every talos PR trains rubber-stamping. On repos
whose PRs can reach no repo-scoped runner, the click protects nothing that
`indri-build` doesn't already expose. V5-62 (Wave 2) needs it first.

**Scope:**
- eblume clicks "approve and always trust" for `talos` once on each eligible
  repo: agents, cv, release-kit; and the canonical-write repos
  (hephaestus.nvim, research, myeve, timberborn-parsimony, gamedev,
  project-template, RexWorks) on their first fork PR after V5-62.
- Update [[runners-and-trust]] if the eligible list changed since it was
  written (re-derive from `forge/runners.json` × `repos.json`).
- Add the do-not-click list (blumeops, horkos, hephaestus, talos) and the
  90-day expiry to [[runbook-forgejo-ci]].

**Done when:** a talos PR on agents, cv and release-kit each runs CI with no
click; the runbook names the do-not-click list and the risk surface.

**Out of scope:** moving privileged or host-mode runners out of PR reach;
any automation of the trust setting (no API exists).

**Filed:** —

## V5-59 — Operator reading budget: baseline panel (blumeops half)

**Repo:** blumeops. Talos half: see talos `docs/design/v0.5/waves/wave-1.md`
(the measurement and its metrics).
**Blocked on:** —
**Design:** talos [context-and-prompts.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/context-and-prompts.md)

**Why:** v0.5 claims to cut what the operator must read. Without a baseline
taken before anything changes, that claim can't be checked.

**Scope:**
- A "Reading budget" row on the talos dashboard
  (`argocd/manifests/grafana-config-ringtail/dashboards/configmap-talos.yaml`),
  next to the output-share panels: characters the operator must read per
  ask and per Issue (bot comments, PR bodies, Human-steps text), and ask age
  by kind.
- Panels read only the metrics the talos half exports. Labels from bounded
  sets only; no Issue number as a label.

**Done when:** the panels render today's numbers from the talos half's
metrics, dashboard source-controlled.

**Out of scope:** alerts (metrics, not alerts); targets (set once the
baseline exists).

**Filed:** —

## V5-21 — Executor sidecar (blumeops half: manifests)

**Repo:** blumeops. Talos half: see talos `docs/design/v0.5/waves/wave-1.md`
(executor protocol and tool routing).
**Blocked on:** — (lands with or after the talos half's image)
**Design:** talos [sandbox.md](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/sandbox.md)

**Why:** a session today shares uid 1500 with the server, can read
`/proc/<server>/environ` (OpenRouter key, OIDC client secret, webhook secret,
op token) and writes `data/`. The work-item store can't go live (V5-06)
until sessions run elsewhere.

**Scope:**
- `argocd/manifests/talos/deployment.yaml`: an `executor` container in the
  talos pod, its own uid (e.g. 1600), no `env`/`envFrom` secrets, no
  service-account token (`automountServiceAccountToken: false` on the
  container's projected volume or the pod, keeping the server's needs),
  all capabilities dropped, `allowPrivilegeEscalation: false`.
- Mounts: session worktrees and pool clones only (`home` PVC `subPath`s),
  never `data/`, `.config` or anything holding the op token; a shared
  `emptyDir` for the executor socket.
- No `shareProcessNamespace`, so the server's `/proc` stays invisible.
- `fix-home-ownership` init container: ownership for the executor's
  subPaths.

**Done when:** in the deployed pod, from the executor: reading
`/proc/<server pid>/environ` fails, writing `data/` fails, and a session's
tool calls run there (talos half's probe).

**Out of scope:** Landlock (V5-22, Wave 2); credential broker (V5-23); heph
socket removal (V5-67, Wave 10).

**Filed:** —
