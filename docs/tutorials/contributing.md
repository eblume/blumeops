---
title: Contributing
date-modified: 2026-02-07
tags:
  - tutorials
  - contributing
---

# Your First Contribution

> **Audiences:** Contributor

This tutorial walks through making your first contribution to BluemeOps - from understanding the codebase to submitting a pull request.

## Prerequisites

Before contributing, you'll need:
- Access to the [[tailscale|Tailscale]] network (request from Erich)
- SSH key added to [[forgejo|Forgejo]] (https://forge.ops.eblu.me)
- Development tools installed (see below)

## Tooling Setup

The repo includes a `Brewfile` and `mise.toml` for easy setup, but these are optional - install the tools however you prefer.

### Required Tools

- `tea` - Gitea/Forgejo CLI for creating PRs
- `argocd` - ArgoCD CLI for deployments
- `pre-commit` - Git hooks for validation

### Using Brewfile (Optional)

```bash
brew bundle  # installs tea, argocd, mise, etc.
```

### Using Mise (Optional)

Mise manages language toolchains and runs tasks:
```bash
mise install  # installs Python, Node.js, etc. from mise.toml
```

### Pre-commit Hooks

Pre-commit hooks validate changes on `git commit`:
```bash
pre-commit install
pre-commit run --all-files  # verify setup
```

All hooks should pass on a fresh clone.

## Understanding the Codebase

BlumeOps manages infrastructure through three main systems:

| System | Directory | What It Manages |
|--------|-----------|-----------------|
| **Ansible** | `ansible/` | Services running directly on [[indri]] |
| **ArgoCD** | `argocd/` | Kubernetes services in the [[cluster]] |
| **Pulumi** | `pulumi/` | [[tailscale|Tailscale]] ACLs and DNS |

Most contributions involve either Ansible roles or ArgoCD manifests.

## The Contribution Workflow

### 1. Clone and Branch

```bash
git clone ssh://git@forge.ops.eblu.me:2222/eblume/blumeops.git
cd blumeops
git checkout -b feature/your-change-name
```

### 2. Make Your Changes

Depending on what you're changing:

**For Kubernetes services:**
- Edit manifests in `argocd/manifests/<service>/`
- Or create new Application in `argocd/apps/`
- For new apps, set `targetRevision` to your feature branch for testing
- For existing apps, you'll need to temporarily change the revision via `argocd app set`

**For Indri services:**
- Edit or create roles in `ansible/roles/`
- Update `ansible/playbooks/indri.yml` if adding a role

**For documentation:**
- Edit files in `docs/`
- Add changelog fragment (see below)

### 3. Add a Changelog Fragment

For user-visible changes:
```bash
echo "Description of your change" > docs/changelog.d/your-branch.feature.md
```

Fragment types (file suffix):
- `.feature.md` - New functionality
- `.bugfix.md` - Bug fixes
- `.infra.md` - Infrastructure changes
- `.doc.md` - Documentation
- `.misc.md` - Other

### 4. Test Your Changes

**Before pushing, always test:**

For Kubernetes changes:
```bash
# Preview what will change
argocd app diff <service>
```

For DNS changes:
```bash
mise run dns-preview
```

### 5. Commit and Push

```bash
git add <files>
git commit -m "Brief description of change"
git push -u origin feature/your-change-name
```

### 6. Create a Pull Request

```bash
tea pr create --title "Your PR Title" --description "$(cat <<'EOF'
## Summary
- What you changed
- Why you changed it

## Deployment and Testing
- [ ] Tested locally / dry run
- [ ] Ready for ArgoCD sync / Ansible apply

EOF
)"
```

### 7. Wait for Review

Erich will review your PR and may leave comments. Check for feedback:
```bash
mise run pr-comments <pr_number>
```

Address each comment, then Erich will:
1. Approve the changes
2. Deploy them (you don't need to do this)
3. Merge the PR

## Example: Adding a Homepage Link

A simple first contribution - adding a service to the Homepage dashboard (go.ops.eblu.me):

1. Find the service's Ingress in `argocd/manifests/<service>/`
2. Add homepage annotations:
```yaml
annotations:
  gethomepage.dev/enabled: "true"
  gethomepage.dev/name: "Service Name"
  gethomepage.dev/group: "Apps"
  gethomepage.dev/icon: "service.png"
```
3. Create PR and wait for sync

## Related

- [[adding-a-service]] - Full tutorial on deploying a new service
- [[replicating-blumeops]] - If you want to build your own instead
