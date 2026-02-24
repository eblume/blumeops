# CLAUDE.md

Guidance for Claude Code working in this repository. See also [[ai-assistance-guide]].

## Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure, orchestrated via tailnet `tail8d86e.ts.net`.

**CRITICAL: Public repo at github.com/eblume/blumeops - never commit secrets!**

**Shell:** The user's shell is **fish**. Use `$status` not `$?` for exit codes. Use fish syntax in interactive examples.

## Rules

1. **Always run `mise run ai-docs -- --style=header --color=never --decorations=always` at session start**
    This will refresh your context with important information you will be assumed to know and follow.
2. **Always use `--context=minikube-indri` with kubectl** (or `--context=k3s-ringtail` for ringtail services) - work contexts must never be touched
3. **Classify the change as C0/C1/C2 before starting** (see below) — this determines branching and PR requirements
4. **Feature branches + PRs for C1/C2** - checkout main, pull, create branch, open PR via `tea pr create`. C0 goes direct to main.
5. **Check PR comments with `mise run pr-comments <pr_number>`** before proceeding
6. **Add changelog fragments** - `docs/changelog.d/<branch>.<type>.md`
    Types: `feature`, `bugfix`, `infra`, `doc`, `ai`, `misc`
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
~/code/personal/zk      # user's Obsidian-sync managed zettelkasten. Potential source for reference data.
~/code/3rd/             # mirrored external projects
~/code/work             # FORBIDDEN
```
Other code paths will be listed via ai-docs, this is just an overview. When you
encounter wiki-links (`[[like-this]]`) it is referring to docs/ cards.

## Service Deployment

### Kubernetes (ArgoCD)

Most services run in minikube on indri via ArgoCD (app-of-apps, manual sync). GPU workloads (Frigate, Mosquitto, ntfy) run on ringtail's k3s cluster, also managed by ArgoCD.

**PR workflow:**
1. Create branch, modify `argocd/manifests/<service>/`
2. Push. Sync 'apps' app if service definition changed (set --revision to branch).
3. Test on branch: `argocd app set <service> --revision <branch> && argocd app sync <service>`
4. After merge: `argocd app set <service> --revision main && argocd app sync <service>`

**Commands:** `argocd app list|get|diff|sync <app>`

**Login:** `argocd login argocd.ops.eblu.me --username admin --password "$(op read 'op://vg6xf6vvfmoh5hqjjhlhbeoaie/srogeebssulhtb6tnqd7ls6qey/password')"`

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

## Third-Party Projects

Ask user to mirror on forge first, then clone to `~/code/3rd/<project>/`.

## Task Discovery

```fish
mise run blumeops-tasks  # fetch from Todoist, sorted by priority
```
Most tasks are stored in `./mise-tasks/`. For scripts with any logic or
complexity, use uv run --script 's with explicit dependencies. Complex
workflows with artifacts should become dagger pipelines. Mise tasks are for
development processes and operations - tools for the user or the agent.

## Credentials

Root store is 1Password. Never grab directly - use existing patterns (ansible
pre_tasks, external-secrets, scripts with `op` CLI). It's ok to use `op item
get` without `--reveal` to explore what secrets are available, however.

Prefer `op read "op://vault/item/field"` over `op item get --fields` to avoid
quoting issues with multi-line values.
