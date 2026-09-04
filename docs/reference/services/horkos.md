---
title: Horkos
aliases:
  - warrant
modified: 2026-08-20
last-reviewed: 2026-08-20
tags:
  - service
  - ai
  - security
---

# Horkos

The approval broker for agent-requested privileged runs — Phase 3 of
[[warrant-approval-gated-runs]]. Agents file requests; Erich approves in the
UI; Horkos consumes the resulting warrant and dispatches the workflow as
`warrant-bot`. A first-party FastAPI + SQLite service.

**Né Warrant** (renamed + extracted to its own repo 2026-08; Ὅρκος is the
Greek daimon of oaths). The minted approval artifact is still called a
**warrant** — Horkos is the service that mints and consumes them — which is
why `warrant-policy.yaml`, `warrant-bot`, and the `Warrant request: #N` PR
stamp keep their names.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://horkos.ops.eblu.me (tailnet; caddy site) |
| **Namespace** | `horkos` |
| **Source** | https://forge.eblu.me/eblume/horkos (own repo; auto-releases on merge to its main) |
| **Image** | `registry.ops.eblu.me/blumeops/horkos` (locally built Nix, `default.nix` in the horkos repo) |
| **Manifests** | `argocd/manifests/horkos/` — ArgoCD app is **manual sync** (the gate must not redeploy itself) |
| **Storage** | 1Gi PVC (SQLite at `/data/horkos.db` — migrated from warrant's DB, schema unchanged) |
| **Agent auth** | Authentik `agents-m2m` client-credentials JWT (JWKS-verified) |
| **Human auth** | Authentik OIDC code flow (`horkos` client), `admins` group, MFA per the authentik flow |
| **Dispatch identity** | `warrant-bot` PAT (`write:repository` on blumeops), `op://blumeops/warrant-dispatch-token` |

## The flow

```
agent: mise run request-run <workflow> <sha> …
   → policy check (warrant-policy.yaml on blumeops main) → PR comment + heph task
   → POST /api/requests            (agents-m2m JWT)
human: horkos.ops.eblu.me → sign in → read the diff → approve…
   → confirm page (full inputs, commit/PR/diff links)
   → warrant minted: single-use, TTL'd, {action, sha, inputs} frozen
   → consumed → workflow_dispatch as warrant-bot → run recorded on the warrant
```

Denials close the request. Anything already executed should be **denied with
a note** — the queue records intent to execute, not history.

The policy file stays in **blumeops**, deliberately: policy and service live
in different repos, so the autonomy boundary and the code enforcing it can
never change in a single PR.

## API

- `POST /api/requests` — file a request `{action, sha, inputs, why, pr, pr_repo}`
  (Bearer JWT); `pr_repo` is the `owner/name` holding `pr`, default blumeops
- `POST /api/requests/{id}/supersede` `{by}` — retire one's own **pending**
  request in favour of a later one (Bearer JWT)
- `GET  /api/requests[?status=…]`, `GET /api/warrants` — read the queue and the decisions
- `POST /api/requests/{id}/decision` `{decision, note}` — approve/deny (session; `admins`)
- `POST /requests/{id}/decide` — the UI form (CSRF-signed); `GET /requests/{id}/confirm`
- `GET  /healthz` — includes `dispatch: armed | armed-no-token | disarmed`
  and the running version (stamped by the release build via `HORKOS_VERSION`)

## Operating it

- **Deploy**: merge the auto-opened `horkos-release-vX.Y.Z` pin PR, then
  `argocd app sync horkos`. Manual sync is the point — see the Application
  manifest for the reason.
- **Disarm**: set `HORKOS_DISPATCH_ENABLED: "0"` in the deployment and sync.
  The credential stays in place, ignored; decisions still record, and
  dispatch falls back to a human in the forge UI.
- **Check the power is real**: `curl -s https://horkos.ops.eblu.me/healthz` —
  `armed-no-token` means the ExternalSecret isn't resolving (the failure that
  once looked exactly like "disabled").
- **Rotate the dispatch PAT**: `mise run warrant-bot-provision -- --rotate`
  (gilbert; needs an ephemeral `write:admin` token, see the script).
- **Scope**: only actions with `class: warrant` in `warrant-policy.yaml` are
  requestable — today `argocd-deploy.yaml`, `build-container.yaml`,
  `deploy-fly.yaml`.
  `provision-*` is `class: deny` (see [[blumeops-ci-item-migration]]).
- **Test it**: the service suite lives in the horkos repo (`scripts/test`
  there, and its CI). `mise run horkos-test` here covers the blumeops-side
  client tooling (`request-run`, `verify-runs`). Neither needs a forge token,
  cluster, or vault.

## Run attribution

The run a warrant names comes from the dispatch itself. Forgejo's dispatch
endpoint answers 204 with no body by default, but with `return_run_info: true`
in the request body it answers **201** naming the run it created — so there is
nothing to infer, and no window in which an unrelated run could be taken for
ours.

A dispatch that answers any other way — 204 from a forge that ignores the
flag, or a body carrying no run number — leaves `run_number` null and links
the workflow's run list. That is the intended outcome, not a degraded one: a
warrant asserts that a human authorized a *specific* run (invariant 5), so a
confidently wrong link is worse than an honest absence. `dispatched_at` is
recorded alongside, which makes a bad link falsifiable after the fact.

Since v0.3.4, `GET /api/requests` serializes each request's latest warrant
(`decision`, `decided_by`, `run_number`, `run_url`, `dispatched_at`) so the
recorded link is consumable outside the database — `mise run verify-runs`
uses it to close approval tasks against the exact run their approval caused.
Forge-side inference remains only where there is NO recorded warrant link at
all (pre-stamp tasks or a warrant outage). A warrant record without a
`run_number` is reported, never guessed, in three ways: request status
`dispatched` means the dispatch ran but the forge never named the run (a
pre-`return_run_info` forge / 204 answer) — **dispatched-norun**, left for a
human to link or re-dispatch; request status `dispatch_failed` means the
dispatch attempt failed — reported, its reason on the warrant note, left
open; any other run-less status (approved / denied / superseded) was **never
dispatched**, and when the warrant note records the pre-dispatch no-op reason
(` | not dispatched: …`), the sweep surfaces it (eblume/horkos#13). The run
heuristic is refused for all three, never consulted (eblume/horkos#12).

## Superseding

A PR that takes review feedback moves its head SHA, so the request bound to
the old commit is dead on arrival of the new one — but it stays `pending`, and
the queue then shows two near-identical entries with nothing to say which is
live. `POST /api/requests/{id}/supersede {"by": <new id>}` retires the old one:
status `superseded`, with `superseded_by` naming its replacement, rendered in
the UI as `superseded → #N`.

It is the only write an agent identity may make to an existing request, and it
can only ever **reduce** (invariant 4). `superseded` is not `pending`, so the
decision path refuses it: no warrant, no dispatch, no way back. The route is
scoped to the caller's own still-pending requests, so an agent can neither
retire another identity's request nor undo a human's decision.

`mise run request-run <workflow> <sha> --supersedes <id>` is the whole loop
from the agent's seat: file the new request, retire the old one, note the
supersession on its PR comment, and close its heph tracking task (matched by
title *and* the `Warrant request: #<id>` stamp — an ambiguous match closes
nothing and says so).

## Known gaps

- **UI ergonomics** — keyboard patterns, filtering, search, embedded diff
  view (heph `01KZ4NH4MF…`). Approval ergonomics *is* the approve-fatigue
  mitigation, so this is substance, not polish.
- **Hardware-backed approval** — TOTP today; the flow-slug design means a
  WebAuthn stage is an authentik change, not a Horkos change (heph
  `01KZ0G21KZ…`).
- **Secret leasing** — deliberately never built; CI reading its own secrets
  from `blumeops-ci` may make it unnecessary.
- ~~**Stale Authentik leftovers**~~ — done 2026-08-23: the old `Warrant`
  provider/app (left behind because blueprints don't prune) were deleted via
  the Authentik API, alongside the orphaned `warrant` namespace/PVC and the
  ghost dashboard tile. The pre-migration `warrant.db` is parked at
  `ringtail:/root/warrant.db.pre-namespace-delete-2026-08-23`.

## Related

- [[warrant-approval-gated-runs]] — the program, its invariants, and why
- [[request-a-privileged-run]] — the request side, from an agent's seat
- [[blumeops-ci-item-migration]] — the vault tier and what never moves
- [[authentik]] — identity provider (`agents-m2m` and `horkos` blueprints)
