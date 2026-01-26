# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

blumeops is Erich Blume's GitOps repository for personal infrastructure management, orchestrated via tailnet `tail8d86e.ts.net`.

**Critical: This repository is published publicly at https://github.com/eblume/blumeops, so never include any secrets!**

## Rules

1. **CRITICAL: Always use `--context=minikube-indri` with kubectl commands.** The user has work contexts configured that must never be touched. Every kubectl command must explicitly specify the context to prevent accidental operations against the wrong cluster.

2. At the start of every session, even if the user asked to do something else, run `mise run zk-docs -- --style=header --color=never --decorations=always` in order to review the `blumeops` documentation in the zettelkasten (zk). zk lives at `~/code/personal/zk`, and is managed via obsidian-sync (not git).

3. When making any changes, start by making sure you're on the `main` git branch and up-to-date, and then create a feature branch. Commit often while working, and create a PR using:
```fish
tea pr create --title "Description of change" --description "$(cat <<'EOF'
## Summary
- First change
- Second change

## Deployment and Testing
- [x] Done thing one
- [ ] Needed thing two

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
The user will review your work as you go, and will merge the PR as the last step in the process, even after deploying. After the user reviews the PR and leaves comments, check for unresolved comments with:
```fish
mise run pr-comments <pr_number>
```
Address each unresolved comment before proceeding. The user will resolve comments on the Forge UI as they are addressed.

4. Always keep the zk cards up to date with any changes, and suggest new links to new cards whenever appropriate. Refer back to the zk docs often during the process of planning and making corrections to ensure accuracy, and if you make a mistake, figure out a way to guard against it using the zk.

5. Use `Brewfile` and `mise.toml` to install tools needed on the development workstation (typically hostnamed "gilbert", username "eblume").

6. Services are hosted either on indri directly (via ansible) or in Kubernetes (via ArgoCD). See the "Service Deployment" section below for details.

7. Try to always test changes before applying them. Use syntax checkers, do dry runs (`--check --diff`), run commands manually via `ssh indri 'some command'`, etc.

8. **Wait for user review before deploying.** After creating a PR, do not run deployment commands until the user has had a chance to review the changes. The user will indicate when they're ready to deploy.

9. After deploying changes, try to verify the result. Use `mise run indri-services-check` to do a general service health check.

## Project Structure

```
./mise-tasks/           # management and utility scripts run via `mise run`
./ansible/playbooks/    # ansible playbooks (indri.yml is primary)
./ansible/roles/        # ansible roles for indri-hosted services
./argocd/apps/          # ArgoCD Application definitions (app-of-apps pattern)
./argocd/manifests/     # Kubernetes manifests for each service
./pulumi/               # Pulumi IaC for tailnet ACLs and cloud resources
~/code/personal/        # projects managed by the user
~/code/3rd/             # external projects, mirrored or downloaded
~/code/work             # FORBIDDEN, never go here, avoid searching it
```

## Service Deployment

### Kubernetes Services (via ArgoCD)

Most services run on `k8s.tail8d86e.ts.net`, via minikube on indri. They are managed via ArgoCD using the app-of-apps pattern:

- **Application definitions**: `argocd/apps/<service>.yaml`
- **Manifests**: `argocd/manifests/<service>/`
- **Sync policy**: Manual sync (no auto-sync on git push)

**PR workflow for k8s services:**

1. Create feature branch and add/modify manifests
2. Push branch to forge
3. Sync the `apps` application to pick up new Application definitions:
   ```fish
   argocd app sync apps
   ```
4. Point the service app at the feature branch for testing:
   ```fish
   argocd app set <service> --revision feature/branch-name
   argocd app sync <service>
   ```
5. Test the deployment
6. After PR merge, reset to main and resync:
   ```fish
   argocd app set <service> --revision main
   argocd app sync <service>
   ```

**Useful commands:**
```fish
argocd app list                                        # List all apps
argocd app get <app>                                   # Get app details
argocd app diff <app>                                  # Preview changes before sync
argocd app sync <app>                                  # Sync an app
kubectl --context=minikube-indri get pods -n <namespace>  # Check pods
kubectl --context=minikube-indri logs -n <namespace> <pod>  # View logs
```

Note: The user has fish abbreviations `ki` for `kubectl --context=minikube-indri` and `k9i` for `k9s --context=minikube-indri`, but these only work in interactive shells.

**ArgoCD login (when token expires):**
```fish
argocd login argocd.ops.eblu.me --username admin --password "$(op --vault vg6xf6vvfmoh5hqjjhlhbeoaie item get srogeebssulhtb6tnqd7ls6qey --fields password --reveal)"
```

### Indri Services (via Ansible)

Some services run directly on indri outside of Kubernetes:
- **Forgejo** - Git forge at `forge.ops.eblu.me` (HTTPS: 443, SSH: 2222)
- **Zot Registry** - Container registry at `registry.ops.eblu.me` (k8s depends on it)
- **Caddy** - Reverse proxy for `*.ops.eblu.me` with TLS via ACME DNS-01
- **Borgmatic** - Backup system
- **Grafana Alloy** - Metrics/logs collector

**Deployment:**
```fish
mise run provision-indri                    # Full playbook
mise run provision-indri -- --tags <role>   # Specific role
mise run provision-indri -- --check --diff  # Dry run
```

### Service Routing

**External DNS (`*.ops.eblu.me`)** - Services accessible from anywhere on the tailnet, including k8s pods and docker containers:
- Managed via Caddy reverse proxy on indri
- DNS points to indri's Tailscale IP (100.98.163.89)
- TLS certificates via Let's Encrypt (ACME DNS-01 with Gandi)
- Config: `ansible/roles/caddy/`

**Tailscale MagicDNS (`*.tail8d86e.ts.net`)** - Services only accessible from Tailscale clients:
- K8s services use Tailscale Ingress (via tailscale-operator)
- Some legacy services still use `tailscale serve`
- Cannot be reached from k8s pods or docker containers (they're not Tailscale clients)

Use `ssh indri 'tailscale serve status --json'` to check current tailscale serve entries.

## Container Image Releases

```fish
mise run container-list                       # Show containers and recent tags
mise run container-release runner v1.0.0      # Tag and trigger build workflow
```

## Third-Party Projects

When a task requires cloning or using a third-party git repository (e.g., for building from source), **ask the user to mirror it on forge first**, then clone from the mirror:
- Mirror location: `https://forge.ops.eblu.me/eblume/<project>.git`
- Clone to: `~/code/3rd/<project>/`

This avoids external dependencies and ensures the project is available even if the upstream is unreachable.

## Task Discovery

To discover pending blumeops tasks, run:

```fish
mise run blumeops-tasks
```

This fetches tasks from the "Blumeops" project in Todoist (via 1Password for API credentials) and displays them sorted by priority: p1 (urgent), p2 (high), p4 (normal/default), p3 (backlog). The typical workflow is to pick a task from this list at the start of a session, then dive in with planning.

## Credentials

The root store for credentials is 1password, which can be accessed via `op --vault <vaultid> item get <itemid> --field fieldname --reveal`, which will prompt the user for their assent and biometrics or password. Typically, use scripts to defer this action - try not to ever grab credentials directly. For instance, the indri.yml playbook starts with `pre_tasks` to gather the relevant secrets needed to provision its services. Some services have their credentials exported to files `chmod 0600` on indri, but they still start out in 1password. In some cases you can test services with a command that grabs the credential, but try to use environment variables or other arrangements to avoid learning the credential yourself, and warn the user first.
