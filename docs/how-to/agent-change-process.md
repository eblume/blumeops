---
title: Agent Change Process
modified: 2026-02-24
last-reviewed: 2026-02-23
tags:
  - how-to
  - ai
---

# Agent Change Process

How to classify and execute infrastructure changes, especially when working with AI agents that may lose context across sessions.

## Change Classification

Before starting work, classify the change:

| Class | Name | When to use | Key trait |
|-------|------|-------------|-----------|
| **C0** | Quick Fix | Small, low-risk, fix-forward safe | Direct to main, no PR |
| **C1** | Human Review | Moderate complexity or risk | Feature branch + PR, docs-first |
| **C2** | Mikado Chain | Multi-phase, multi-session, high complexity | Mikado Branch Invariant |

When in doubt, start at C1. Upgrade to C2 if complexity spirals or the user requests it.

## C0 — Quick Fix

A change where the risk is low enough that problems can be quickly fixed forward.

1. Run `mise run ai-docs` to load context
2. Implement the change directly on main
3. Commit and push

No feature branch or PR required. If something goes wrong, fix forward with another commit.

Examples: fix a typo, bump a version, add a simple config value, update a doc.

## C1 — Human Review

A change with enough complexity or risk that a human should review it, but not so much that a formal multi-phase approach is needed.

### Process

1. Run `mise run ai-docs` to load context
2. **Search related docs** — read existing documentation and reference cards related to the change area
3. **Create a feature branch** and open a PR early (draft is fine)
4. **Documentation first** — commit doc changes reflecting the desired end state before writing code. This helps the reviewer understand intent and catches design issues early
5. **Implement** — commit code changes, pushing as you go. The PR gets updated along the way and the user can review and comment at any point
6. **Deploy from the branch** — do not wait for merge:
   - **ArgoCD:** `argocd app set <service> --revision <branch> && argocd app sync <service>`
   - **Ansible:** run playbooks directly from the branch checkout
   - **Workflows:** point workflow triggers at the branch if needed
7. After user review and successful deployment, the user merges the PR
8. **After merge:** reset ArgoCD revisions back to main, re-sync
9. **If the PR changed `containers/`:** the merge triggers a rebuild from main automatically. Once it completes, commit a C0 updating the manifest to the new `[main]`-tagged image (see [[build-container-image#Squash-merge and container tags]])

### Upgrading to C2

Upgrade to C2 if any of these happen during a C1 change:

- You discover the change requires multiple prerequisite changes that must be sequenced
- The change is spiraling in complexity beyond a single session
- The user requests it
- During planning you realize this is a multi-phase project

## C2 — Mikado Chain

A complex, multi-session change managed through the [Mikado method](https://mikadomethod.info/) with a strict branch discipline called the **Mikado Branch Invariant**.

### Planning and research

Before writing any code, invest in understanding the problem:

1. Run `mise run ai-docs` to load context
2. Search related docs, reference cards, and existing how-to guides for the change area
3. Think through the dependency graph — what prerequisites exist? What could go wrong?
4. Create Mikado cards for everything you can anticipate (you'll discover more later — that's the point of the method)

This planning phase can span multiple sessions. Cards introduced during planning are merged to main and become the foundation for work cycles later.

### The Mikado Branch Invariant

The invariant governs how commits are ordered on a C2 feature branch. The branch must always have this structure:

```
main ← [plan commits] ← [impl, close] ← [impl, close] ← ... ← [finalize]
       ^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
       Planning layer    Repeating work cycles
       (cards only)      (impl then close, one leaf at a time)
```

**Rules:**

1. The first N commits on the branch (after diverging from main) must ALL be commits that **only introduce or modify Mikado cards** — no code changes
2. After the card layer, work proceeds in **cycles**: each cycle is one or more code commits followed by one or more commits closing leaf nodes
3. A cycle should target a single leaf node (though closing multiple in one cycle is acceptable if the code supports it)
4. Cycles repeat until the chain is complete

**The one rule:** No Mikado card may be introduced after any code or card-closing commit. New cards require a branch reset (see below).

**The length-zero case:** It is valid for the "planning layer" to have zero commits on the branch — this happens when all Mikado cards were introduced in earlier sessions and are already in main's history. The invariant is satisfied.

**Exception — finalize:** The terminal commit of a completed chain rewrites Mikado cards to historical documentation. This is a card modification after code commits, and is the only permitted violation of the one rule (see "Completing a chain" below).

### Conventions

#### Branch naming

C2 branches must be named `mikado/<chain-stem>`, where `<chain-stem>` is the filename stem of the goal card. Example: goal card `deploy-authentik.md` → branch `mikado/deploy-authentik`.

#### Goal card `branch:` frontmatter

The goal card of a C2 chain must include a `branch:` field once work begins:

```yaml
---
title: Deploy Authentik
status: active
branch: mikado/deploy-authentik
requires:
  - configure-postgres
  - setup-redis
tags:
  - how-to
---
```

A goal card with `status: active` but no `branch:` field indicates a chain that has been planned but not yet started — the planning-phase cards exist but no implementation branch has been created.

#### Commit message convention

All commits on a `mikado/*` branch must use this format:

```
C2(<chain-stem>): <verb> <short description>
```

Verbs and their meanings:

| Verb | Phase | What it means |
|------|-------|---------------|
| `plan` | Planning layer | Introduces or modifies a Mikado card (no code changes) |
| `impl` | Work cycle | Code progress toward closing a leaf node (no card changes) |
| `close` | Work cycle | Closes a leaf node by removing `status: active` |
| `finalize` | Terminal | Rewrites cards to historical docs, adds changelog |

Examples:
```
C2(deploy-authentik): plan add postgres and redis prerequisite cards
C2(deploy-authentik): impl configure external-secrets for authentik
C2(deploy-authentik): close configure-postgres
C2(deploy-authentik): finalize rewrite cards as historical documentation
```

The `mikado-branch-invariant-check` commit-msg hook validates this convention and the invariant ordering.

### Process

1. **Goal card:** Create a how-to doc in `docs/how-to/` describing the desired end state
   - Add `status: active` and `branch: mikado/<chain-stem>` to frontmatter
   - Create prerequisite cards discovered during planning, each with `status: active`
   - Commit all cards together (or in a sequence of card-only commits) using `C2(<chain>): plan ...` messages
2. **Open a PR** after the first card commits so the user can review the Mikado graph
3. **Work leaf nodes** — pick a leaf (a card with `status: active` and no unmet `requires`):
   - Commit code changes (`C2(<chain>): impl ...`) that progress toward closing it
   - **Verify the card's own deliverables** (deploy from branch, run tests, etc.) before closing. "Works" means the card's stated outputs are correct — not that downstream consumers have integrated them. If a downstream card later discovers the output doesn't fit, that's a new prerequisite discovery handled by the normal reset mechanism.
   - Commit the card closure (`C2(<chain>): close ...`) — remove `status: active`
   - Push to origin — this is the save point
4. **End the cycle** — after pushing a closed leaf node, prompt the user to review the PR and suggest ending the session. Each closed leaf is a natural stopping point; the chain is designed to be resumed later. Don't rush into the next leaf without the user's go-ahead.
5. **Repeat** until the chain is complete
6. **New agent sessions** pick up state by running `mise run docs-mikado --resume`

### Discovering new prerequisites or errors

When you discover a new prerequisite **or encounter an error** during code work, do not fix forward. The Mikado method's power comes from rigorous resets that keep the plan honest. You must restore the Mikado Branch Invariant:

1. **Stash or note any in-progress work** you want to preserve
2. **Identify the reset point** — the last `plan` or `close` commit before your current `impl` commits:
   ```bash
   git log --oneline mikado/<chain-stem> --not main
   ```
3. **Reset the branch** to that commit:
   ```bash
   git reset --hard <reset-point-sha>
   ```
4. **Update the plan** — add a `plan` commit that captures what you learned:
   - If you discovered a new prerequisite: add a new card and update `requires`
   - If you hit an error: update the relevant card with what you learned, or introduce a new prerequisite card that addresses the root cause
5. **Replay valid work** by cherry-picking commits that still apply:
   ```bash
   git cherry-pick <sha1> <sha2> ...
   ```
6. **Resume the Mikado process** from the new state of the card stack

**When to reset vs. fix forward:** If an `impl` commit introduces a bug that's a simple typo or one-liner, another `impl` commit is fine. But if the error reveals a gap in understanding, a missing prerequisite, or requires rethinking the approach — reset. The threshold is: "does this error teach us something that should be in the plan?" If yes, reset.

**Saving work across resets:** It is acceptable to cherry-pick code commits from before the reset back onto the branch after adding the new card. Use `git stash` for uncommitted work. This is a pragmatic exception — use it only when you are confident the saved work is still valid given the new prerequisite. When in doubt, redo the work from scratch.

### Completing a chain

When the final leaf node is closed and no `status: active` cards remain:

1. **Rewrite all Mikado cards** to reflect their nature as historical documentation:
   - Remove transient technical details (specific version numbers, temporary workarounds) that won't matter in the future
   - Frame the content as "what to do if someone wanted to repeat this process"
   - Add appropriate context about what was learned
   - Remove `branch:` from the goal card frontmatter
2. **Add changelog information** in `docs/changelog.d/`
3. Commit as `C2(<chain>): finalize ...` — this is the one permitted exception to the invariant's "no card changes after code" rule
4. The user reviews and merges the PR

### Cold-start: resuming a chain in a new session

When starting a new session to continue C2 work:

1. Run `mise run ai-docs` to load context
2. Run `mise run docs-mikado --resume` — this will:
   - Detect the current branch and match it to an active chain
   - Show the chain state, ready leaf nodes, and current position in the invariant
   - Show the PR number and URL if an open PR exists for the branch
   - Warn about any stashed work in `git stash list`
   - If on main, list active chains and suggest which to resume
3. Check PR comments with `mise run pr-comments <pr_number>` — use the PR number from the `--resume` output above
4. Pick the next ready leaf node and continue with a work cycle

### Build artifacts

Mikado resets apply to branch code, not build artifacts. Container images in the registry are independent of branch lifecycle:

- **Registry images** are build outputs cached in zot — tagged with commit SHAs, so each build is unique and traceable
- **Squash-merge orphans:** Images built during PR development reference branch SHAs that won't exist on main after merge. After merge, a rebuild triggers automatically; commit a C0 to update manifests to the new `[main]`-tagged image. Use `mise run container-list <name>` to find it
- **Automatic builds** trigger when container changes merge to main. Use `mise run container-build-and-release` for manual dispatch
- **If a build succeeds but deployment fails**, the image is fine; the problem is elsewhere. Document what you learned and try again
- **If a build fails in CI**, no image is pushed. Fix the nix/dockerfile and re-merge or re-dispatch

## Card Conventions

### Frontmatter

```yaml
---
title: Deploy Authentik
status: active          # omit when complete
branch: mikado/deploy-authentik  # goal cards only; omit when complete
requires:               # explicit dependencies
  - configure-postgres
  - setup-redis
tags:
  - how-to
---
```

- `status: active` marks in-progress work; remove when done (this is the ONLY way a card is marked complete)
- `branch` is set on goal cards only, linking the card to its `mikado/<chain-stem>` branch. A goal card with `status: active` but no `branch` indicates a chain that is planned but not yet started. Remove `branch` when the chain is finalized.
- `requires` lists card stems (filenames without `.md`) that must be completed first. **Keep `requires` permanently** even after prerequisites are done — it documents the dependency graph history
- `required-by` is NOT stored — it's computed by `docs-mikado`

### Writing Cards

- **Mikado cards are not plans.** Plans are designed upfront; Mikado cards are discovered through failed attempts. Don't put Mikado prerequisite cards in `docs/how-to/plans/`.
- Cards live in a topic subdirectory under `docs/how-to/` (e.g., `docs/how-to/authentik/` for the deploy-authentik chain). The goal card may live in `plans/` if it started as a plan.
- Keep cards brief (<30 seconds to read)
- Link to other cards rather than inlining their content
- Document what was learned from failures, not just what to do

### Git Discipline

- **C0:** Commit directly to main
- **C1:** Single feature branch, PR early, push often
- **C2:** Branch named `mikado/<chain-stem>`, Mikado Branch Invariant enforced, `C2()` commit convention, PR early, push after every leaf-node closure
- **Deploy from branches** — C1 and C2 changes deploy from the unmerged branch (ArgoCD `--revision`, Ansible from checkout, etc.). Reset to main after merge.
- GitOps requires pushing to test — if a pushed commit breaks, revert it promptly

## Tools

| Command | Purpose |
|---------|---------|
| `mise run docs-mikado` | List all active Mikado chains with branch status |
| `mise run docs-mikado <card>` | Show dependency chain for a goal card |
| `mise run docs-mikado <card> --all` | Include completed cards in full |
| `mise run docs-mikado --resume` | Resume a chain: detect branch, show state and next steps |
| `mise run docs-mikado --resume <chain>` | Resume a specific chain with branch consistency check |

The `mikado-branch-invariant-check` commit-msg hook runs automatically on `mikado/*` branches, validating commit message conventions and invariant ordering. Requires `uvx pre-commit install --hook-type commit-msg`.

## Related

- [[ai-assistance-guide]] — General AI agent conventions
- [[exploring-the-docs]] — Documentation structure overview
