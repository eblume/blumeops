---
title: Spork Strategy
modified: 2026-03-28
last-reviewed: 2026-03-28
tags:
  - explanation
  - git
  - forgejo
---

# Spork Strategy

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

A "spork" is a floating-branch soft-fork strategy for maintaining local changes against upstream projects without creating a true fork. The name: a fork that's trying its hardest not to be one.

## The problem

We mirror upstream projects on forge for supply-chain control. Sometimes we need to carry local patches — workflow support, build tooling, bug fixes. A real fork diverges silently until merge day becomes a nightmare. A spork stays perpetually close to upstream with patches "floating" on top, rebased daily.

## The trade-off

A spork chooses "small frequent pain" (constant rebasing, shifting branch targets) over "rare catastrophic pain" (fork divergence). For a solo operator carrying a handful of patches, this is the right trade-off. The key property: `git log main..blumeops` always shows your complete delta from upstream. No mystery divergence.

Long-lived work against a sporked repo must accept that there is no "safe" branch — everything is an ever-shifting target. Anyone with a local checkout needs to be comfortable with `git pull --rebase`.

## Architecture

Three remotes, five branch types, one daily sync workflow. The `blumeops` branch is the default — it looks just like upstream with local workflows overlaid. Feature branches come in two flavors: upstreamable (branched off `main`, clean for contribution) and non-upstreamable (branched off `blumeops`, local-only). A `deploy` branch merges everything together as a build artifact.

Forgejo Actions checks `.forgejo/workflows/` first; if that directory exists, `.github/workflows/` is ignored. This protects the `blumeops` branch and `feature/local/*` branches (which inherit `.forgejo/` from `blumeops`). However, `main` and `feature/upstream/*` branches do NOT have `.forgejo/workflows/` — they're clean upstream code — so Forgejo falls back to `.github/workflows/` on those branches. See [[spork-strategy#Spork Attack]] for the security implications.

## Spork Attack

A "spork attack" is a supply-chain risk inherent to the spork strategy. Because `main` and `feature/upstream/*` branches carry upstream's `.github/workflows/`, those workflows are registered by Forgejo Actions. If an upstream project publishes a workflow targeting runner labels that match your infrastructure, it will execute on your runners.

**Attack chain:**

1. Upstream pushes a workflow (in `.github/workflows/` or `.forgejo/workflows/`) with `runs-on: <your-runner-label>`
2. Mirror auto-syncs, mirror-sync fast-forwards `main` on your fork
3. The workflow triggers — via push event, PR event, cron schedule, or any other trigger mechanism
4. Workflow executes on your runner with access to `GITHUB_TOKEN` and the runner's environment

Note that a cron-triggered workflow is especially dangerous: it requires no user interaction at all. As soon as `main` is updated with the malicious workflow, Forgejo schedules it automatically.

**Current mitigations:**

- **Runner label mismatch** — our runner uses `k8s`, upstream workflows typically use `ubuntu-24.04` / `macos-latest` / `windows-latest`. Jobs queue but never execute. This is effective but fragile — it depends on upstream never guessing our label.
- **Trust boundary** — we only spork projects we trust. Kingfisher is maintained by a MongoDB security engineer.
- **Mirror review** — mirror syncs are visible in Forgejo; malicious workflow changes would appear in the commit history. But this is not a real-time defense — the workflow may execute before anyone reviews.

**What would fix this properly:**

- A Forgejo per-repo setting to disable workflow discovery entirely on specific branches, or to require an explicit allow-list of workflow files. Neither exists today.
- Runner-level repo allow-lists could limit blast radius, but the workflow files still come from the sporked repo via upstream, so the runner would still execute them.

**Recommendation:** Use non-standard runner labels (not `ubuntu-latest`, `linux`, etc.) and only spork projects you trust. Document which projects are sporked and review upstream workflow changes periodically. Consider this an open problem — there is no complete defense short of disabling Actions on the repo entirely (which breaks mirror-sync).

## How-to guides

- [[create-a-spork]] — initial setup with `mise run spork-create`
- [[manage-spork-branches]] — feature branches, the deploy branch, handling rebase conflicts
- [[build-spork-container]] — building reproducible containers from pinned SHAs

## See also

- [[manage-forgejo-mirrors]] — how upstream mirrors work
- [[kingfisher]] — first project using the spork strategy
