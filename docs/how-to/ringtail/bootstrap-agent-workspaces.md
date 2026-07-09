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

## 1b. Create the agents Forgejo PAT (for PR creation)

> **Status:** done (2026-07-08) — item `agents-forgejo-token` in the agents vault.

Agents open PRs with `tea`, which needs a token. Mint it **as the `agents`
user** (not admin): a Forgejo PAT can't exceed its owner's permissions, so an
agents-owned token is structurally bounded to the repos agents collaborates on
— the ownership bound is the guardrail, not the scope list.

```fish
ssh indri
FJ=/Users/erichblume/code/3rd/forgejo/forgejo
WP=/Users/erichblume/forgejo; CFG=$WP/custom/conf/app.ini
"$FJ" admin user generate-access-token --username agents \
    --scopes write:repository,write:issue --token-name agent-pr \
    --work-path "$WP" --config "$CFG"
```

Store it concealed in the **agents** vault as `agents-forgejo-token` →
`api-token` (`op item create --vault agents --category "API Credential" --title
agents-forgejo-token "api-token[password]=<tok>"`). The workspace launcher reads
it via the op shim and both exports `FORGEJO_TOKEN` and seeds `tea`'s config, so
PR creation has **no blumeops-vault dependency**. Scopes are `write:repository`
+ `write:issue` (tea's `pr create` needs the issue scope — PRs are issues in
Forgejo) — never `write:admin`/`write:organization`/`sudo`.

## 2. Confirm vault items exist

The `agents` vault must contain (created during the prototype, 2026-07-08):

- `agents-forgejo-bot` — SSH keypair (`private key`, `public key` fields).
- `agents-forgejo-token` — Forgejo PAT (`api-token` field, `write:repository`).
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

## 7. Seed the heph spoke (one-time)

The agent runs a `hephd` spoke (see [[agent-workspaces#The heph spoke (deliberately in-boundary)]]).
The mechanical parts — `cargo install` via mise, the services — are
source-controlled and come up on `provision-ringtail`. These are the irreducible
secret/identity steps a human does once:

1. **Set the `heph-agents` Authentik password.** The blueprint creates the
   `heph-agents` user (heph-scoped group, not `admins`). In the Authentik UI set
   a password for it (Directory → Users → heph-agents → Set password) and stash
   it in the agents vault. This is the credential for the device-code login below.

2. **Wait for the install, then seed the token.** Confirm the build finished
   (`ssh ringtail 'systemctl status agent-heph-install --no-pager'`), then run the
   device-code login pointed at the vault-backed save command:

   ```fish
   ssh -t ringtail
   sudo -u agent -H -i
   heph auth login \
     --hub-url   http://indri.tail8d86e.ts.net:8787 \
     --issuer    https://authentik.ops.eblu.me/application/o/heph/ \
     --client-id heph \
     --token-save-cmd heph-token-save
   ```

   Open the printed URL, log in **as `heph-agents`**, approve. `heph-token-save`
   writes the token to `op://agents/heph-spoke-token/token` (creating the item).

3. **Record the authorized sub for the hub.** The hub only serves an identity it
   recognizes as owner. The `sub` is a `hashed_user_id` — decode it from the
   seeded token and store it in the **blumeops** vault as item `heph-agents-sub`,
   field `sub`:

   ```fish
   # as the agent user; decode the access token's sub claim
   op read op://agents/heph-spoke-token/token | jq -r .access_token \
     | cut -d. -f2 | base64 -d 2>/dev/null | jq -r .sub
   # then, with your own (blumeops-vault) op session, store it:
   op item create --vault blumeops --category "API Credential" \
     --title heph-agents-sub "sub[text]=<the-sub>"
   ```

4. **Deploy so the hub authorizes it, and start the spoke.**

   ```fish
   mise run provision-indri -- --tags heph     # hub picks up --authorized-sub
   ssh ringtail 'sudo systemctl restart agent-heph-spoke'
   ssh ringtail 'sudo -u agent -H heph sync --status'   # expect a healthy sync
   ```

> **Revoke** by disabling the `heph-agents` Authentik user, or by removing the
> `heph-agents-sub` vault item and re-provisioning indri (drops it from
> `--authorized-sub`) — either cuts the spoke without touching your own logins.

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
