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

## Cost accounting

First-class ([[talos-design]]): per-message `Usage` in every transcript, per-session totals in the UI. The OpenRouter key ("openrouter (blumeops)") is a copy of the personal key — replace with a dedicated spend-limited key.

## Related

- [[talos-design]] — architecture and phases (P2 = forge-driven issue→PR runs)
- [[authentik]] — SSO provider
- [[agent-workspaces]] — the Claude-based counterpart
- [[routing]] — Caddy route
