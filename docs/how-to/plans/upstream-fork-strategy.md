---
title: "Plan: Upstream Fork Strategy"
modified: 2026-02-11
tags:
  - how-to
  - plans
  - forgejo
  - git
---

# Plan: Upstream Fork Strategy

> **Status:** Planned (design sketch — not yet executed)

## Background

Several BlumeOps projects need to track upstream repositories while maintaining local modifications. Examples include a personal Quartz fork (for docs site customization) and potentially other tools where upstream changes need to flow in continuously.

The current approach — Forgejo auto-tracking mirrors — works for read-only copies but breaks down when we need to:

1. Add BlumeOps-specific changes (delete upstream workflows, add `mise.toml`, custom config)
2. Develop features that might eventually be upstreamed
3. Keep all of this synchronized as upstream evolves

### Goals

- Upstream changes flow in automatically (daily rebase)
- Rebase conflicts are detected and reported, not silently ignored
- BlumeOps-specific patches are cleanly separated from upstream-candidate work
- Feature branches that could become upstream PRs are maintained independently

## Branch Model

The strategy uses stacked branches — each layer builds on the one below:

```
upstream/main                  (read-only tracking branch)
    │
    ▼
blumeops                       (primary branch — blumeops-specific patches)
    │                          e.g., delete .github/, add mise.toml,
    │                          configure for tailnet, etc.
    │
    ├──▶ feature/foo           (feature branch — developed on top of blumeops)
    │    │                     intended for local use, may never go upstream
    │    │
    │    └──▶ feature/foo-upstream  (optional — same changes rebased onto main)
    │                               for submitting as an upstream PR
    │
    └──▶ feature/bar           (another feature branch)
```

### Branch Purposes

| Branch | Base | Purpose | Rebased onto |
|--------|------|---------|--------------|
| `upstream/main` | — | Tracks upstream's `main` (or `master`) via `git fetch` | Never rebased |
| `blumeops` | `upstream/main` | Primary branch; BlumeOps-specific patches only | `upstream/main` (daily) |
| `feature/*` | `blumeops` | Feature development | `blumeops` (after successful rebase) |
| `feature/*-upstream` | `upstream/main` | Cherry-picked/rebased feature for upstream PR | `upstream/main` (on demand) |

### What Goes in `blumeops` vs `feature/*`

**`blumeops` branch** — infrastructure-level changes that are permanent and BlumeOps-specific:
- Delete upstream CI workflows (`.github/workflows/`)
- Add `mise.toml` for local tooling
- Add or modify configuration for the BlumeOps environment
- Patch version pins or dependency overrides

**`feature/*` branches** — functional changes to the project itself:
- Bug fixes you want to contribute upstream
- New features or customizations
- Anything that could theoretically stand on its own as a PR to the upstream project

This separation ensures the `blumeops` branch stays small and conflict-resistant (infrastructure changes rarely conflict with upstream code changes), while feature branches carry the substantive modifications.

## Daily Rebase Workflow

A Forgejo Actions workflow runs on a schedule to keep `blumeops` rebased onto the latest upstream:

### Workflow Outline

```
trigger: cron (daily) or manual dispatch

1. Fetch upstream remote
2. Check if upstream/main has new commits since last rebase
3. If no new commits → exit early
4. Attempt: git rebase blumeops --onto upstream/main
5. If rebase succeeds:
   a. Force-push blumeops
   b. For each feature/* branch:
      - Attempt rebase onto updated blumeops
      - If success → force-push
      - If conflict → skip, record failure
6. If rebase fails (conflict):
   a. Abort rebase
   b. Create or update a Forgejo issue with conflict details
   c. Label the issue for visibility
```

### Conflict Reporting

When a rebase fails, the workflow creates (or updates) a Forgejo issue via the API:

- **Title:** `Rebase conflict: blumeops onto upstream/main` (or `feature/foo onto blumeops`)
- **Body:** Include the conflicting files, the upstream commit range, and the git output
- **Labels:** `rebase-conflict`, `automated`
- **Assignee:** `eblume`

The issue serves as a task to manually resolve the conflict. Once resolved and force-pushed, the next daily run succeeds and the issue can be closed.

### Safety Guards

- **Never force-push `upstream/main`** — this is a read-only tracking branch, only updated via `git fetch`
- **Abort on any rebase ambiguity** — if the rebase produces unexpected state, abort and report rather than pushing garbage
- **Dry-run mode** — the workflow should support a manual dispatch input to run in dry-run mode (rebase but don't push, just report what would happen)
- **Lock file** — prevent concurrent rebase runs from colliding (Forgejo Actions concurrency groups)

## One-Time Setup Per Fork

### Step 1: Create the Mirror

Set up a Forgejo auto-tracking mirror of the upstream project:
```
Forgejo → New Migration → Git → URL: https://github.com/org/project.git
```

### Step 2: Disable Mirroring

Once mirrored, disable the auto-sync in Forgejo repository settings. The repository is now a regular Forgejo repo with the upstream history.

### Step 3: Set Up Remotes

```bash
cd ~/code/3rd/<project>
git remote rename origin forge
git remote add upstream https://github.com/org/project.git
git fetch upstream
```

### Step 4: Create the `blumeops` Branch

```bash
git checkout upstream/main
git checkout -b blumeops
# Apply blumeops-specific patches
git commit -m "BlumeOps: remove upstream workflows, add mise.toml"
git push forge blumeops
```

Set `blumeops` as the default branch in Forgejo repository settings.

### Step 5: Add the Rebase Workflow

Add `.forgejo/workflows/rebase-upstream.yaml` to the `blumeops` branch. This workflow is itself a blumeops-specific patch — upstream doesn't have it.

### Step 6: Protect Branches

Configure Forgejo branch protection:
- `blumeops`: only the rebase workflow (and manual push) can force-push
- `upstream/main`: read-only (only updated by the rebase workflow's `git fetch`)

## The Upstream PR Path

When a feature is ready to be proposed upstream:

1. Create `feature/foo-upstream` from `upstream/main`
2. Cherry-pick or rebase `feature/foo` commits onto it (excluding any `blumeops`-specific commits)
3. Push to the fork on the upstream platform (e.g., GitHub)
4. Open PR from the fork to upstream

This branch is maintained independently — it does not participate in the daily rebase. It's a point-in-time snapshot for the PR. If the PR needs updates, rebase it manually.

## First Instance: Quartz Fork

Quartz (the documentation site generator) is the planned first fork and the primary motivation for this strategy.

- **Upstream:** `https://github.com/jackyzha0/quartz.git`
- **Forge repo:** `forge.ops.eblu.me/mirrors/quartz`
- **Primary branch:** `blumeops`

### BlumeOps-Specific Patches (`blumeops` branch)

Changes that are permanently BlumeOps-specific and would never go upstream:

- Remove `.github/` workflows
- Add `mise.toml` with pinned Node version
- Configure Quartz defaults for BlumeOps site metadata

### Feature Work (`feature/*` branches)

The key feature motivating this fork is **`last-reviewed` frontmatter support**. BlumeOps documentation uses a `last-reviewed` date in frontmatter to track documentation staleness (see `mise run docs-review`). Upstream Quartz has no awareness of this field. The fork enables:

- **Rendering `last-reviewed` in article headers** — display when a doc was last reviewed, making staleness visible to readers without running CLI tools
- **Staleness indicators** — visual styling (e.g., a warning banner) for docs where `last-reviewed` exceeds a threshold
- **Sorting/filtering by review date** — Quartz explorer or listing pages that surface docs needing attention

This is a strong upstream PR candidate — other Quartz users maintaining knowledge bases would benefit from custom frontmatter rendering. The `feature/last-reviewed` branch would be developed on the `blumeops` branch (for local use) with a parallel `feature/last-reviewed-upstream` branch rebased onto `upstream/main` for the PR.

### Integration with Dagger Docs Build

This fork directly supports the [[adopt-dagger-ci]] plan. Once the fork exists, the Dagger `build_docs` function switches from cloning upstream Quartz to using the fork:

```python
# Before (cloning upstream):
.with_exec(["git", "clone", "--depth=1",
             "https://github.com/jackyzha0/quartz.git", "/tmp/quartz"])

# After (using the BlumeOps fork):
.with_exec(["git", "clone", "--depth=1", "--branch=blumeops",
             "https://forge.ops.eblu.me/mirrors/quartz.git", "/tmp/quartz"])
```

This means the `build-blumeops.yaml` workflow automatically picks up fork customizations (like `last-reviewed` rendering) when building docs — no separate integration step needed. Local iteration via `dagger call build-docs` also uses the fork, so you can test Quartz customizations against actual BlumeOps content before pushing.

## Open Questions

- **Rebase vs merge:** This plan uses rebase for a clean linear history. Merge commits would avoid force-pushes but create a messier history. Rebase is preferred for small forks; revisit if the commit volume grows.
- **Notification mechanism:** Forgejo issues are proposed for conflict reporting. Alternatives: email, Slack webhook, Todoist task via API. Issues are preferred because they're visible in the forge and can carry discussion.
- **Feature branch automation:** The daily rebase of feature branches onto `blumeops` is aggressive — it means feature branches are force-pushed daily. An alternative is to only rebase feature branches on demand (manually or via workflow dispatch). Start with manual and automate later based on experience.
- **Multiple upstreams:** Some projects track multiple remotes (e.g., a CNCF project with a GitHub mirror and a self-hosted primary). The workflow should support configurable upstream remote URLs.

## Future Considerations

- **Renovate integration** — Renovate could watch upstream tags and open PRs to the `blumeops` branch when new releases are available, complementing the daily rebase with release-aware updates
- **Dagger integration** — forked projects that produce build artifacts can use the BlumeOps Dagger module for builds, sharing the same local iteration and CI patterns
- **Template repository** — once the pattern is proven with quartz, create a template repo or mise task that scaffolds the branch structure and rebase workflow for new forks

## Related

- [[adopt-dagger-ci]] — CI/CD build engine (consumes fork artifacts)
- [[forgejo]] — Git forge hosting the forks
- [[docs]] — Documentation site (first fork consumer)
