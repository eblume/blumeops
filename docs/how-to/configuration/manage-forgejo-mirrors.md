---
title: Manage Forgejo Mirrors
modified: 2026-09-03
last-reviewed: 2026-09-03
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

GitHub rate-limits unauthenticated git fetch/clone over HTTPS. As of May 2025, these limits were tightened significantly. All mirrors should use an authenticated `clone_addr` (via a zero-scope GitHub PAT) to avoid throttling.

The GitHub PAT is stored in 1Password:

| Property | Value |
|----------|-------|
| **Vault** | blumeops (`vg6xf6vvfmoh5hqjjhlhbeoaie`) |
| **Item** | Forgejo Secrets (`w3663ffnvkewbftncqxtcpeavy`) |
| **Field** | `forge-ci-github-pat` |
| **op ref** | `op://blumeops/w3663ffnvkewbftncqxtcpeavy/forge-ci-github-pat` |

The name is `forge-ci-` rather than `mirror-` because mirroring is one consumer
of it, not the only one: it is indri's general-purpose credential for reading
public GitHub. CI tool resolution is the other consumer — the runner injects it
into every job as `MISE_GITHUB_TOKEN` (see [[forgejo-runner]]), so it is
readable by CI jobs. What the token *is* stays narrow — a PAT with **no
permissions** (a zero-scope classic token), which grants read-only
access to public repositories and nothing else. Keep it that way. Anything
needing a scope needs its own token.

Rotation reaches the two consumers differently: `mise run mirror-update-pats`
re-bakes the mirrors immediately, but the runner env only picks up the new
value at the next `provision-indri`.

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

The GitHub PAT is a zero-scope classic token with a 30-day expiry. A recurring Forgejo issue fires on the 1st and 21st of each month to drive the rotation.

### 1. Create a New PAT on GitHub

Use the **classic** form — create a token at [token settings](https://github.com/settings/tokens/new):

- **Name:** `forge-ci-github` (or similar, include the date for tracking)
- **Expiration:** 30 days
- **Permissions:** **nothing checked** (zero scopes)

> **Grant no permissions, ever.** "None" is not merely the minimum that works
> here, it is the property that makes this token safe to spread. Consumers
> beyond mirroring read it, so a scope added for one caller is a scope every
> caller gets. A task needing more needs its own token.

**Why classic rather than fine-grained:** the fine-grained form has a
resource-owner/org-approval step, and it fails. On 2026-08-10 it silently
redirected to the token list on submit — no token, no approval request, no
validation error — with `eblume` as resource owner and the default expiry.
Private window and repeated attempts made no difference. The classic form has
no resource-owner or org-approval step.

Either form does the job — the token exists only to make the clones
authenticated, so GitHub applies the 5000/hr limit instead of 60/hr, and
zero scopes means public read and nothing else. The fine-grained form, if
used, is [fine-grained token settings](https://github.com/settings/personal-access-tokens/new)
with "Public repositories" access and no permissions.

Copy the new PAT to your clipboard.

### 2. Update 1Password

With the new PAT on your clipboard:

```fish
op item edit w3663ffnvkewbftncqxtcpeavy forge-ci-github-pat=(pbpaste) --vault blumeops
```

Verify the update:

```fish
op read "op://blumeops/w3663ffnvkewbftncqxtcpeavy/forge-ci-github-pat" | head -c 12
# Should print the first 12 chars of the new PAT (ghp_...)
```

### 3. Push the PAT to All Mirrors

```fish
mise run mirror-update-pats
```

### 4. Delete the Old PAT on GitHub

Return to [GitHub token settings](https://github.com/settings/tokens) and delete the previous token.

> [!note] "Never used" is expected
> The old token may show **"Last used: never"** in the GitHub UI even after weeks of active syncing. GitHub PAT last-used tracking is unreliable for **git-over-HTTPS** operations (it records API calls, but frequently never registers plain `git fetch`/`clone`), which is all the mirrors do. This is not a sign the PAT was unused — verify auth properly in step 5 instead.

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
