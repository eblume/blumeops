---
title: Why GitOps
modified: 2026-09-07
last-reviewed: 2026-09-07
tags:
  - explanation
  - philosophy
---

# Why GitOps?

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

BlumeOps uses GitOps principles for managing personal infrastructure. This might seem like overkill for a homelab, but there are good reasons. GitOps is more than a deployment preference here — it is the central pillar that the stack, and the agent systems built on top of it, are designed around.

## The Problem with Manual Infrastructure

Traditional server management involves SSHing into machines and running commands. This works, but creates problems:

- **Drift**: The actual state diverges from what you think it is
- **Amnesia**: You forget what you changed and why
- **Fragility**: One bad command can break things with no easy rollback
- **Bus factor**: Only you know how it works (even AI assistants struggle without context)

## Git as the Source of Truth

GitOps inverts the model: instead of pushing changes to servers, you commit desired state to Git, and automation pulls it into reality.

**Benefits:**
- Every change is tracked with commit history
- Pull requests enable review before deployment
- Rollback is just `git revert`
- The repo *is* the documentation

## Why This Matters for a Homelab

A personal homelab isn't a production environment, but it shares the same challenges:

1. **Memory is unreliable** - Six months from now, you won't remember why you configured Caddy that way
2. **Experimentation is constant** - You try things, break things, want to undo things
3. **AI assistance needs context** - Claude can help much more effectively when it can read your infrastructure as code

## The BlumeOps Approach

BlumeOps uses layered GitOps:

| Layer | Tool | What it manages |
|-------|------|-----------------|
| **Network** | [[pulumi]] | Tailscale ACLs, tags, auth keys; Gandi DNS |
| **Host config** | [[ansible]] | Services on [[indri]]; ringtail's NixOS build; sifaka exporters |
| **Kubernetes** | [[argocd]] | Containerized workloads |

Each layer has its own reconciliation loop:
- Pulumi applies on `mise run tailnet-up`
- Ansible applies on `mise run provision-indri`
- ArgoCD watches Git; most apps sync automatically, a few meta-apps (ArgoCD itself, the app-of-apps root) are deliberately manual

## A Central Pillar

GitOps isn't just how BlumeOps deploys workloads — it underpins the design of nearly every system in the stack:

- **The k3s fleet** — every containerized service (the SSO, the databases, the observability stack, and the agent services) is declared in `argocd/manifests/` and reconciled by [[argocd]] from this repo.
- **First-party container releases** — an image release is a PR in this repo that bumps the pin tag (`v<version>-<short-sha>-nix`) and `service-versions.yaml` together, so every running build is traceable to a commit.
- **CI itself** — the `.forgejo/workflows/` that build and test everything live in this repo, as do the warrant-gated privileged workflows (such as `build-container`, `argocd-deploy`, `deploy-fly`), whose definitions execute from `main` only.
- **Host configuration** — [[indri]] services via [[ansible]], ringtail's NixOS build (its flake lives in this repo), and the sifaka exporters.
- **The tailnet** — Tailscale ACLs, tags, and auth keys, plus Gandi DNS, applied by [[pulumi]] from repo state.
- **The docs** — this site is built from the repo and shipped as versioned releases.
- **The agent services themselves** — [[talos]] and [[horkos]] deploy *through* this loop: their release workflow opens a pin PR here, and merging it is the deploy.

## The Pantheon: Agent-Driven GitOps

The posture has shifted a great deal in a short time: BlumeOps is now a pantheon of GitOps-driven automation backed by agentic workflows — [[forgejo|Forge]] (the forge where the issues live), [[talos|Talos]] (the agent sessions), [[horkos|Horkos]] (the approval broker), and [[hephaestus|Hephaestus]] (the task and context substrate).

GitOps is now the mechanism by which Forge issues become code changes in blumeops itself: a Forge issue or PR review engages a Talos session via webhook; the session works it as a branch plus a cross-repo PR from the read-only `agents` bot; Erich reviews and merges; ArgoCD and CI pick the change up. Privileged actions — deploys, image builds — travel a separate gate: `mise run request-run` → human approval in Horkos → `warrant-bot` dispatch, as described in [[warrant-approval-gated-runs]].

The loop is fully self-hosted and SHA-bound: image pins carry the short SHA of the commit that built them, warrants bind to a full 40-character commit (never a branch), and Horkos freezes the approved `{action, sha, inputs}` at approval time — so every first-party image and every privileged action traces back to an immutable commit. The result is not deterministic in the reproducible-builds sense — LLMs write the code changes — but it verges on it: every state transition is traceable to a commit in this repo's history.

The design also makes a deliberate attempt at addressing Simon Willison's ["Lethal Trifecta"](https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/): an agent that (1) reads untrusted content, (2) holds credentials to private data, and (3) can act on the outside world is a prompt-injection exfiltration machine. Talos agents do read untrusted content and do hold scoped secrets, so the third leg is structurally denied: egress only through a per-connection-logged gateway, read-only on canonical repos, and no deploy path in the pod. Anything with lasting effect on the outside world routes through the human approval gate, which keeps a durable decision record. See [[security-model]] for the fence details.

## Trade-offs

GitOps isn't free:

- **Learning curve** - You need to understand Ansible, ArgoCD, Pulumi
- **Indirection** - Can't just `brew install` something; need to add it to config
- **Complexity** - More moving parts than a simple server

But for BlumeOps, the trade-off is worth it. The infrastructure is complex enough that managing it imperatively would be error-prone, and the GitOps approach enables effective AI-assisted operations.

## Related

- [[architecture]] - How the pieces fit together
- [[pulumi]] - Network infrastructure as code
- [[argocd]] - Kubernetes GitOps
- [[ansible]] - Host configuration
- [[talos-design]] - The agent workflow service
- [[warrant-approval-gated-runs]] - Human-gated privileged runs
- [[agent-change-process]] - How agent changes flow as PRs
- [[security-model]] - The fences around agent capabilities
