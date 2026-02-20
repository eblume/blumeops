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
2. **Attempt the change**, amending the working commit. On failure, revert the broken change and:
   - Create/update prerequisite cards as how-to docs with `status: active`
   - Add `requires: [prerequisite-stem, ...]` to the goal card's frontmatter
   - Commit the doc updates (the documentation IS the Mikado graph)
3. **Work leaf nodes first** — cards with `status: active` and no unmet `requires`
4. **New agent sessions** pick up state by running `mise run docs-mikado`
5. When a card's change succeeds, remove `status: active` (or the entire field) from its frontmatter

Documentation IS the Mikado graph. Each card captures what was learned from failed attempts, so the next agent session doesn't repeat mistakes.

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

- Cards live in `docs/how-to/` — they're how-to docs with lifecycle metadata
- Keep cards brief (<30 seconds to read)
- Link to other cards rather than inlining their content
- Document what was learned from failures, not just what to do

### Git Discipline

- Single feature branch per C1/C2 change
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
