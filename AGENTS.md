# AGENTS.md

Guidance for AI agents working in this repository. See also [[ai-assistance-guide]].

## Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure, orchestrated via tailnet `tail8d86e.ts.net`.

**CRITICAL: Public repo at github.com/eblume/blumeops - never commit secrets!**

**Shell:** The user's interactive shell may differ from the current harness shell. Prefer repo-safe, non-interactive commands when possible, and match the user's shell conventions when giving interactive examples.

## Rules

1. **Start every task by finding and reading the relevant docs**
    Search `docs/` for cards related to the change area (grep for titles/tags, follow `[[wiki-links]]`) and read what you find before acting. Wiki-links refer to cards under `docs/` by filename stem.
    For problems with a very large surface area, `mise run ai-sources` concatenates all non-doc source files (~270K tokens) — opt-in only, confirm with the user before loading it wholesale; targeted reading is usually better.
2. **Always use `--context=k3s-ringtail` with kubectl** — it is the only blumeops cluster (minikube on indri was retired 2026-06, see [[retire-minikube]]); work contexts must never be touched
3. **Classify the change as C0/C1/C2 before starting** (see below) — this determines branching and PR requirements
4. **Feature branches + PRs for C1/C2** - checkout main, pull, create branch, open PR via `tea pr create`. C0 goes direct to main.
5. **Check PR comments with `mise run pr-comments <pr_number>`** before proceeding
6. **Add changelog fragments (all change levels)** - `docs/changelog.d/<name>.<type>.md`
    Types: `feature`, `bugfix`, `infra`, `doc`, `ai`, `misc`
    Applies to C0, C1, and C2 whenever the change is user-visible or noteworthy.
    - **C1/C2:** Use branch name: `<branch>.<type>.md`
    - **C0:** Use orphan prefix: `+<descriptive-slug>.<type>.md` (avoids `main.*` collisions)
7. **Test before applying** - dry runs (`--check --diff`), syntax checks, `ssh indri '...'`
8. **Wait for user review before deploying** (C1/C2)
9. **Never merge PRs or push to main without explicit request** (C0 commits to main are fine)
10. **Verify deployments** - `mise run services-check`

## Change Classification

Before starting work, classify the change:

| Class | Name | When to use | Key trait |
|-------|------|-------------|-----------|
| **C0** | Quick Fix | Small, low-risk, fix-forward safe | Direct to main, no PR |
| **C1** | Human Review | Moderate complexity or risk | Feature branch + PR, docs-first |
| **C2** | Mikado Chain | Multi-phase, multi-session, high complexity | Mikado Branch Invariant |

**C0** — commit directly to main. No branch or PR needed. Fix forward if problems arise.

**C1** — feature branch with early PR. Search related docs first, write documentation changes before code, deploy from the unmerged branch (ArgoCD `--revision`, Ansible from checkout). Upgrade to C2 if complexity spirals.

**C2** — branch `mikado/<chain-stem>` governed by the Mikado Branch Invariant: all card commits first, then code progress, then card closures. Commits use `C2(<chain>): plan/impl/close/finalize` convention. Reset the branch when new prerequisites are discovered. Resume with `mise run docs-mikado --resume`.

See [[agent-change-process]] for the full methodology.

## Project Structure

```
./docs/                 # documentation (Diataxis, Quartz)
./docs/changelog.d/     # towncrier fragments
./.dagger/              # dagger pipelines
./.forgejo/             # forgejo-runner actions and workflows
./mise-tasks/           # scripts via `mise run`
./ansible/playbooks/    # ansible (indri.yml primary)
./ansible/roles/        # indri service roles
./argocd/apps/          # ArgoCD Application definitions
./argocd/manifests/     # k8s manifests per service
./fly/                  # fly.io proxy for public routing
./pulumi/               # Pulumi IaC (tailnet ACLs, dns, cloud)
~/.config/{nvim,fish}   # user's shell config, managed by chezmoi
~/code/personal/        # user's projects
~/code/personal/zk      # user's zettelkasten (Obsidian-sync). Reference-data source; migrating into heph docs (hephaestus).
~/code/3rd/             # mirrored external projects
~/code/work             # FORBIDDEN
```
This is just an overview — explore `docs/` for the rest. When you
encounter wiki-links (`[[like-this]]`) it is referring to docs/ cards.

## Service Deployment

### Kubernetes (ArgoCD)

All Kubernetes workloads (including ArgoCD itself) run on ringtail's k3s cluster via ArgoCD (app-of-apps, manual sync).

**PR workflow:**
1. Create branch, modify `argocd/manifests/<service>/`
2. Push. Sync 'apps' app if service definition changed (set --revision to branch).
3. Test on branch: `argocd app set <service> --revision <branch> && argocd app sync <service>`
4. After merge: `argocd app set <service> --revision main && argocd app sync <service>`

**Commands:** `argocd app list|get|diff|sync <app>`

**Login:** `argocd login argocd.ops.eblu.me --sso` (opens browser for Authentik SSO). Admin fallback for break-glass: `argocd login argocd.ops.eblu.me --username admin --password "$(op read 'op://vg6xf6vvfmoh5hqjjhlhbeoaie/srogeebssulhtb6tnqd7ls6qey/password')"`

### Indri (Ansible)

Native services: Forgejo, Zot, Caddy, Borgmatic, Alloy

```fish
mise run provision-indri                    # full
mise run provision-indri -- --tags <role>   # specific
mise run provision-indri -- --check --diff  # dry run
```

### Routing

| Domain | Mechanism | Reachable from |
|--------|-----------|----------------|
| `*.eblu.me` | Fly.io proxy (Tailscale tunnel) | public internet |
| `*.ops.eblu.me` | Caddy on indri | k8s pods, containers, tailnet |
| `*.tail8d86e.ts.net` | Tailscale MagicDNS | tailnet clients only |

Check tailscale serve: `ssh indri 'tailscale serve status --json'`

## Container Releases

```fish
mise run container-list                       # show images/tags
mise run container-release <name> <version>   # tag and build
```
The goal is to eventually use only locally built containers in all cases, with
full supply chain control via forge.ops.eblu.me repositories, mirroring source
from upstream.

**After triggering a build** (manual dispatch or push to main), verify the
workflow succeeded before proceeding:

```fish
mise run runner-logs                          # find the run number
mise run runner-logs <run#>                   # see jobs in the run
mise run runner-logs <run#> -j <N>            # fetch logs on failure
```

This also works for other forge repos (`--repo eblume/hermes`).

## Third-Party Projects

Ask user to mirror on forge first, then clone to `~/code/3rd/<project>/`.

### Sporked Projects

Some mirrored projects are "sporked" — a floating-branch soft-fork strategy
where local patches are continuously rebased on top of upstream. See
[[spork-strategy]] and [[create-a-spork]] for the full methodology.

Sporked projects live in `~/code/3rd/<project>/` with three remotes:
`origin` (eblume/ fork on forge), `mirror` (mirrors/ on forge), `upstream`
(canonical). The `blumeops` branch is the default; `deploy` merges everything.

Create a new spork: `mise run spork-create <mirror-name>`

## Task Discovery

BlumeOps tasks live in [hephaestus](https://github.com/eblume/hephaestus) (`heph`),
the user's self-hosted context/task system. The CLI is a thin client of the
local `hephd` daemon. (This replaced the retired `blumeops-tasks` mise task,
which read from Todoist.)

### Reading tasks

```fish
heph list --project Blumeops --json   # outstanding Blumeops tasks as JSON
heph next                             # tactical "what is next?" ranking
heph show <node_id>                   # one task with its scalars
heph context <node_id>                # print the task's canonical-context doc
heph log <node_id>                    # print the task's latest log entries
```

JSON rows carry `node_id` (use this as `<ID>` in all commands below), `title`,
`state`, `do_date`/`late_on` (epoch ms), `recurrence` (RFC-5545), and
`attention` (red|orange|white|blue — a1–a4 urgency tiers; blue = on-deck).

### Manipulating tasks

```fish
heph done <node_id>                   # mark done (recurring tasks roll forward)
heph drop <node_id>                   # mark dropped
heph skip <node_id>                   # skip a recurring task's current occurrence
heph log <node_id> "text"             # append a log entry
heph context <node_id> --append "…"   # append to the canonical-context doc (--body replaces; `-` reads stdin)
heph edit <node_id> --do-date +3d     # reschedule; also --late-on/--recur/--attention/--project (`none` clears)
heph task "Title" --project Blumeops --do-date fri --attention white  # create a task
```

Date forms: `today|tomorrow|+3d|fri|YYYY-MM-DD`. Recurrence: presets
(`daily|weekly|monthly|yearly|weekdays`) or natural language (`"every 3 days"`).

Conventions: don't save TODOs to agent memory — file them as heph tasks under
the Blumeops project. When completing a recurring chore (e.g. "BlumeOps doc
review"), `heph log` a short note of what was done, then `heph done` it.

Most operational scripts are stored in `./mise-tasks/`. For scripts with any logic or
complexity, use uv run --script 's with explicit dependencies. Complex
workflows with artifacts should become dagger pipelines. Mise tasks are for
development processes and operations - tools for the user or the agent.

## Credentials

Root store is 1Password. Never grab directly - use existing patterns (ansible
pre_tasks, external-secrets, scripts with `op` CLI). It's ok to use `op item
get` without `--reveal` to explore what secrets are available, however.

Prefer `op read "op://vault/item/field"` over `op item get --fields` to avoid
quoting issues with multi-line values.
