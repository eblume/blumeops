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

On indri (Forgejo admin CLI), create a non-admin user named `agents`:

```fish
ssh indri
# inside the forgejo environment (see forgejo.md for how admin CLI is invoked)
forgejo admin user create --username agents --email agents@eblu.me \
    --random-password --must-change-password=false
```

Then, in the Forgejo web UI as an admin:

- Add the **public key** from the `agents-forgejo-bot` vault item (see
  [[agents-forgejo-bot]]) to the `agents` user's SSH keys.
- Grant the `agents` user **write** on: `hephaestus`, `hephaestus.nvim`,
  `blumeops`, `project-template`, `adelaide-baby-shower-app`, `research`
  (add as a collaborator, or via a team).
- Confirm `main` is protected on each (Settings → Branches) so the bot cannot
  push to it.

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

## 5. Log in (OAuth) and accept first-run prompts

Remote Control needs a subscription OAuth login. On a headless box the login
prints a URL — open it on gilbert, approve, paste the code back.

```fish
sudo -u agent -H bash -lc 'cd ~/workspaces/blumeops/blumeops && ~/.local/bin/claude'
```

In that interactive session:

1. Complete `/login` (browser on gilbert, paste code back).
2. Accept the **workspace trust** dialog.
3. `/exit`.

Then seed the Remote Control **consent** prompt once (it persists to
`~/.claude.json`), for one workspace — the consent is per-user, not per-dir:

```fish
sudo -u agent -H bash -lc 'cd ~/workspaces/blumeops/blumeops && ~/.local/bin/claude remote-control --spawn worktree --name ringtail-bootstrap'
# answer "y" to "Enable Remote Control?", confirm it connects, then Ctrl-C
```

> **Trust per directory:** each workspace's primary repo dir needs the trust
> dialog accepted once. Either repeat the `claude` run per workspace cwd, or
> pre-seed trust in `~/.claude.json`. The `agent-ws-*` services run
> non-interactively and cannot answer a trust prompt, so an unseeded workspace
> will crash-loop until trusted.

## 6. Start the services

```fish
ssh ringtail 'sudo systemctl start agent-repos-init.service'
ssh ringtail 'sudo systemctl start "agent-ws-*"'
ssh ringtail 'systemctl status "agent-ws-*" --no-pager'
```

Open the **Code** tab in the Claude mobile app — `ringtail-hephaestus`,
`ringtail-blumeops`, `ringtail-research`, and `ringtail-playground` should each
appear online. Tapping one and starting a session spawns an isolated worktree
of that repo.

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
