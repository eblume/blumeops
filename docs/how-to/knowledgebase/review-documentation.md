---
title: Review Documentation
tags:
  - how-to
  - documentation
  - maintenance
---

# Review Documentation

How to periodically review and maintain the BlumeOps knowledge base.

## Review by Staleness

Show docs sorted by when they were last reviewed (most stale first):

```bash
mise run docs-review
```

This reads the `last-reviewed` frontmatter field from each card. Cards without the field are treated as never-reviewed and appear at the top. The script shows a staleness table and then displays the most stale card with a review checklist.

To show more entries in the table:

```bash
mise run docs-review -- --limit 30
```

### Marking a Card as Reviewed

After reviewing a card, add or update the `last-reviewed` field in its frontmatter:

```yaml
---
title: Some Card
last-reviewed: 2026-02-09
tags:
  - reference
---
```

Commit this change alongside any fixes you make during the review.

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

## Making Changes

If a card needs updates:

1. Create a feature branch
2. Make the edits
3. Run `mise run docs-check-links` to verify links
4. Create a PR for review

See [[update-documentation]] for publishing changes.

## Related

- [[update-documentation]] - Publishing documentation changes
- [[exploring-the-docs]] - Navigating the documentation
