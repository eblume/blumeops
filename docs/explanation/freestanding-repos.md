---
title: Freestanding Repos
modified: 2026-09-10
last-reviewed: 2026-09-10
tags:
  - explanation
  - infrastructure
  - ai
---

# Freestanding Repos

A **freestanding repo** carries no trust boundary. Unlike the fenced core
(blumeops, agents, horkos, talos — the pinned read-only set) it
auto-deploys nothing and manages no real secrets: it
builds, releases to forge release artifacts, and optionally installs locally
via a hand-run script or mise task.

"Freestanding" describes the shape: self-supporting, with nothing depending
on them and no downstream dependency on their part. Whether talos acts on a
freestanding repo is a separate attribute, not part of the class. A
`repos.json` opt-out attribute — "the repo exists and is visible, but the
bot does not operate on its issues or commit code without asking" — is
anticipated as an attribute on the `repos.json` entry, not a new class. It
is not implemented yet.

## Shape

One line in `argocd/manifests/talos/repos.json`:

```json
{ "name": "<repo>", "access": "write", "pool": "canonical" }
```

No `release_hook`. `release_hook: true` adds the forge → horkos release
webhook; it is for repos whose artifacts flow through horkos, and a
freestanding repo never needs it.

## Lifecycle

[[add-a-freestanding-repo]] walks the end-to-end procedure. In outline:

1. The forge repo is created from `project-template` — a human action; the
   agents bot's token cannot create repos.
2. The `repos.json` entry lands on blumeops `main` via PR.
3. On merge, CI (the Agent Repo Access workflow) reconciles the agents bot's
   collaborator grant, and the talos pod rolls to pick the repo up in its
   clone loop.
4. Manual follow-up from gilbert: `mise run agent-repo-access` creates the
   forge → talos webhook and seeds the `agents` engagement label. Those
   halves need secrets and tokens CI does not carry: the webhook signing
   secret comes from the blumeops 1Password vault, and the CI token 403s
   even on label reads. A webhook without the label is a trap — delivery works but
   nothing engages. Details: [[agents-forgejo-bot]] §"Sharing a repo with the bot".

## Buildability

A freestanding repo's CI runs on the forge runner (indri) and its dev loop
is expected to run in the talos pod, so external dependencies must be
fetchable or vendored in CI — a decision point for e.g. vendored game
assemblies. Contrast: timberborn-parsimony is pooled but not
pod-buildable (it needs game DLLs mounted only on ringtail/gilbert) — the
anti-example.

## The first freestanding repo

RexWorks, a RimWorld mod (Harmony, C#), is being created as the proof case
in [eblume/blumeops#978](https://forge.eblu.me/eblume/blumeops/issues/978).

## See also

- [[add-a-freestanding-repo]] — the end-to-end procedure
- [[agents-forgejo-bot]] — the identity and access model
