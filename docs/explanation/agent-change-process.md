---
title: Agent Change Process
modified: 2026-08-07
last-reviewed: 2026-02-23
tags:
  - explanation
  - ai
---

# Agent Change Process

> **Note:** This article was drafted by AI and reviewed by Erich. I plan to rewrite all explanatory content in my own words - these serve as placeholders to establish the documentation structure.

How to execute infrastructure changes, especially when working with AI agents that may lose context across sessions.

## How changes reach main

There are two routes, and which one applies is mostly decided by *who* you are rather than how big the change is:

| Route | When | Changelog fragment |
|-------|------|--------------------|
| **Direct to main** | An interactive human session making a small, fix-forward-safe change | Orphan prefix: `+<slug>.<type>.md` |
| **Feature branch + PR** | Everything larger, and **all remote-agent work** | Branch name: `<branch>.<type>.md` |

Remote agents have no choice in the matter: the `agents` bot is read-only on canonical, so a direct commit to `main` is not something it can do. Branch off `upstream/main`, push to `origin`, open a cross-repo PR. See `AGENTS.md` for the authoritative statement of both rules.

Multi-phase work that spans sessions is still one branch and one PR — sequence it however the work wants, and lean on the PR to carry state between sessions.

**Context loading:** start by finding and reading the docs relevant to the change area — grep `docs/` and follow wiki-links. For problems with a very large surface area, `mise run ai-sources` concatenates all non-doc source files (~270K tokens); confirm with the user before loading it wholesale.

> **Retired:** this document used to open with a C0/C1/C2 change *classification* assigned before work began, and devoted most of its length to the Mikado Branch Invariant — a commit-ordering discipline for C2 chains, enforced by a `commit-msg` hook. Both are gone: AGENTS.md replaced the classification with the two-route split above, and the Mikado apparatus (the hook, `mikado-branch-invariant-check`, `docs-mikado`, the `mikado-navigator` subagent, and the `C2(<chain>):` commit convention) was removed once no chain had used it in a long time. Old cards and commits referencing them are historical.

## Feature branch + PR

The default route for anything non-trivial, and the only route available to remote agents.

### Process

1. Find and read the docs relevant to the change area
2. **Search related docs** — read existing documentation and reference cards related to the change area
3. **Create a feature branch** and open a PR early (draft is fine)
4. **Documentation first** — commit doc changes reflecting the desired end state before writing code. This helps the reviewer understand intent and catches design issues early
5. **Implement** — commit code changes, pushing as you go. The PR gets updated along the way and the user can review and comment at any point
6. **Add changelog fragment** — `docs/changelog.d/<branch>.<type>.md` for any user-visible or noteworthy changes
7. **If the PR changed `containers/`:** build from the final branch head with `mise run container-build-and-release <name>`, then commit the resulting tag into `argocd/manifests/<service>/kustomization.yaml` **in this same PR**. No post-merge rebuild — see [[build-container-image#Container tags and merge strategy]]
8. **Deploy from the branch** — do not wait for merge:
   - **ArgoCD:** `argocd app set <service> --revision <full-40-char-sha> && argocd app sync <service>`. Pass a **SHA, never a branch name**: workload apps sync automatically, so a branch revision would make every later push to that branch deploy itself unreviewed. The `ArgoCD Deploy` workflow enforces SHA-or-`main`; hand-run commands should match it (see [[argocd#Deploying from a branch]])
   - **Ansible:** run playbooks directly from the branch checkout
   - **Workflows:** point workflow triggers at the branch if needed
9. **Approve the CI checks.** An agent PR's checks sit `pending` with no run
   until a human clicks *Approve and run* in the forge. This is deliberate —
   see [§Why agent PRs need an approval click](#why-agent-prs-need-an-approval-click)
10. After user review and successful deployment, the user merges the PR
11. **After merge:** reset any overridden revision with `argocd app set <service> --revision main`. Apps still tracking `main` need nothing — the merge deploys itself

### Build artifacts

Container images in the registry are independent of branch lifecycle — a branch reset or a rebase does not invalidate them:

- **Registry images** are build outputs cached in zot — tagged with commit SHAs, so each build is unique and traceable
- **Images built during PR development stay valid after merge.** Canonical merges with merge commits, so a branch-head SHA becomes an ancestor of main and its tag flips `[branch]` → `[main]` by itself. Build once from the final branch head and put the manifest tag bump in the same PR — no post-merge rebuild. Use `mise run container-list <name>` to check. See [[build-container-image#Container tags and merge strategy]]
- **All builds are manual** — use `mise run container-build-and-release <name>` to dispatch
- **If a build succeeds but deployment fails**, the image is fine; the problem is elsewhere. Document what you learned and try again
- **If a build fails in CI**, no image is pushed. Fix the nix/dockerfile and re-merge or re-dispatch


## Why agent PRs need an approval click

Open an agent PR and its checks show `pending` with **no workflow run behind
them**. Nothing is broken and nothing is queued: the forge is waiting for a
human to press *Approve and run*. Press it and the run is created, executes,
and reports normally.

The cause is the fence working. The `agents` bot is deliberately read-only on
canonical, which makes its PRs *outside contributions*, and Forgejo withholds
workflow runs on outside contributions until someone with write access
approves them.

**The click decides which workflow files run — not merely whether they run.**
That is the part worth remembering, because it is not what the button looks
like it does:

| Author | Which workflows execute |
|--------|-------------------------|
| Untrusted | *"the workflows found in the **target branch** of the pull request will be used instead of those found in the pull request"* |
| Trusted (*Approve always*) | *"workflows found in the **pull request content** are used … taking into account any changes done to these files as part of that pull request"* |

So trusting the bot permanently would mean an agent PR that adds a workflow with
`on: pull_request` runs **that file**, on the `indri` runner, at PR-open time —
before a human has read the diff. That is a path from "an agent wrote a file" to
"code ran on a homelab host" with no human in between, and it undoes
[[warrant-approval-gated-runs]] invariant 3 (*definitions run from `main` only*)
one layer down, in forge settings rather than in the repo.

*Approve always* was set for these workflows on 2026-08-07 and revoked the same
day for exactly that reason. Trust is per-repo per-contributor and expires after
three months idle, so a stale grant is not forever — but it should not be
granted to an agent identity at all.

### What the click does not protect

Worth knowing so the click is not mistaken for more than it is:

- **Secrets were never at risk.** Forgejo does not pass secrets to
  `pull_request` runs from forks, trusted author or not. The blumeops vault and
  the Actions secrets stay out of reach on this path.
- **Deploys were never at risk.** Privileged workflows are `workflow_dispatch`
  only on `runs-on: priv`; a pull request cannot trigger them at all. Warrant
  still gates every one.
- **Strangers are not the threat.** The instance has registration disabled, so
  nobody can fork this repo without an account Erich created. The threat model
  is prompt injection in an agent session — the case
  [[agent-containerization]] exists for.

### Do not reach for `pull_request_target`

The obvious way to skip the click is `pull_request_target`, which runs the
definition from `main` and is **not** subject to the approval gate. Resist it.
It is the one trigger that receives repository secrets *and* a write-capable
token, and it is the basis of the "pwn request" vulnerability class: the
workflow is trusted, so the moment it checks out and executes the PR's code,
the PR author has both.

It can be written safely — check out `main` for the validators, check out the PR
head into a subdirectory as **data only**, never execute a line of it — but that
discipline then has to survive every future edit by every future agent, and the
failure mode is far worse than the thing being avoided. For a check whose job is
catching a forgotten changelog fragment, it is a bad trade. There are no
`pull_request_target` workflows in this repo; adding one is a much larger
decision than its diff will look.

### The residual problem

A PR where nobody clicked shows *no* check rather than a failing one, which
reads the same as "nothing to validate". The fix is to make the Docs Checks
status **required in branch protection on `main`**, so an unrun check blocks the
merge instead of looking neutral — not to remove the gate.

## Git discipline

- **Direct to main:** interactive human sessions only, small fix-forward-safe changes
- **Feature branch + PR:** single branch, PR early, push often. The only route for remote agents
- **Changelog fragments (always):** add `docs/changelog.d/<name>.<type>.md` for any user-visible or noteworthy change. Direct-to-main uses orphan fragments (`+<descriptive-slug>.<type>.md`) to avoid `main.*` collisions and includes the fragment in the same commit; branch work uses the branch name (`<branch>.<type>.md`) and adds it during the branch.
- **Deploy from branches** — branch work deploys from the unmerged branch (ArgoCD `--revision`, Ansible from checkout, etc.). Reset to main after merge.
- GitOps requires pushing to test — if a pushed commit breaks, revert it promptly

## Related

- [[ai-assistance-guide]] — General AI agent conventions
- [[exploring-the-docs]] — Documentation structure overview
