---
title: Talos
modified: 2026-08-14
last-reviewed: 2026-08-14
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
| **Image** | `registry.ops.eblu.me/blumeops/talos` (first-party Nix, `containers/talos/`) |
| **Source** | https://forge.eblu.me/eblume/talos |
| **Manifests** | `argocd/manifests/talos/` |
| **Port** | 3000 |

## Architecture

Bun server embedding the pi runtime (`pi-coding-agent` SDK): sessions are append-only JSONL trees on the `talos-home` PVC with per-message token/cost data embedded; the browser UI (JSON + SSE) streams responses, renders tool calls, shows per-session cost, and offers two dictation modes (browser SpeechRecognition, or `/api/transcribe` through an OpenRouter audio model). OIDC is a confidential client `talos`, admins only.

**Access model = the [[agent-containerization|containerized agent]] model**: userspace Tailscale sidecar (`talos-agent`, tag:agent) as the only tailnet path, CGNAT egress fence NetworkPolicy, no cluster API, op agents-vault service-account token as the one bootstrap secret, shared hephd spoke socket. Ingress arrives separately via the ProxyGroup (`talos` MagicDNS name) + Caddy.

Models are env-pinned (`TALOS_MODEL`, currently `qwen/qwen3.8-max`); models newer than pi's catalog are synthesized from OpenRouter's live listing with real pricing so cost tracking stays correct.

The image bakes an **eval-only nix** (following the [[agent-containerization]] §"Nix in the pod" precedent): `$HOME`-relocated store on the PVC, `max-jobs = 0`, swept on size by the entrypoint. It lets the pod compute `fetchgit`/`srcHash` values for its own image bumps instead of burning warrant-approved build rounds on hash-mismatch errors — builds stay impossible by construction.

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
cron job never escalates — it only spawns more equally-unprivileged work.

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
