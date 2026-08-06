---
title: Warrant
modified: 2026-08-06
last-reviewed: 2026-08-06
tags:
  - service
  - ai
  - security
---

# Warrant

The approval broker for agent-requested privileged runs — Phase 3 of
[[warrant-approval-gated-runs]]. Agents file requests; Erich approves in the
UI; Warrant consumes the resulting warrant and dispatches the workflow as
`warrant-bot`. A first-party FastAPI + SQLite service.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://warrant.ops.eblu.me (tailnet; caddy site) |
| **Namespace** | `warrant` |
| **Image** | `registry.ops.eblu.me/blumeops/warrant` (locally built, `containers/warrant/`) |
| **Manifests** | `argocd/manifests/warrant/` |
| **Storage** | 1Gi PVC (SQLite at `/data/warrant.db`) |
| **Agent auth** | Authentik `agents-m2m` client-credentials JWT (JWKS-verified) |
| **Human auth** | Authentik OIDC code flow, `admins` group, MFA per the authentik flow |
| **Dispatch identity** | `warrant-bot` PAT (`write:repository` on blumeops), `op://blumeops/warrant-dispatch-token` |

## The flow

```
agent: mise run request-run <workflow> <sha> …
   → policy check (warrant-policy.yaml on main) → PR comment + heph task
   → POST /api/requests            (agents-m2m JWT)
human: warrant.ops.eblu.me → sign in → read the diff → approve…
   → confirm page (full inputs, commit/PR/diff links)
   → warrant minted: single-use, TTL'd, {action, sha, inputs} frozen
   → consumed → workflow_dispatch as warrant-bot → run recorded on the warrant
```

Denials close the request. Anything already executed should be **denied with
a note** — the queue records intent to execute, not history.

## API

- `POST /api/requests` — file a request `{action, sha, inputs, why, pr}` (Bearer JWT)
- `GET  /api/requests[?status=…]`, `GET /api/warrants` — read the queue and the decisions
- `POST /api/requests/{id}/decision` `{decision, note}` — approve/deny (session; `admins`)
- `POST /requests/{id}/decide` — the UI form (CSRF-signed); `GET /requests/{id}/confirm`
- `GET  /healthz` — includes `dispatch: armed | armed-no-token | disarmed`

## Operating it

- **Disarm**: set `WARRANT_DISPATCH_ENABLED: "0"` in the deployment and sync.
  The credential stays in place, ignored; decisions still record, and
  dispatch falls back to a human in the forge UI.
- **Check the power is real**: `curl -s https://warrant.ops.eblu.me/healthz` —
  `armed-no-token` means the ExternalSecret isn't resolving (the failure that
  once looked exactly like "disabled").
- **Rotate the dispatch PAT**: `mise run warrant-bot-provision -- --rotate`
  (gilbert; needs an ephemeral `write:admin` token, see the script).
- **Scope**: only actions with `class: warrant` in `warrant-policy.yaml` are
  requestable — today `argocd-deploy.yaml`, `build-container.yaml`,
  `deploy-fly.yaml`.
  `provision-*` is `class: deny` (see [[blumeops-ci-item-migration]]).
- **Test it**: `mise run warrant-test` — unit tests over
  `containers/warrant/app/main.py`. No forge token, cluster, or vault, so it
  runs from an agent pod as readily as from gilbert.

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

## Known gaps

- **UI ergonomics** — keyboard patterns, filtering, search, embedded diff
  view (heph `01KZ4NH4MF…`). Approval ergonomics *is* the approve-fatigue
  mitigation, so this is substance, not polish.
- **Hardware-backed approval** — TOTP today; the flow-slug design means a
  WebAuthn stage is an authentik change, not a Warrant change (heph
  `01KZ0G21KZ…`).
- **Secret leasing** — deliberately never built; CI reading its own secrets
  from `blumeops-ci` may make it unnecessary.

## Related

- [[warrant-approval-gated-runs]] — the program, its invariants, and why
- [[request-a-privileged-run]] — the request side, from an agent's seat
- [[blumeops-ci-item-migration]] — the vault tier and what never moves
- [[authentik]] — identity provider (`agents-m2m` and `warrant` blueprints)
