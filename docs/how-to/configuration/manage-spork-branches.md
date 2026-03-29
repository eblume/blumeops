---
title: Manage Spork Branches
modified: 2026-03-28
last-reviewed: 2026-03-28
tags:
  - how-to
  - git
  - forgejo
---

# Manage Spork Branches

How to create, maintain, and reason about feature branches on a sporked repository. See [[create-a-spork]] for initial setup.

## Branch types

### Upstreamable features (`feature/upstream/*`)

Changes intended to be contributed upstream. Branch off `main` so the diff is clean — no local tooling or workflows mixed in.

```fish
cd ~/code/3rd/kingfisher
git fetch origin
git checkout -b feature/upstream/forgejo-support origin/main

# Make changes, commit as normal
git push -u origin feature/upstream/forgejo-support
```

The mirror-sync workflow will automatically rebase this branch onto `main` each day.

To see what the upstream contribution looks like:

```fish
git log main..feature/upstream/forgejo-support --oneline
git diff main...feature/upstream/forgejo-support
```

To create a preview PR on forge (targets the mirror, not upstream):

```fish
# From the eblume/<project> repo, PR targeting mirrors/<project>:main
# This gives a public URL showing the diff without filing upstream
tea pr create --repo mirrors/kingfisher --head eblume/kingfisher:feature/upstream/forgejo-support --base main
```

When ready to contribute upstream, manually translate the branch to a GitHub PR.

### Non-upstreamable features (`feature/local/*`)

Local-only changes that will never go upstream. Branch off `blumeops` so you have access to all local tooling.

```fish
cd ~/code/3rd/kingfisher
git fetch origin
git checkout -b feature/local/custom-rules origin/blumeops

# Make changes, commit as normal
git push -u origin feature/local/custom-rules
```

The mirror-sync workflow will automatically rebase this branch onto `blumeops` each day.

## The `deploy` branch

The `deploy` branch is a build artifact — rebuilt fresh by mirror-sync daily. It contains everything merged together: `blumeops` + all `feature/local/*` + all `feature/upstream/*`. Use this branch for deployments (e.g., ArgoCD `targetRevision`).

**Never commit to or work from `deploy`.**

## Working with rebasing branches

Because mirror-sync force-pushes rebased branches daily, local checkouts will diverge. Always pull with rebase:

```fish
git pull --rebase origin feature/upstream/my-change
```

Or set it as default for the repo:

```fish
git config pull.rebase true
```

This is the fundamental trade-off of the spork strategy: small frequent rebases instead of rare catastrophic merges.

## When rebases fail

If upstream changes conflict with a feature branch, mirror-sync will skip that branch and log an error. Recovery:

```fish
cd ~/code/3rd/kingfisher
git fetch origin
git checkout feature/upstream/my-change
git rebase origin/main
# Resolve conflicts...
git push --force-with-lease origin feature/upstream/my-change
```

The next mirror-sync run will pick up the resolved branch and rebuild `deploy`.

**TODO:** Workflow failures — whether from rebase conflicts or upstream history rewrites (force-push on main) — are currently only visible in the Forgejo Actions UI. Alerting via Grafana is planned but not yet implemented.

## Future: `.spork.toml`

For repos with multiple feature branches, a `.spork.toml` file on the `blumeops` branch could declare:

- **Branch dependencies** (stacked branches — `bar` depends on `foo`)
- **Feature descriptions** (what the branch is for, in prose)
- **Upstream/local classification** (as an alternative to the naming convention)

This is not yet implemented. For now, the `feature/upstream/*` vs `feature/local/*` naming convention is the source of truth.

## See also

- [[create-a-spork]] — initial setup
- [[manage-forgejo-mirrors]] — mirror setup and PAT rotation
