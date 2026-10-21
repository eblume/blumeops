---
title: Talos v0.5 — instance side (design snapshot)
modified: 2026-10-21
last-reviewed: 2026-10-21
tags:
  - explanation
  - ai
  - design
---

# Talos v0.5 — instance side

> **Talos v0.5 design snapshot (instance side), not a maintained reference.**
> The generic design lives in talos `docs/design/v0.5/`; this page holds what
> is specific to this instance.

Talos v0.5 turns talos from a reader of forge threads into a system of record:
every Issue gets a plan, steps and asks that talos owns, and Forgejo, CI and
horkos report facts into it. The generic design (the work-item record, asks,
the event log, classifiers, the landing queue, the sandbox) is written in
talos and names no host, repo or runner. This directory holds the other half:
which repos, runners, hosts, workflows and config files this instance uses to
run that design, and the Issue bodies for the blumeops rows of each wave.

Generic design, in talos:
[index](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/README.md),
[work items](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/work-items.md),
[asks](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/asks.md),
[event log](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/event-log.md),
[classifiers](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/classifiers.md),
[landing queue](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/landing-queue.md),
[sandbox](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/sandbox.md),
[context and prompts](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/context-and-prompts.md),
[components](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/components.md),
[cases](https://forge.ops.eblu.me/eblume/talos/src/branch/main/docs/design/v0.5/cases.md).

## Pages

| Page | Covers |
|---|---|
| [[landing-gate]] | The `queue-gate` workflow on every managed repo, the queue issue, branch protection, and the main-settled rule's inputs |
| [[runners-and-trust]] | Privileged runners, why a PR's own workflow reaches them, the "always trust" lists, and the one fork model |
| [[aspects]] | The aspect suite in `aspects/`: layout, plumbing, pilots and candidates |
| [[hosts-warrants-and-config]] | Warrant policy and horkos, auto-apply hosts, the auto-sync app map, declared state, templates, settings, crons, verify reach |
| [[indri-ansible-retirement]] | V5-83: the indri Ansible retirement chain, run alongside the waves as the control group |
| [[wave-1]], [[wave-2]], [[wave-3]], [[wave-4]] | Issue bodies for the blumeops rows of Waves 1–4 |

## Instance values stay out of talos

Talos and horkos are components. Anything that names this deployment
(`eblume`, `eblu.me`, a host, a runner label, a vault, a repo list) lives here
and reaches them as a mounted file or an environment variable, following the
rule in [[declared-state-files]]. The first aspect pilot (V5-32, "instance
config out of talos/horkos") enforces it over talos's and horkos's `src/` and
their prompt strings, so a violation fails CI instead of relying on review.

## Related

- [[talos-design]] — the original talos design card
- [[talos]] — the service reference
- [[warrant-approval-gated-runs]], [[horkos]], [[auto-apply]]
