---
title: Contributing
modified: 2026-11-14
last-reviewed: 2026-11-14
tags:
  - tutorials
  - contributing
---

# Your First Contribution

> **Audiences:** Contributor

This tutorial walks through making your first contribution to BlumeOps - from understanding the codebase to submitting a pull request.

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
- `prek` - Git hooks for validation

### Using Brewfile (Optional)

```bash
brew bundle  # installs tea, argocd, mise, etc.
```

### Using Mise (Optional)

Mise manages language toolchains, runs tasks, and pins tools like `prek`:
```bash
mise install  # installs Python, Node.js, prek, etc. from mise.toml
```

### Git Hooks (prek)

Git hooks validate changes on `git commit` (prek is pinned in `mise.toml`):
```bash
prek install
prek run --all-files  # verify setup
```

All hooks should pass on a fresh clone.

## Understanding the Codebase

BlumeOps manages infrastructure through three main systems:

| System | Directory | What It Manages |
|--------|-----------|-----------------|
| **nix-darwin** | `darwin/indri/` | Host config for [[indri]], applied on merge ([[auto-apply]]) |
| **NixOS** | `nixos/ringtail/` | Host config for ringtail, applied on merge ([[auto-apply]]) |
| **ArgoCD** | `argocd/` | Kubernetes services in the [[cluster]] |
| **Pulumi** | `pulumi/` | [[tailscale|Tailscale]] ACLs and DNS |
| **Ansible** | `ansible/` | Sifaka exporters (`ansible/playbooks/sifaka.yml`) |
| **Containers** | `containers/` | Container images, built by CI on merge |

Most contributions involve either ArgoCD manifests or host flake config.

## The Contribution Workflow

### 1. Clone and Branch

```bash
git clone ssh://forgejo@forge.ops.eblu.me:2222/eblume/blumeops.git
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

**For host config (indri, ringtail):**
- Edit the flake under `darwin/indri/` or `nixos/ringtail/`

**For documentation:**
- Edit files in `docs/`
- Add changelog fragment (see below)

### 3. Add a Changelog Fragment

Every branch needs a changelog fragment, or the Docs Checks job fails it. Name it after the branch, with slashes flattened to dashes (`feature/your-change-name` → `feature-your-change-name`):
```bash
echo "Description of your change" > docs/changelog.d/feature-your-change-name.feature.md
```

If the change warrants no changelog entry, add an empty `<flattened-branch>.skip.md` instead.

Fragment types (file suffix):
- `.feature.md` - New functionality
- `.bugfix.md` - Bug fixes
- `.infra.md` - Infrastructure changes
- `.doc.md` - Documentation
- `.ai.md` - AI-assisted changes
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
- [ ] Ready for ArgoCD sync / host apply

EOF
)"
```

### 7. Wait for Review

Erich will review your PR and may leave comments. Check for feedback:
```bash
mise run pr-comments <pr_number>
```

Address each comment. Erich approves and merges the PR. Merging deploys: workload ArgoCD apps auto-sync (four are manual by design, see [[argocd]]), and changes under `darwin/indri/**` or `nixos/ringtail/**`, or the shared `forge/runners.{nix,json}`, are auto-applied to their host ([[auto-apply]]). Pulumi has no merge-time apply, so Erich applies it (`mise run tailnet-up` / `dns-up`); ask him about Sifaka (Ansible) changes.

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
