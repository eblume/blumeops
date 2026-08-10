---
title: Manage Forgejo Mirrors
modified: 2026-08-10
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
| **Field** | `forge-ci-github-pat` |
| **op ref** | `op://blumeops/w3663ffnvkewbftncqxtcpeavy/forge-ci-github-pat` |

The name is `forge-ci-` rather than `mirror-` because mirroring is one consumer
of it, not the only one: it is indri's general-purpose credential for reading
public GitHub, and CI tool resolution is the next consumer lined up. What the
token *is* stays narrow — a fine-grained PAT with **no permissions**, which
grants read-only access to public repositories and nothing else. Keep it that
way. Anything needing a scope needs its own token, because this one is on a path
to being readable by CI jobs.

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

- **Name:** `forge-ci-github` (or similar, include the date for tracking)
- **Expiration:** 30 days
- **Repository access:** Public repositories (read-only)
- **Permissions:** None required — fine-grained PATs automatically include read-only access to all public repos

> **Grant no permissions, ever.** "None" is not merely the minimum that works
> here, it is the property that makes this token safe to spread. Consumers
> beyond mirroring read it, so a scope added for one caller is a scope every
> caller gets. A task needing more needs its own token.

**A classic token with zero scopes is an accepted alternative.** Create one at
[token settings](https://github.com/settings/tokens/new) with the same name and
expiry and **nothing checked**. The capability is the same — the token exists
only to make the clones authenticated, so GitHub applies the 5000/hr limit
instead of 60/hr, and no scopes means public read and nothing else.

Use it when the fine-grained form fails. On 2026-08-10 it silently redirected to
the token list on submit: no token, no approval request, no validation error,
with `eblume` as resource owner and the default expiry. Private window and
repeated attempts made no difference. The classic form has no resource-owner or
org-approval step, which is the part that fails.

Copy the new PAT to your clipboard.

### 2. Update 1Password

With the new PAT on your clipboard:

```fish
op item edit w3663ffnvkewbftncqxtcpeavy forge-ci-github-pat=(pbpaste) --vault blumeops
```

Verify the update:

```fish
op read "op://blumeops/w3663ffnvkewbftncqxtcpeavy/forge-ci-github-pat" | head -c 12
# Should print the first 12 chars of the new PAT (github_pat_...)
```

### 3. Push the PAT to All Mirrors

```fish
mise run mirror-update-pats
```

### 4. Delete the Old PAT on GitHub

Return to [GitHub token settings](https://github.com/settings/tokens?type=beta) and delete the previous token.

> [!note] "Never used" is expected
> The old token may show **"Last used: never"** in the GitHub UI even after weeks of active syncing. Fine-grained PAT last-used tracking is unreliable for **git-over-HTTPS** operations (it records API calls, but frequently never registers plain `git fetch`/`clone`), which is all the mirrors do. This is not a sign the PAT was unused — verify auth properly in step 5 instead.

### 5. Verify

The mirrors only use the PAT to lift GitHub's rate limit (public repos don't need auth for *access*), so confirm the token authenticates rather than relying on the "Last used" field.

Check the token is recognized as authenticated — `5000`/hr means authed, `60`/hr means anonymous/invalid:

```fish
curl -s -H "Authorization: Bearer $(op read 'op://blumeops/w3663ffnvkewbftncqxtcpeavy/forge-ci-github-pat')" \
  https://api.github.com/rate_limit | jq '.resources.core.limit'
```

Optionally, trigger a manual sync on one mirror to confirm end-to-end:

1. Go to any mirror repo's settings page on forge (e.g., `https://forge.eblu.me/mirrors/cloudnative-pg/settings`)
2. In the "Mirror settings" section, click "Synchronize now"
3. Confirm the sync completes without errors

## Related

- [[forgejo]] — Forgejo service reference
- [[rotate-gandi-pat]] — Similar PAT rotation workflow for Gandi DNS
- [[spork-strategy]] — floating-branch soft-fork strategy explanation
- [[create-a-spork]] — create a spork on top of a mirror
