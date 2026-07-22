---
title: Agents Forgejo Bot
modified: 2026-07-21
last-reviewed: 2026-07-21
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
  `hephaestus`, `hephaestus.nvim`, `research`.
- **`blumeops`: read-only, author via fork.** The bot has **read** on the
  canonical `eblume/blumeops` and pushes to its own fork **`agents/blumeops`**,
  opening cross-repo PRs. Read (not write) is load-bearing: `workflow_dispatch`
  is write-gated, so a read-only bot **cannot trigger blumeops' CI** and thus
  cannot reach the deploy-credentialed Actions secrets (`ARGOCD_AUTH_TOKEN`,
  `FLY_DEPLOY_TOKEN`, `ZOT_CI_API_KEY`, `MAIN_PUSH_TOKEN`) — see
  [[agent-workspaces]] §Isolation. `main` is additionally branch-protected
  (push + merge whitelisted to `eblume`).
- **Not an admin.** No org/settings/runner access. No deploy credentials.

## Credentials

The bot has two, both in the **agents** vault, both bounded to its own
collaborations:

- `agents-forgejo-bot` — SSH keypair. The public half is on the `agents` user;
  the private half (concealed field) is deployed to `/etc/agents/ssh/id_ed25519`
  and used for `git push`.
- `agents-forgejo-token` — a Forgejo PAT, scopes `write:repository` +
  `write:issue` (tea's `pr create` needs the issue scope — PRs are issues in
  Forgejo), **minted as the `agents` user** so it can't exceed the bot's own
  repo access.
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
