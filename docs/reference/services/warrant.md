---
title: Warrant
modified: 2026-08-02
last-reviewed: 2026-08-02
tags:
  - service
  - ai
  - security
---

# Warrant

The approval broker for agent-requested privileged runs — Phase 3 of
[[warrant-approval-gated-runs]]. **Currently a v0.1 scaffold**: a request
queue with a read-only UI and an agent API, deliberately without an approval
path or any privileged credential. Approvals remain forge-dispatch
([[request-a-privileged-run]]) until v0.2 lands the Authentik passkey
step-up + warrant-minting flow.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://warrant.ops.eblu.me |
| **Namespace** | `warrant` |
| **Image** | `registry.ops.eblu.me/blumeops/warrant` (locally built, `containers/warrant/`) |
| **Manifests** | `argocd/manifests/warrant/` |
| **Storage** | 1Gi PVC (SQLite at `/data/warrant.db`) |
| **Agent auth** | Authentik `agents-m2m` client-credentials JWT (JWKS-verified) |

## API (v0.1)

- `POST /api/requests` — file a request `{action, sha, inputs, why, pr}`
  (Bearer JWT required)
- `GET /api/requests[?status=pending]` — list
- `POST /api/requests/{id}/decision` — **501** by design in v0.1
- `GET /healthz`

## Roadmap to v0.2 (the real broker)

1. Authentik session auth for the UI + WebAuthn/passkey step-up on decisions
   (see the hardware-auth spike, heph `01KZ0G21KZ…`)
2. Approval mints a single-use, TTL'd warrant bound to
   `{action, sha, inputs, secret-scope}`
3. Broker-held dispatch PAT + scoped secret leases (`blumeops-ci` vault)
4. heph mirroring (requests ↔ tasks) and ntfy/push integration
5. `request-run` gains `--broker` to file here instead of (then alongside)
   PR comments

## Related

- [[warrant-approval-gated-runs]] — the program design
- [[request-a-privileged-run]] — the Phase-1 flow this will subsume
- [[authentik]] — identity provider (`agents-m2m` blueprint)
