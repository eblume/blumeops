---
title: Talos — self-hosted agent workflow service (design)
modified: 2026-08-14
last-reviewed: 2026-08-14
tags:
  - explanation
  - ai
  - design
---

# Talos — self-hosted agent workflow service

Talos is a planned first-party service that replicates the *shape* of Claude
remote control — a real coding agent whose session lives on our
infrastructure, driven from any browser on the tailnet — without depending on
Anthropic's relay, and with model freedom via OpenRouter. Named for the
bronze automaton.

## Why

Two pressures converged:

1. **Claude remote control's relay is fragile and not ours.** WAN blips kill
   the websocket with no client-side retry (the [[agent-workspaces|agent-ws]]
   liveness probe exists to recycle exactly this failure); when it breaks we
   can only restart. The session layer is the part we can't fix because we
   don't own it.
2. **Model diversity.** OpenRouter gives access to open-weight models (Qwen
   et al.) at commodity prices; nothing in our agent workflow should be
   welded to one vendor.

A plain chat UI (Open WebUI — evaluated and rejected, PR #562) proves
nothing we care about: the value is agency + owned sessions, not chat.

## Architecture

Runner/driver separation. The **runner** is reusable; drivers are thin.

```
 browser (any tailnet device, Authentik login)
      │  wss:// (cookie auth at upgrade)
      ▼
 talos.ops.eblu.me ──Caddy──► talos.tail8d86e.ts.net (ProxyGroup ingress)
      │
      ▼
 ┌─ talos pod (agent-ws parity) ─────────────────────────────┐
 │  talos server (Bun/TS)                                    │
 │    ├─ static SPA (pi-web-ui + pi-client over WebSocket)   │
 │    ├─ OIDC (confidential client `talos`, admins only)     │
 │    ├─ WebSocket ⇄ framed-CBOR bridge (PiServerListener)   │
 │    ├─ pi-server + pi-coding-agent runtime                 │
 │    │    └─ models via pi-ai → OpenRouter (+ollama later)  │
 │    └─ SQLite session store (PVC) — durable transcripts    │
 │  ts sidecar (userspace, tag:agent, SOCKS 1055)            │
 │  egress netpol blocks 100.64.0.0/10 (sidecar-only tailnet)│
 │  workspace PVC: author-only blumeops clone + scratch      │
 │  op service-account token → agents vault (runtime creds)  │
 │  heph spoke socket (hostPath)                             │
 └───────────────────────────────────────────────────────────┘
```

**Driver 1 (interactive, first):** the SPA. Session list, streaming chat,
tool-call rendering, interrupt/steer, resume from any device. pi-client's
lease model (exclusive for the driver, shared for observers) and
authoritative snapshots give reconnect semantics for free — the exact thing
the Anthropic relay lacks from our side.

**Driver 2 (forge loop, later):** a Forgejo workflow/webhook consumer that
runs the same runner headless from a labeled issue or PR comment and outputs
a PR, iterating on review comments. Shares the session store, so headless
runs get browsable transcripts in the web UI. This is the
[[agent-change-process|change-process]]-native mode and the long-term
payoff; the interactive driver doubles as its debugging console.

## Access model

Deliberately identical to [[agent-containerization|agent-ws]]: same tailnet
identity class (`tag:agent` via userspace sidecar), same egress netpol, no
cluster API, one bootstrap secret (op service-account token for the agents
vault), author-only fork/PR git posture with the `agents` bot. Talos gets
*ingress* (which agent-ws lacks) via the standard ProxyGroup + Caddy chain;
ingress and the egress lockdown are independent directions.

Secrets: `talos-client-secret` field on "Authentik (blumeops)";
`"openrouter (blumeops)"` item for the model API key (initially a copy of
the personal key — **replace with a dedicated spend-limited key**).

## Cost accounting (first-class)

Every session answers "what did this cost?" This is a requirement, not a
nice-to-have, and it shapes the data model:

- **Per-message:** pi-ai attaches `Usage` (tokens + a cost breakdown) to
  every assistant message, computed via `calculateCost()` from catalog
  pricing. Persisting messages verbatim in the session store persists cost.
- **Per-session:** aggregate over the transcript (SQL sum in the session
  repository); surfaced in the session list and as a running total in the
  chat UI. Forge-driven runs report their cost in the PR they produce.
- **Reconciliation:** catalog-computed cost is an estimate. An async job
  reconciles against OpenRouter's billed numbers (`/api/v1/generation` per
  response id, `/api/v1/auth/key` usage counter) so drift is visible.
- **Boundary:** the OpenRouter key itself carries a provider-side spend
  limit — the app-level ledger is observability, not enforcement.

## Key dependencies and risks

- **pi (badlogic/pi-mono, npm scope `@earendil-works`)** supplies the agent
  runtime (`pi-coding-agent`, `pi-agent-core`), multi-provider LLM layer
  (`pi-ai`), remote-session protocol (`pi-server`/`pi-protocol`/`pi-client`,
  framed CBOR, transport-agnostic), SQLite session backend, and browser chat
  components (`pi-web-ui`). The server/protocol packages are marked
  **experimental** — pin exact versions, expect churn. `pi-web-ui` lags the
  other packages; treat as convenience, not contract.
- **Supply chain:** npm-installed for the prototype (locked via lockfile).
  Before production, mirror pi-mono on the forge per [[spork-strategy]]
  conventions and decide whether to vendor or spork.
- **Container build:** first-party Nix `dockerTools` image per policy. Bun
  packaging in Nix is the open question (options: `bun build --compile`
  standalone binary; node-compatible build; nixpkgs bun + fetched
  node_modules). Resolve during Phase 1.
- **Cost control:** default model is cheap (`qwen/qwen3.6-27b` until
  `qwen/qwen3.8-27b` lands on OpenRouter; `qwen3.8-max` selectable), and the
  OpenRouter key should carry a provider-side spend limit.

## Phases

- **P0 — local prototype (gilbert):** repo `eblume/talos` on the forge;
  pi runner + WebSocket bridge + minimal UI running locally against
  OpenRouter; prove create/resume/steer from two browsers.
- **P1 — deploy:** Nix image, k8s manifests (agent-ws parity + ingress),
  Authentik client, Caddy route, docs/service card.
- **P2 — forge driver:** issue/comment-triggered headless runs producing
  PRs; warrant-gated privileged actions unchanged.

## Related

- [[agent-containerization]] — the access model being mirrored
- [[agent-workspaces]] — the Claude-based counterpart
- [[agent-change-process]] — the process the forge driver automates
- [[federated-login]] — Authentik SSO
