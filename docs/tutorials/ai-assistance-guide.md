---
title: ai-assistance-guide
tags:
  - tutorials
  - ai
---

# AI Assistance Guide

> **Audiences:** AI, Owner

This guide provides context for AI agents (like Claude Code) assisting with BlumeOps operations, and helps Erich understand how to work effectively with AI assistance.

## Critical Rules

These are non-negotiable for AI agents working in this repo:

1. **Always use `--context=minikube-indri` with kubectl** - Work contexts exist that must never be touched
2. **Run `mise run zk-docs` at session start** - Review current infrastructure state
3. **Never commit secrets** - The repo is public at github.com/eblume/blumeops
4. **Wait for user review before deploying** - Create PRs, don't auto-deploy
5. **Never merge PRs without explicit request** - The user merges after review

Full rules are in the repo's `CLAUDE.md`.

## Workflow Conventions

### Feature Branches

All work happens on feature branches:
```bash
git checkout main && git pull
git checkout -b feature/descriptive-name
# ... make changes ...
git commit -m "Description"
```

### Pull Requests

Use the forge's `tea` CLI:
```bash
tea pr create --title "Title" --description "$(cat <<'EOF'
## Summary
- Change 1
- Change 2

## Deployment and Testing
- [ ] Test step
EOF
)"
```

### Changelog Fragments

Add a fragment for user-visible changes:
```bash
echo "Description" > docs/changelog.d/branch-name.feature.md
```

Types (file suffix): `.feature`, `.bugfix`, `.infra`, `.doc`, `.ai`, `.misc`

### Wiki-Link Formatting

Use simple wiki-links without alternate text or extra spaces:
- Prefer `[[borgmatic]]` over `[[borgmatic | Borgmatic]]`
- Only use alternate text when grammatically warranted (e.g., `[[cluster|Kubernetes]]` reads better than `[[cluster]]`)
- No spaces around the pipe: `[[path|Text]]` not `[[ path | Text ]]`

When editing documentation, rewrite links to follow this convention as you encounter them.

## Service Locations

Understanding where services run helps target changes correctly:

| Location | Services | Management |
|----------|----------|------------|
| [[indri]] (native) | Forgejo, Zot, Jellyfin, Caddy | Ansible |
| [[cluster|Kubernetes]] | Everything else | ArgoCD |

## Mise Tasks

BlumeOps operations are driven by mise tasks. Run `mise tasks` to list all available tasks.

| Task | When to Use |
|------|-------------|
| `zk-docs` | At session start - review infrastructure documentation |
| `provision-indri` | Deploy changes to [[indri]]-hosted services via Ansible |
| `services-check` | After deployments - verify all services are healthy |
| `pr-comments` | Check unresolved PR comments during review |
| `blumeops-tasks` | Find pending tasks from Todoist |
| `container-list` | View available container images and tags |
| `container-tag-and-release` | Release a new container image version |
| `dns-preview` | Preview DNS changes before applying |
| `dns-up` | Apply DNS changes via Pulumi |
| `tailnet-preview` | Preview Tailscale ACL changes |
| `tailnet-up` | Apply Tailscale ACL changes via Pulumi |
| `doc-links` | Validate wiki-links in documentation |
| `doc-titles` | Check for duplicate doc titles |
| `doc-filenames` | Check for duplicate doc filenames |
| `doc-random` | Select a random doc card for review |
| `indri-runner-logs` | View Forgejo workflow logs from local runner |

For ArgoCD operations, use the `argocd` CLI directly:
- `argocd app diff <service>` - Preview changes
- `argocd app sync <service>` - Deploy changes

## Reference Navigation

For AI agents building context:

- [[reference/index|Reference Index]] - Entry point for technical details
- [[hosts|Host Inventory]] - What hardware exists
- [[apps|ArgoCD Apps]] - What's deployed in Kubernetes
- [[routing|Routing]] - How services are exposed

## Credential Access

Credentials live in 1Password. Never retrieve them directly - use existing patterns:
- Ansible `pre_tasks` gather secrets at playbook start
- [[external-secrets]] syncs to Kubernetes
- Scripts use `op` CLI with user biometric prompts

## Common Pitfalls

| Pitfall | Correct Approach |
|---------|------------------|
| Missing kubectl context | Always add `--context=minikube-indri` |
| Deploying without review | Create PR first, wait for user approval |
| Re-explaining reference material | Link to reference cards instead |
| Committing to main | Use feature branches |
| Guessing at credentials | Ask user or check 1Password patterns |
