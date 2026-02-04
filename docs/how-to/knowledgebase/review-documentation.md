---
title: review-documentation
tags:
  - how-to
  - documentation
  - maintenance
---

# Review Documentation

How to periodically review and maintain the BlumeOps knowledge base.

## Quick Random Review

Select a random documentation card for review:

```bash
mise run doc-random
```

This displays a random card with a review checklist to guide your assessment.

## Review Checklist

When reviewing a documentation card, consider:

| Check | Description |
|-------|-------------|
| **Accuracy** | Is the information current and correct? |
| **Links** | Are wiki-links working? Should more be added? |
| **Scope** | Is the card appropriately sized (not too large/small)? |
| **Category** | Is it in the right section (reference/how-to/tutorial/explanation)? |
| **Frontmatter** | Are title and tags appropriate? |
| **Related** | Should it link to related cards? |

## Verify Deployed State

For service reference cards, verify the documentation matches reality:

### ArgoCD Apps (Kubernetes services)

Check if the app is synced and healthy:

```bash
argocd app get <app-name>
argocd app diff <app-name>  # Show pending changes
```

If out of sync, either the docs are stale or a deployment is pending.

### Ansible Roles (indri services)

Check if the role applies idempotently (no changes needed):

```bash
mise run provision-indri -- --tags <role> --check --diff
```

If changes would be made, either the docs are stale or the host has drifted.

### Pulumi (Tailscale ACLs, DNS)

Check for drift:

```bash
# Tailscale ACLs
cd pulumi/tailscale && pulumi preview

# DNS (Gandi)
cd pulumi/gandi && pulumi preview
```

If changes are pending, investigate whether docs or infrastructure is stale.

## When to Review

Consider running `mise run doc-random` during:

- Start of work sessions (quick maintenance)
- After major infrastructure changes (verify docs reflect reality)
- When learning the system (random exploration)

## Making Changes

If a card needs updates:

1. Create a feature branch
2. Make the edits
3. Run `mise run doc-links` to verify links
4. Create a PR for review

See [[update-documentation]] for publishing changes.

## Related

- [[update-documentation]] - Publishing documentation changes
- [[exploring-the-docs]] - Navigating the documentation
