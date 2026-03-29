---
title: Create a Spork
modified: 2026-03-28
last-reviewed: 2026-03-28
tags:
  - how-to
  - git
  - forgejo
---

# Create a Spork

How to set up a floating-branch soft-fork ("spork") of a mirrored upstream project using `mise run spork-create`.

## Prerequisites

- Mirror already exists at `mirrors/<project>` on forge (see [[manage-forgejo-mirrors]])
- 1Password CLI authenticated (`op` CLI)
- SSH access to `forge.ops.eblu.me:2222`

## Create the spork

```fish
mise run spork-create kingfisher
```

This will:

1. Fork `mirrors/kingfisher` → `eblume/kingfisher` on forge
2. Create a `blumeops` branch from upstream's main branch
3. Remove any upstream `.forgejo/` directory (if present)
4. Add `.forgejo/workflows/mirror-sync.yaml` and commit it
5. Set `blumeops` as the default branch
6. Clone to `~/code/3rd/kingfisher` with three remotes: `origin`, `mirror`, `upstream`

Options:

```fish
mise run spork-create kingfisher --dry-run          # preview only
mise run spork-create kingfisher --no-clone         # skip local clone
mise run spork-create kingfisher --main-branch dev  # override branch name
```

## Verify the setup

```fish
cd ~/code/3rd/kingfisher
git remote -v
# origin   ssh://forgejo@forge.ops.eblu.me:2222/eblume/kingfisher.git (fetch)
# mirror   ssh://forgejo@forge.ops.eblu.me:2222/mirrors/kingfisher.git (fetch)
# upstream https://github.com/mongodb/kingfisher.git (fetch)

git branch -a
# * blumeops
#   remotes/origin/blumeops
#   remotes/origin/main
```

## What happens next

The mirror-sync workflow runs daily at 05:00 UTC and:

- Fast-forwards `main` from the mirror
- Rebases `blumeops` on top of `main`
- Rebases any `feature/local/*` and `feature/upstream/*` branches
- Rebuilds the `deploy` branch (all features merged)

See [[manage-spork-branches]] for working with feature branches.

## Terminology

| Term | Meaning |
|------|---------|
| `origin` | Your mutable fork at `eblume/<project>` on forge |
| `mirror` | Read-only upstream mirror at `mirrors/<project>` on forge |
| `upstream` | Canonical upstream repository (e.g., GitHub) |
| `main` | Clean upstream tracking branch (may be named `master`, `dev`, etc.) |
| `blumeops` | Default branch — upstream + local workflows/tooling |
| `deploy` | Build artifact branch — everything merged, used for deployments |

## See also

- [[manage-spork-branches]] — creating feature branches, upstreamable vs local
- [[manage-forgejo-mirrors]] — mirror setup and PAT rotation
