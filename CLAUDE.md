# CLAUDE.md

Guidance for Claude Code working in this repository. See also [[ai-assistance-guide]].

## Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure, orchestrated via tailnet `tail8d86e.ts.net`.

**CRITICAL: Public repo at github.com/eblume/blumeops - never commit secrets!**

## Rules

1. **Always run `mise run zk-docs -- --style=header --color=never --decorations=always` at session start**
    This will refresh your context with important information you will be assumed to know and follow.
2. **Always use `--context=minikube-indri` with kubectl** - work contexts must never be touched
3. **Feature branches only** - checkout main, pull, create branch, commit often
4. **Create PRs via `tea pr create`** - user reviews before deploy, merges after
5. **Check PR comments with `mise run pr-comments <pr_number>`** before proceeding
6. **Add changelog fragments** - `docs/changelog.d/<branch>.<type>.md`
    Types: `feature`, `bugfix`, `infra`, `doc`, `ai`, `misc`
7. **Test before applying** - dry runs (`--check --diff`), syntax checks, `ssh indri '...'`
8. **Wait for user review before deploying**
9. **Never merge PRs or push to main without explicit request**
10. **Verify deployments** - `mise run services-check`

## Project Structure

```
./docs/                 # documentation (Diataxis, Quartz)
./docs/changelog.d/     # towncrier fragments
./mise-tasks/           # scripts via `mise run`
./ansible/playbooks/    # ansible (indri.yml primary)
./ansible/roles/        # indri service roles
./argocd/apps/          # ArgoCD Application definitions
./argocd/manifests/     # k8s manifests per service
./pulumi/               # Pulumi IaC (tailnet ACLs, cloud)
~/code/personal/        # user's projects
~/code/3rd/             # mirrored external projects
~/code/work             # FORBIDDEN
```

## Service Deployment

### Kubernetes (ArgoCD)

Most services run in minikube on indri via ArgoCD (app-of-apps, manual sync).

**PR workflow:**
1. Create branch, modify `argocd/manifests/<service>/`
2. Push, then `argocd app sync apps`
3. Test on branch: `argocd app set <service> --revision <branch> && argocd app sync <service>`
4. After merge: `argocd app set <service> --revision main && argocd app sync <service>`

**Commands:** `argocd app list|get|diff|sync <app>`

**Login:** `argocd login argocd.ops.eblu.me --username admin --password "$(op --vault vg6xf6vvfmoh5hqjjhlhbeoaie item get srogeebssulhtb6tnqd7ls6qey --fields password --reveal)"`

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

## Third-Party Projects

Ask user to mirror on forge first, then clone to `~/code/3rd/<project>/`.

## Task Discovery

```fish
mise run blumeops-tasks  # fetch from Todoist, sorted by priority
```

## Credentials

Root store is 1Password. Never grab directly - use existing patterns (ansible pre_tasks, external-secrets, scripts with `op` CLI). Warn user before any credential access.
