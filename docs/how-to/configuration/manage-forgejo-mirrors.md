---
title: Manage Forgejo Mirrors
modified: 2026-02-26
last-reviewed: 2026-02-26
tags:
  - how-to
  - forgejo
  - git
---

# Manage Forgejo Mirrors

How Forgejo upstream mirrors work, how to create new mirrors, and how to rotate the GitHub PAT used for authenticated sync.

## Overview

BlumeOps mirrors upstream repositories (mostly from GitHub) into the `mirrors/` organization on forge. These are **pull mirrors** — Forgejo periodically fetches from the upstream URL and updates the local copy. ArgoCD and other consumers then read from forge instead of hitting upstream directly.

### Why Authenticate

GitHub rate-limits unauthenticated git fetch/clone over HTTPS. As of May 2025, these limits were tightened significantly. All mirrors should use an authenticated `clone_addr` (via a GitHub fine-grained PAT) to avoid throttling.

The GitHub PAT is stored in 1Password:

| Property | Value |
|----------|-------|
| **Vault** | blumeops (`vg6xf6vvfmoh5hqjjhlhbeoaie`) |
| **Item** | Forgejo Secrets (`w3663ffnvkewbftncqxtcpeavy`) |
| **Field** | `github-mirror-pat` |
| **op ref** | `op://blumeops/w3663ffnvkewbftncqxtcpeavy/github-mirror-pat` |

### Sync Interval

Mirror sync frequency is controlled by two settings in `app.ini`:

| Setting | Section | Default | Purpose |
|---------|---------|---------|---------|
| `DEFAULT_INTERVAL` | `[mirror]` | `8h` | How often each mirror checks for upstream changes |
| `MIN_INTERVAL` | `[mirror]` | `10m` | Floor for per-repo interval overrides |
| `SCHEDULE` | `[cron.update_mirrors]` | `@every 10m` | How often the cron scans for due mirrors |

With 10–30 mirrors at 8h intervals, expect ~1–4 fetches/hour — well within any rate limit when authenticated.

The `[mirror]` settings are explicitly configured in `ansible/roles/forgejo/templates/app.ini.j2`. The `[cron.update_mirrors]` SCHEDULE is a Forgejo built-in default and is not in the template.

## Prerequisites

- Access to 1Password blumeops vault
- Forgejo admin account on forge.ops.eblu.me
- `op` CLI authenticated
- For new mirrors: `mise run mirror-create`

## Create a New Mirror

```fish
mise run mirror-create https://github.com/org/repo.git
```

Options:
- `--name <name>` — override the repo name on forge (default: derived from URL)
- `--description <text>` — set the repo description
- `--dry-run` — preview without creating

For GitHub upstreams, the script automatically includes the GitHub PAT from 1Password so the mirror authenticates from the start. Non-GitHub upstreams (Codeberg, etc.) are created without upstream auth.

## Update All Mirror PATs

To update the GitHub PAT on all existing mirrors at once:

```fish
mise run mirror-update-pats
```

This SSHs into indri and rewrites the git remote URL in each mirror's bare repository to embed `eblume:<PAT>@` in the upstream URL. It reads the PAT from 1Password and skips mirrors that already have the current PAT.

Use `--dry-run` to preview:

```fish
mise run mirror-update-pats --dry-run
```

### How It Works

Forgejo stores mirror credentials directly in the bare repo's git config on disk (not in the database). The `remote_address` in SQLite stays as the clean URL; the actual fetch URL in `<repo>.git/config` contains the embedded credentials:

```
# Unauthenticated
url = https://github.com/org/repo.git

# Authenticated
url = https://eblume:<pat>@github.com/org/repo.git
```

The Forgejo API has no endpoint for updating pull mirror credentials, so the script updates the git config directly via SSH.

## Rotate the GitHub PAT

The GitHub fine-grained PAT has a 30-day expiry. Set a recurring reminder (every 20 days) to rotate it before it expires.

### 1. Create a New PAT on GitHub

Go to [GitHub fine-grained token settings](https://github.com/settings/personal-access-tokens/new) and create a new token:

- **Name:** `forgejo-mirror-sync` (or similar, include the date for tracking)
- **Expiration:** 30 days
- **Repository access:** Public repositories (read-only)
- **Permissions:** None required — fine-grained PATs automatically include read-only access to all public repos

Copy the new PAT to your clipboard.

### 2. Update 1Password

With the new PAT on your clipboard:

```fish
op item edit w3663ffnvkewbftncqxtcpeavy github-mirror-pat=(pbpaste) --vault blumeops
```

Verify the update:

```fish
op read "op://blumeops/w3663ffnvkewbftncqxtcpeavy/github-mirror-pat" | head -c 12
# Should print the first 12 chars of the new PAT (github_pat_...)
```

### 3. Push the PAT to All Mirrors

```fish
mise run mirror-update-pats
```

### 4. Delete the Old PAT on GitHub

Return to [GitHub token settings](https://github.com/settings/tokens?type=beta) and delete the previous token.

### 5. Verify

Trigger a manual sync on one mirror to confirm the new PAT works:

1. Go to any mirror repo on forge (e.g., `mirrors/cloudnative-pg`)
2. Click the sync button (circular arrows icon) next to the mirror status
3. Confirm the sync completes without errors

## Related

- [[forgejo]] — Forgejo service reference
- [[upstream-fork-strategy]] — Stacked-branch forking for repos with local modifications
- [[gandi-operations]] — Similar PAT rotation workflow for Gandi DNS
