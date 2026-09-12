---
title: Talos
modified: 2026-09-12
last-reviewed: 2026-09-12
tags:
  - service
  - ai
---

# Talos

Self-hosted agent workflow service ([[talos-design]]): browser-driven pi agent sessions over OpenRouter models, resumable from any tailnet device, behind [[authentik]] SSO. The non-Anthropic parallel to Claude remote control on [[agent-workspaces]].

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://talos.ops.eblu.me |
| **Tailscale URL** | https://talos.tail8d86e.ts.net |
| **Namespace** | `talos` |
| **Cluster** | ringtail k3s |
| **Image** | `registry.ops.eblu.me/blumeops/talos` (first-party Nix, built from `default.nix` in the talos repo — auto-released on merge to its main) |
| **Source** | https://forge.eblu.me/eblume/talos |
| **Manifests** | `argocd/manifests/talos/` |
| **Port** | 3000 |

## Architecture

Bun server embedding the pi runtime (`pi-coding-agent` SDK): sessions are append-only JSONL trees on the `talos-home` PVC with per-message token/cost data embedded; the browser UI (JSON + SSE) streams responses, renders tool calls, shows per-session cost, and offers two dictation modes (browser SpeechRecognition, or `/api/transcribe` through an OpenRouter audio model). OIDC is a confidential client `talos`, admins only.

**Access model = the [[agent-containerization|containerized agent]] model**: userspace Tailscale sidecar (`talos-agent`, tag:agent) as the only tailnet path, CGNAT egress fence NetworkPolicy, no cluster API, op agents-vault service-account token as the one bootstrap secret, shared hephd spoke socket. Ingress arrives separately via the ProxyGroup (`talos` MagicDNS name) + Caddy.

Models are env-pinned (`TALOS_MODEL`, currently `qwen/qwen3.8-27b`); models newer than pi's catalog are synthesized from OpenRouter's live listing with real pricing so cost tracking stays correct.

The image bakes an **eval-only nix** (following the [[agent-containerization]] §"Nix in the pod" precedent): `$HOME`-relocated store on the PVC, `max-jobs = 0`, swept on size by the entrypoint. It lets the pod compute `fetchgit` hash values for the image's pinned dependencies (heph, npm deps) instead of burning CI rounds on hash-mismatch errors. (The image's own source needs no hash since the auto-release move — the talos repo's `default.nix` builds from the checkout itself, and every merge to talos main releases automatically.)
Rust builds (hephaestus is the only Rust repo in the pool) use a shared `CARGO_TARGET_DIR=/home/talos/.cache/cargo-target` on the PVC, set in the deployment env: one incremental tree for every session and warm across pod replacement, instead of a cold rebuild per worktree leaving a multi-GB `target/` behind (blumeops#813).

## Programmatic API

The API (`POST /api/run`, `/api/crons`, …) trusts two bearer issuers: the
`talos` OIDC client (browser users, minted server-side) and — since
`TALOS_OIDC_M2M_ISSUER` is set — the fleet's shared **`agents-m2m`** machine
identity that `agent-health` already uses. So a script or service drives talos
with the `agents-m2m` credential, no browser session and no talos-specific
secret. A token for the wrong issuer fails `iss`/`aud`, so the second issuer
never widens who the first accepts (talos `src/jwt.ts`, `verifyBearer`).

**No wrapper task by design** — it's just the API. Mint the `agents-m2m` token
the way `agent-health` does, then call talos. The credential is in the
blumeops vault (`agents-m2m-app-password`); it is also in the agents vault, so
this path is reachable from an agent session too. Warrant + human approval
remains the gate on every privileged action, so an agent creating a session or
cron job never escalates — it only spawns more equally-unprivileged work. One
exception: the heph-task watcher kind (below) has a session-facing wrapper,
`mise run talos-wait-for-task`, because a session registers a watcher as its
"waiting on a human" primitive and the wrapper keeps that to one command.

```sh
TOKEN=$(curl -s https://authentik.ops.eblu.me/application/o/token/ \
  -d grant_type=client_credentials -d client_id=agents-m2m \
  -d username=agent-ringtail \
  --data-urlencode "password=$(op read op://blumeops/oor7os5kapczgpbwv7obkca4y4/agents-m2m-app-password)" \
  -d 'scope=openid profile' | jq -r .access_token)

# create the daily doc-review cron (talos#21 — scheduled headless runs)
curl -s -X POST https://talos.ops.eblu.me/api/crons \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"name":"BlumeOps doc review","schedule":{"expr":"0 7 * * *","timezone":"UTC"},"prompt":"…"}'

curl -s https://talos.ops.eblu.me/api/crons -H "Authorization: Bearer $TOKEN"   # list
```

**heph-task watcher (one-shot continuation).** A job whose
`schedule.kind` is `"heph-task"` fires a new session when the watched heph
task reaches a state in `on` (`"done"` and/or `"dropped"`):

```json
{
  "name": "ringtail rebuild follow-up (blumeops#800)",
  "prompt": "The burn-in task is done: verify the GC config and close out #800.",
  "schedule": { "kind": "heph-task", "nodeId": "01M1J1PRRQGYJNTFFZQSZJARMB", "on": ["done"], "expiresAt": "2026-09-13T08:00:00Z" },
  "origin": { "repo": "eblume/blumeops", "issue": 800 }
}
```

- **One-shot semantics.** The job is consumed *before* firing — patched
  `enabled: false` plus `firedReason` in one step — so a failed fire never
  re-fires; the job then stays listed as disabled. Re-arm is an explicit
  `PATCH /api/crons/:id` (re-arm clears `firedReason`); cancel is
  `DELETE /api/crons/:id`. `firedReason` is `condition`, `expired`, or
  `disarmed`.
- **The `talos-watch` tag.** On arm (create or re-arm) talos adds the
  `talos-watch` tag to the watched heph task and exposes `tagApplied: true`
  on the job; the tag is removed on consume, delete, or disable. If the tag
  is gone at poll time, the job is consumed with `firedReason: "disarmed"` —
  removing the tag in heph (the PWA's Unwatch action) is the human-side
  cancel, and it is where the human sees the watcher (not the talos
  dashboard).
- **`expiresAt`** (future ISO timestamp): when it passes, the job fires with
  `firedReason: "expired"` instead of waiting forever.
- **`origin`** (`{repo, issue}`) anchors the spawned session to the origin
  issue; `GET /api/crons` adds the derived `originUrl`.

From an agent pod the wrapper mints the token and routes through the sidecar
itself:

```sh
# register (the prompt comes from a file — the API takes an inline prompt only)
mise run talos-wait-for-task create 01M1J1PRRQGYJNTFFZQSZJARMB \
  --on done --prompt-file ./prompt.md --origin eblume/blumeops#800 \
  --expires 2026-09-13T08:00:00Z
mise run talos-wait-for-task list
mise run talos-wait-for-task show <job-id>
mise run talos-wait-for-task cancel <job-id>
```

From the tailnet-fenced agent pod, route through the sidecar with
`ALL_PROXY=socks5://localhost:1055`. Creating a job in the UI instead needs an
admin browser login.

## Cost accounting

First-class ([[talos-design]]): per-message `Usage` in every transcript, per-session totals in the UI. The OpenRouter key ("openrouter (blumeops)") is a copy of the personal key — replace with a dedicated spend-limited key.

## Related

- [[talos-design]] — architecture and phases (P2 = forge-driven issue→PR runs)
- [[authentik]] — SSO provider
- [[agent-workspaces]] — the Claude-based counterpart
- [[routing]] — Caddy route
