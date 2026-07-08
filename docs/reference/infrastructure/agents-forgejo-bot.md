---
title: Agents Forgejo Bot
modified: 2026-07-08
last-reviewed: 2026-07-08
tags:
  - reference
  - infrastructure
  - ai
---

# Agents Forgejo Bot

The Forgejo identity that [[agent-workspaces]] use to push work. Agents commit
and push **branches**; branch protection on `main` and human PR review are the
gate before anything deploys.

## Identity

- **Forgejo user:** `agents`
- **SSH key:** stored in the `agents` 1Password vault as item
  `agents-forgejo-bot` (fields `private key`, `public key`). The private key is
  deployed to ringtail at `/etc/agents/ssh/id_ed25519` (mode 0400, owner
  `agent`) by `ansible/playbooks/ringtail.yml`.
- **Public key:**
  ```
  ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMxDHumC8G7oWH7ivpQLKvBs8MRjf3nBlQmPBXMdduTF agents-forgejo-bot@ringtail
  ```

## Access policy

- **Write** (push branches, open PRs) to the repos agents work in:
  `hephaestus`, `hephaestus.nvim`, `research`. **Not `blumeops`** — it is
  deliberately not an agent workspace ([[agent-workspaces]] §"Why blumeops is
  not a workspace"); blumeops work is local-on-gilbert with biometric `op`.
- **`main` is not protected against the bot.** Convention is to open PRs, but
  the bot technically *can* push to `main` — branch protection was dropped
  because a username push-whitelist rejects CI's Forgejo Actions token
  ([[agent-workspaces]] §Isolation, Forgejo
  [#11159](https://codeberg.org/forgejo/forgejo/issues/11159)). The safeguard
  is that the bot has no deploy credentials, so a `main` commit deploys
  nothing until a human provisions.
- **Not an admin.** No org/settings/runner access. No deploy credentials.

## Credentials

The bot has two, both in the **agents** vault, both bounded to its own
collaborations:

- `agents-forgejo-bot` — SSH keypair. The public half is on the `agents` user;
  the private half (concealed field) is deployed to `/etc/agents/ssh/id_ed25519`
  and used for `git push`.
- `agents-forgejo-token` — a Forgejo PAT, scope `write:repository` only,
  **minted as the `agents` user** so it can't exceed the bot's own repo access.
  Read by the workspace launcher via the op shim for `tea pr create` /
  `FORGEJO_TOKEN`. A PAT minted this way is self-bounding — the ownership is the
  guardrail, not the scope list.

## Rotating the key

1. Generate a new `ed25519` keypair; update the `agents-forgejo-bot` item's
   `private key` / `public key` fields in the `agents` vault.
2. Replace the public key on the `agents` Forgejo user.
3. `mise run provision-ringtail` to redeploy `/etc/agents/ssh/id_ed25519`.

## Related

- [[agent-workspaces]] — what uses this identity
- [[bootstrap-agent-workspaces]] — first-time creation steps
- [[forgejo]] — the forge
