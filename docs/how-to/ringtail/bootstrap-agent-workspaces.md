---
title: Bootstrap Agent Workspaces
modified: 2026-07-08
last-reviewed: 2026-07-08
tags:
  - how-to
  - ringtail
  - ai
---

# Bootstrap Agent Workspaces

One-time steps to bring up [[agent-workspaces]] on [[ringtail]]. Ordinary
redeploys are just `mise run provision-ringtail`; these steps cover the state
that lives *outside* git (the Forgejo bot user, the agent's OAuth login, and
Claude's first-run consent) and must be done once by a human.

Do these **in order**. Steps 1–2 can happen before the config is deployed;
steps 4–6 require the `agent` user to exist (i.e. after the first
`nixos-rebuild`).

## 1. Create the Forgejo bot user

> **Status:** already done (2026-07-08) — the `agents` user exists and has the
> bot public key. This section documents how, for reproduction/rotation.

On indri (Forgejo admin CLI), create a non-admin user named `agents`. Forgejo
runs as `erichblume` with its work path at `/Users/erichblume/forgejo`:

```fish
ssh indri
FJ=/Users/erichblume/code/3rd/forgejo/forgejo
WP=/Users/erichblume/forgejo; CFG=$WP/custom/conf/app.ini
"$FJ" admin user create --username agents --email blume.erich+agents@gmail.com \
    --random-password --must-change-password=false --work-path "$WP" --config "$CFG"
```

(Email is a `+agents` gmail alias because `eblu.me` has no working MX yet.)

Then, in the Forgejo web UI as an admin:

- Add the **public key** from the `agents-forgejo-bot` vault item (see
  [[agents-forgejo-bot]]) to the `agents` user's SSH keys.
- Grant the `agents` user **write** on the workspace repos: `hephaestus`,
  `hephaestus.nvim`, `research` (add as a collaborator, or via a team).

> **Not `blumeops`.** blumeops is intentionally not an agent workspace (see
> [[agent-workspaces]] §"Why blumeops is not a workspace"), so the bot needs no
> write there. If the bot was granted `blumeops`/`project-template`/
> `adelaide-baby-shower-app` write during the prototype, **revoke it** — the bot
> should hold only what a live workspace uses.

> **`main` is intentionally not branch-protected against the bot.** A username
> push-whitelist rejects CI's automatic Forgejo Actions token (Forgejo
> [#11159](https://codeberg.org/forgejo/forgejo/issues/11159)), which breaks
> the release workflows. The bot *can* push to `main`; the boundary is
> convention (open PRs) plus the fact that the bot holds no deploy credentials.
> See [[agent-workspaces]] §Isolation.

## 2. Confirm vault items exist

The `agents` vault must contain (created during the prototype, 2026-07-08):

- `agents-forgejo-bot` — SSH keypair (`private key`, `public key` fields).
- The `agents-ringtail Service Account` item lives in the **blumeops** vault
  and holds the `agents-ringtail-rw` token (read/write on `agents` only).

## 3. Deploy the config

```fish
mise run provision-ringtail
```

This writes `/etc/agents/op-token` and `/etc/agents/ssh/id_ed25519`, creates the
`agent` user, and installs the `agent-repos-init` + `agent-ws-*` services. The
workspace services **will fail to start yet** — Claude isn't installed for the
`agent` user and there's no OAuth login. That's expected; continue.

## 4. Install Claude Code for the agent user

Remote Control moves fast, so we use the official self-updating installer rather
than nixpkgs (see [[agent-workspaces]] "Known warts"):

```fish
ssh ringtail
sudo -u agent -H bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
# verify:
sudo -u agent -H bash -lc '~/.local/bin/claude --version'
```

## 5. Log in (OAuth) — once, interactively

Remote Control needs a subscription OAuth login. Do it **once** in any
workspace; it writes `~/.claude/.credentials.json` (account-wide). Use a real
TTY (`ssh -t` + `sudo -i`) and the **full path** — the fresh `agent` login
shell doesn't have `~/.local/bin` on PATH yet:

```fish
ssh -t ringtail
sudo -u agent -H -i
cd ~/workspaces/hephaestus/hephaestus
~/.local/bin/claude
```

In that session: run `/login` (open the printed URL on gilbert, approve, paste
the code back), accept the **workspace trust** dialog, then `/exit`.

- **Remote Control consent is per-config-dir and MUST be seeded**, or every
  service blocks invisibly. On first `remote-control` launch Claude prompts
  `Enable Remote Control? (y/n)`. A non-interactive service can't answer it, so
  it **hangs at the prompt** — and because the launcher wraps Claude in
  `script`, the hung process still reports `active (running)` to systemd with 0
  restarts. It looks healthy but never connects (this bit us: the only visible
  environment was a stale ghost from an earlier run). The consent is stored in
  `<config-dir>/.claude.json` as `"remoteDialogSeen": true`. Seed it either by:
  - running `~/.local/bin/claude remote-control` once interactively and
    answering `y`+Enter (confirm it prints `Connected`), or
  - **pre-seeding non-interactively**: set `"remoteDialogSeen": true` at the top
    level of `.claude.json` (same edit pass as the trust flags below), which is
    the reproducible path.
  It persists on disk (survives reboots/re-provision), but a fresh `agent` home
  needs it re-seeded.
- **Trust is per-directory** (`~/.claude.json` →
  `projects["<path>"].hasTrustDialogAccepted`). The `/login` above trusts only
  its own cwd; the `agent-ws-*` services run non-interactively and crash-loop
  on an untrusted dir. Pre-seed the other workspace cwds instead of logging in
  to each:

  ```fish
  # as root; set hasTrustDialogAccepted=true for each remaining workspace cwd,
  # then: chown agent:agent ~agent/.claude.json && chmod 600 ~agent/.claude.json
  ```

  (paths: `~agent/workspaces/{hephaestus/hephaestus,research/research,playground}`)

## 6. Start the services

```fish
ssh ringtail 'sudo systemctl start agent-repos-init.service'
ssh ringtail 'sudo systemctl start "agent-ws-*"'
ssh ringtail 'systemctl status "agent-ws-*" --no-pager'
```

Open the **Code** tab in the Claude mobile app — `ringtail-hephaestus`,
`ringtail-research`, and `ringtail-playground` should each appear online.
Tapping one and starting a session spawns an isolated worktree of that repo.

## Verifying the secrets path

From a spawned session (or `sudo -u agent`), plain `op` should work read/write
against the `agents` vault only:

```
op vault list                                  # exactly: agents
op item get agent-test-secret --vault agents    # reads
```

## Teardown / rollback

Revert the PR and `mise run provision-ringtail`; then
`ssh ringtail 'sudo userdel -r agent'` if you want the home gone. Remove the
`agents` Forgejo user and revoke the service account in 1Password if retiring
the capability entirely.

## Related

- [[agent-workspaces]] — design & operations
- [[agents-forgejo-bot]] — the bot identity
