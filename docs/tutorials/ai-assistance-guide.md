---
title: AI Assistance Guide
modified: 2026-07-19
last-reviewed: 2026-07-19
tags:
  - tutorials
  - ai
---

# AI Assistance Guide

> **Audiences:** AI, Owner

This guide provides context for AI agents assisting with BlumeOps operations, and helps Erich understand how to work effectively with AI assistance.

## Critical Rules

These are non-negotiable for AI agents working in this repo:

1. **Always pass an explicit kubectl context: `--context=k3s-ringtail`** - Work contexts (`eks-*`) exist that must never be touched. (The retired `minikube-indri` context may still linger in kubeconfigs — it is dead; see [[retire-minikube]].)
2. **Start every task by finding and reading the relevant docs** - Grep `docs/` and follow wiki-links
3. **Never commit secrets** - The repo is public at github.com/eblume/blumeops
4. **Wait for user review before deploying** - Create PRs, don't auto-deploy
5. **Never merge PRs without explicit request** - The user merges after review

Full rules are in the repo's `AGENTS.md`. See [[agent-change-process]] for the two routes a change can take — direct to main (interactive human sessions, small fixes) and feature branch + PR (everything else, and all remote-agent work) — plus the Mikado Branch Invariant for multi-phase chains.

## Workflow Conventions

### Branching

Which route applies (see [[agent-change-process]]):

- **Direct to main:** interactive human session, small fix-forward-safe change — no branch or PR needed. Not available to remote agents, which are read-only on canonical
- **Feature branch + PR:** everything else
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
# branch work: use branch name
echo "Description" > docs/changelog.d/branch-name.feature.md

# direct to main: use orphan prefix (no branch to name after)
echo "Description" > docs/changelog.d/+descriptive-slug.feature.md
```

Types (file suffix): `.feature`, `.bugfix`, `.infra`, `.doc`, `.ai`, `.misc`

### Wiki-Link Formatting

Use simple wiki-links without alternate text or extra spaces:
- Prefer `[[borgmatic]]` over `[[borgmatic|Borgmatic]]`
- Only use alternate text when grammatically warranted (e.g., `[[cluster|Kubernetes]]` reads better than `[[cluster]]`)
- No spaces around the pipe: `[[path|Text]]` not `[[ path|Text ]]`

When editing documentation, rewrite links to follow this convention as you encounter them.

## Service Locations

Understanding where services run helps target changes correctly:

| Location | Services | Management |
|----------|----------|------------|
| [[indri]] (native) | Forgejo, Zot, Caddy, Borgmatic, Alloy | Ansible |
| [[indri]] (native) | Jellyfin | LaunchAgent (not Ansible-managed) |
| [[cluster|Kubernetes]] (k3s on [[ringtail]]) | Everything else | ArgoCD |

## Mise Tasks

BlumeOps operations are driven by mise tasks. Run `mise tasks` to list all available tasks.

| Task | When to Use |
|------|-------------|
| `ai-sources` | Deep context - all non-doc source files (~270K tokens). Ask user before running; useful for problems with a large surface area (see [[mise-tasks]]) |
| `docs-mikado` | View active Mikado dependency chains for C2 changes |
| `docs-mikado --resume` | Resume a C2 chain: detect branch, show state and next steps |
| `provision-indri` | Deploy changes to [[indri]]-hosted services via Ansible |
| `services-check` | After deployments - verify all services are healthy |
| `pr-comments` | Check unresolved PR comments during review |
| `container-list` | View available container images and tags |
| `container-build-and-release` | Trigger container build workflows |
| `dns-preview` | Preview DNS changes before applying |
| `dns-up` | Apply DNS changes via Pulumi |
| `tailnet-preview` | Preview Tailscale ACL changes |
| `tailnet-up` | Apply Tailscale ACL changes via Pulumi |
| `docs-check-links` | Validate wiki-links resolve correctly (supports path-based links, orphan detection) |
| `docs-review-stale` | Report docs by last-modified date, highlight stale ones |
| `docs-review-tags` | Print frontmatter tag inventory across all docs |
| `docs-review` | Review the most stale doc by last-reviewed date |
| `runner-logs` | View Forgejo workflow logs (indri or ringtail runner) |

For task discovery, BlumeOps tasks live in [hephaestus](https://github.com/eblume/hephaestus) (`heph`), not Todoist. List outstanding work with `heph list --project Blumeops --json --due`.

For ArgoCD operations, use the `argocd` CLI directly:
- `argocd app diff <service>` - Preview changes
- `argocd app sync <service>` - Deploy changes

## Reference Navigation

For AI agents building context:

- [Reference](/reference/) - Entry point for technical details
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
| Missing kubectl context | Always add `--context=k3s-ringtail` |
| Deploying without review | Create PR first, wait for user approval |
| Re-explaining reference material | Link to reference cards instead |
| Committing to main from a remote-agent session | Branch and open a PR — the `agents` bot cannot push canonical `main` |
| Guessing at credentials | Ask user or check 1Password patterns |
