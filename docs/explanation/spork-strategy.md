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

Forgejo Actions only checks `.forgejo/workflows/` when that directory exists, so upstream's `.github/workflows/` won't run on forge — no deletion needed. If upstream has its own `.forgejo/` directory (rare), it's removed during spork setup.

## How-to guides

- [[create-a-spork]] — initial setup with `mise run spork-create`
- [[manage-spork-branches]] — feature branches, the deploy branch, handling rebase conflicts

## See also

- [[manage-forgejo-mirrors]] — how upstream mirrors work
- [[kingfisher]] — first project using the spork strategy
