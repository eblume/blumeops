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
3. Create, use, and modify tooling via the `mise run` system to provide tooling
   for users and agents. **Tasks whose description starts with `[human]` cannot
   run from an agent pod** — they need the blumeops vault, a tool the talos
   image does not carry, or an ssh route to a host the pod cannot reach. That is
   the fence, not a bug. Check `mise tasks` before reaching for one; if you need
   its *effect*, file a request (see §Privileged actions) or ask.

   Where the blocker is a **missing binary**, guard it at the point of use with
   `"$(dirname "$0")/_require" docker kubectl` under `set -euo pipefail`, so the
   task refuses with an explanation instead of half-running. Guard only what
   mise itself cannot supply — `mise.toml` installs dagger, pulumi,
   ansible-core and flyctl into the pod, so those are present inside
   `mise run`. Vault- and route-blocked tasks need no guard: `op` and `ssh`
   already fail legibly on their own.
4. **The lint gate runs automatically.** The pod's entrypoint installs
   prek git hooks (pre-commit + pre-push) into every pool clone that carries
   a `prek.toml`, and session worktrees inherit them — so commits and pushes
   of blumeops already run the PR prek job's hook set (everything except
   prettier — a node hook, and the agent pod ships no node) before anything
   leaves the pod. Bypass deliberately with `git commit/push --no-verify`.
   `mise run agent-lint` is the same gate on demand. Agent PR checks sit
   pending until a human clicks approve-and-run, so a lint failure caught
   late costs a review round; `container-version-check` mismatches in
   particular are cheap to catch locally.
5. **Add changelog fragments (all change levels)** - `docs/changelog.d/<name>.<type>.md`
    Types: `feature`, `bugfix`, `infra`, `doc`, `ai`, `misc`
    - **Feature branch/PR** Use branch name: `<branch>.<type>.md`
    - **Direct to main:** Use orphan prefix: `+<descriptive-slug>.<type>.md` (avoids `main.*` collisions)
    - **Flatten slashes to dashes**: branch `agent/foo` → `agent-foo.<type>.md`,
      never `agent/foo.<type>.md`. Towncrier reads flat files only and skips
      subdirectories silently, so a nested fragment is simply lost.
      `mise run changelog-check` catches it, and **Docs Checks** runs on every PR.
6. Create, use, and modify forgejo workflows to enforce PR validity.
7. **Verify deployments** - `mise run agent-health` (Grafana alert state; works
   from anywhere). For anything alerts don't answer — restart counts, pod ages,
   whether last week's change moved the needle — `mise run agent-metrics
   '<promql>'` queries Prometheus through Grafana with the same credential.
   `increase(metric[30d])` covers "how much over the last month" in one query.
   `mise run services-check` is the fuller `[human]` check — it needs kubectl
   and ssh, so it is a gilbert job.

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

## Privileged actions: request, don't ask

Agents cannot deploy, build containers, or run vault-backed scripts directly
— and don't need to ask for them in prose either. **File a request:**

```fish
mise run request-run <workflow> <full-40-char-sha> --pr <N> \
    [-i key=value ...] --why "one line"
```

Pass `--repo owner/name` when the PR the request is about lives in another
repo (e.g. `--repo eblume/talos`) — the workflow, the bound SHA, and the
dispatch stay blumeops; only the attached PR moves.

It validates the request against `warrant-policy.yaml` **on main**
(unknown or `class: deny` actions are refused at request time), then records
it as a PR comment, a heph task, and an entry in the approval queue. A human
approves in Horkos (né Warrant), which dispatches the workflow. Requestable today:
`argocd-deploy.yaml`, `build-container.yaml`, `deploy-fly.yaml`.

`mise run verify-runs` closes the loop afterwards; `mise run agent-health`
checks the fleet without cluster access. Adding a new privileged workflow
means adding its `warrant-policy.yaml` entry **in the same PR** — capability
and boundary get reviewed together.

See [[request-a-privileged-run]], [[horkos]], and
[[warrant-approval-gated-runs]] for the design and its invariants.

## Service Deployment

### Kubernetes (ArgoCD)

All Kubernetes workloads (including ArgoCD itself) run on ringtail's k3s cluster via ArgoCD (app-of-apps).

**Workload apps sync themselves.** A manifest change merged to `main` reaches
the cluster on its own, within ArgoCD's reconciliation interval — the PR review
and merge *are* the gate ([[argocd#Sync Policy]]). **Do not follow a merge with
a deploy.** It is not merely redundant: you are racing the auto-sync your own
merge started, and `argocd app set` loses that race with `another operation is
already in progress`.

Four applications are **manual** by design, each with its reason stated in its
manifest: `apps`, `argocd`, `cloudnative-pg-ringtail`,
`external-secrets-crds-ringtail`. Those are the ones that do need an explicit
deploy after merge.

**PR workflow:**
1. Create branch, modify `argocd/manifests/<service>/`
2. Push. Sync the `apps` app if the Application definition itself changed.
3. Optional, to test before merging: `argocd app set <service> --revision <branch> && argocd app sync <service>`
4. Merge. An auto-sync app deploys itself. Only if you pinned in step 3, undo
   it: `argocd app set <service> --revision main`

**Commands:** `argocd app list|get|diff|sync <app>`

**From an agent session** none of the above is available — there is no `argocd`
binary in the pod and no cluster access. The only path is `mise run request-run
argocd-deploy.yaml …` (see §Privileged actions), and it is warranted for one of
three reasons: one of the four manual apps, pinning an application to a
revision, or undoing such a pin. If you are reaching for it because you just
merged a manifest, stop — that deploy has already happened.

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
`container-list` reads `registry.ops.eblu.me`, which is tailnet-only. From an
agent pod, route it through the sidecar — `ALL_PROXY=socks5://localhost:1055
mise run container-list`. Without it the task now fails loudly rather than
reporting every container as untagged.
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
