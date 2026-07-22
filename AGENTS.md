# AGENTS.md

Guidance for AI agents working in this repository. See also [[ai-assistance-guide]].

## Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure, orchestrated via tailnet `tail8d86e.ts.net`.

**CRITICAL: Public repo at github.com/eblume/blumeops - never commit secrets!**

**Shell:** The user's interactive shell may differ from the current harness
shell, but the user's preferred shell is fish. Configuration is managed by
chezmoi.

** Environment:** Agent's harness could be running either interactively from
various hosts (gilbert (macos/arm64) or ringtail (nixos/amd64)), or it could be
running in a remote-agent session on ringtail with restricted access to
infrastructure. When running as a remote-agent, agents work product should be
gitops (PRs typically preferred, some branches protected), with user-executed
deployment actions. When operating outside of remote-agent, it's OK to use "op"
to query for secrets to assist in deployment directly, because the user will
need to confirm through biometric approval.

## Rules

1. **Start every task by finding and reading the relevant docs and context**.
2. **Fork + PRs (bot is read-only on canonical).** The `agents` bot has **read**
   on `eblume/blumeops` and authors via its fork `agents/blumeops` — the clone's
   `origin` is the fork, `upstream` is canonical. Branch off `upstream/main`,
   push to `origin`, and open a **cross-repo** PR:
   `tea pr create --repo eblume/blumeops --base main --head agents:<branch>`.
   `git fetch upstream` before working. The bot **cannot** push to
   `eblume/blumeops` or commit to `main` directly (that's a human, from gilbert).
3. Create, use, and modify tooling via the `mise run` system to provide tooling for users and agents.
4. **Add changelog fragments (all change levels)** - `docs/changelog.d/<name>.<type>.md`
    Types: `feature`, `bugfix`, `infra`, `doc`, `ai`, `misc`
    - **Feature branch/PR** Use branch name: `<branch>.<type>.md`
    - **Direct to main:** Use orphan prefix: `+<descriptive-slug>.<type>.md` (avoids `main.*` collisions)
5. Create, use, and modify forgejo workflows to enforce PR validity.
6. **Verify deployments** - `mise run services-check`

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
**New services should use locally built containers** (Nix `dockerTools`,
pulled from `registry.ops.eblu.me` with source mirrored on
forge.ops.eblu.me) for supply-chain control. This is guidance for new work,
not a campaign to retroactively localize everything — some upstream images
(e.g. frigate's TensorRT build, immich's CUDA ML stack, the CloudNativePG
PostgreSQL operands) are impractical to rebuild and stay on their upstream
registries.

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
which read from Todoist.) If this agent doesn't have access to heph, there is a problem, and the agent should propose a fix to add it depending on the current context.

### Reading tasks

```fish
heph list --project Blumeops --json --due # outstanding Blumeops tasks as JSON
heph show <node_id>                       # one task with its scalars
heph context <node_id>                    # print the task's canonical-context doc
heph log <node_id>                        # print the task's latest log entries
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

Root store is 1Password. Never expose directly - use existing patterns (ansible
pre_tasks, external-secrets, scripts with `op` CLI). It's ok to use `op item
get` without `--reveal` to explore what secrets are available, however.

Prefer `op read "op://vault/item/field"` over `op item get --fields` to avoid
quoting issues with multi-line values.

remote-agent sessions operate with a restricted service token that provides access only to the "agents" vault. Some scripts will fail to work - it is OK to propose changes to the workflow or to request new credentials to accomplish the goal, but this must always involve user approval by design.
