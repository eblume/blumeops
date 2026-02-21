---
title: Agent Change Process
modified: 2026-02-20
tags:
  - how-to
  - ai
---

# Agent Change Process

How to classify and execute infrastructure changes, especially when working with AI agents that may lose context across sessions.

## Change Classification

Before starting work, classify the change:

| Class | Scope | Process |
|-------|-------|---------|
| **C0** | Quick fix, single-file, obvious | Read `ai-docs`, implement directly |
| **C1** | Moderate, potential hidden complexity | Mikado method, single session, single PR |
| **C2** | Complex, multi-session | Mikado method, documentation-driven, single PR |

## C0 — Quick Fix

1. Run `mise run ai-docs` to load context
2. Implement the change directly
3. Commit, push, create PR

Examples: fix a typo, bump a version, add a simple config value.

## C1 — Guided Change (Single Session)

Use the [Mikado method](https://mikadomethod.info/) within a single session:

1. Run `mise run ai-docs` to load context
2. Attempt the change on a feature branch, amending a single commit as you iterate
3. **If it works:** push and create PR
4. **If it fails:** revert the broken change (`git revert`), then:
   - Amend or add a commit with documentation updates noting what prerequisite was discovered
   - Update frontmatter: add `requires: [prerequisite-card]` to the goal card
   - Work the leaf nodes (prerequisites with no further dependencies) first
   - Repeat until the goal succeeds

Single feature branch, squash-merge when complete. GitOps may require pushing to test — if a pushed commit breaks, revert it promptly.

## C2 — Documented Change (Multi-Session)

Like C1 but designed to survive agent context loss across sessions:

1. **Goal card:** Create a how-to doc in `docs/how-to/` describing the desired end state
   - Add `status: active` to frontmatter
2. **Attempt the change** — GitOps may require pushing code to test (e.g., ArgoCD sync). When the attempt fails:
   - **First**, reset the failed code changes (the branch should not carry broken code forward)
   - **Then**, create/update prerequisite cards as how-to docs with `status: active`
   - Add `requires: [prerequisite-stem, ...]` to the goal card's frontmatter
   - Commit only the doc updates (the documentation IS the Mikado graph)
3. **Work leaf nodes first** — cards with `status: active` and no unmet `requires`
4. **Re-attempt the goal** after leaf nodes are resolved — code from the attempt comes back here
5. **New agent sessions** pick up state by running `mise run docs-mikado`
6. When a card's change succeeds, remove `status: active` (or the entire field) from its frontmatter

Documentation IS the Mikado graph. Each card captures what was learned from failed attempts, so the next agent session doesn't repeat mistakes.

### Handling failed attempts

When an attempt fails and you discover prerequisites, the branch must be cleaned up before documenting what you learned:

1. Reset to before the code attempt (`git reset --hard`)
2. Commit the new prerequisite cards and frontmatter updates
3. If you already committed docs mixed with code, cherry-pick the doc commits onto a clean base rather than reverting (avoids noisy add/revert history)

The branch between attempts should contain only documentation. Code returns when prerequisites are satisfied and the next attempt succeeds.

### Build artifacts

Mikado resets apply to branch code, not build artifacts. Container images in the registry are independent of branch lifecycle:

- **Registry images** are build outputs cached in zot — tagged with commit SHAs, so each build is unique and traceable.
- **Automatic builds** trigger when container changes merge to main. Use `mise run container-build-and-release` for manual dispatch.
- **If a build succeeds but deployment fails**, the image is fine; the problem is elsewhere. Document what you learned and try again.
- **If a build fails in CI**, no image is pushed. Fix the nix/dockerfile and re-merge or re-dispatch.

## Card Conventions

### Frontmatter

```yaml
---
title: Deploy Authentik
status: active          # omit when complete
requires:               # explicit dependencies
  - configure-postgres
  - setup-redis
tags:
  - how-to
---
```

- `status: active` marks in-progress work; omit when done
- `requires` lists card stems (filenames without `.md`) that must be completed first
- `required-by` is NOT stored — it's computed by `docs-mikado`

### Writing Cards

- **Mikado cards are not plans.** Plans are designed upfront; Mikado cards are discovered through failed attempts. Don't put Mikado prerequisite cards in `docs/how-to/plans/`.
- Cards live in a topic subdirectory under `docs/how-to/` (e.g., `docs/how-to/authentik/` for the deploy-authentik chain). The goal card may live in `plans/` if it started as a plan.
- Keep cards brief (<30 seconds to read)
- Link to other cards rather than inlining their content
- Document what was learned from failures, not just what to do

### Git Discipline

- Single feature branch per C1/C2 change
- **Create a PR early** — open a draft PR after the first doc commit so the user can review the Mikado graph as it evolves between iterations.
- **Push after every iteration** — after completing a leaf node or documenting a failed attempt, push to origin. This is the save point for multi-session work.
- Amend a single working commit as you iterate; keep the branch history clean
- GitOps requires pushing to test — if a pushed commit breaks, revert it promptly
- Commit doc updates noting what was learned from failures

## Tools

| Command | Purpose |
|---------|---------|
| `mise run docs-mikado` | List all active Mikado chains |
| `mise run docs-mikado <card>` | Show dependency chain for a goal card |
| `mise run docs-mikado <card> --all` | Include completed cards in full |

## Related

- [[ai-assistance-guide]] — General AI agent conventions
- [[exploring-the-docs]] — Documentation structure overview
