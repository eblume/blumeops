---
title: Bootstrap Agent Workspaces
modified: 2026-08-07
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
Claude's first-run consent) and must be done by a human — once, except the
OAuth login, which recurs every 5 days (see step 5).

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
- Grant the `agents` user **write** on the workspace repos: `agents`,
  `hephaestus`, `hephaestus.nvim`, `research`, `timberborn-parsimony` (add as a
  collaborator, or via a team). Any repo `agent-repos-init` clones needs this —
  a missing grant fails the oneshot and blocks the workspace service.

> **`blumeops` is write too, but author-only.** The bot holds write on
> blumeops so it can push PR branches (granted 2026-07-10 with the author-only
> pool clone) — but there is deliberately no blumeops workspace server, and
> write ≠ deploy: the gates are the blumeops 1Password vault and the root-only
> kubeconfig, not repo permissions. See [[agent-workspaces]] §"blumeops:
> author-only, not a server". (`project-template` and `adelaide-baby-shower-app`
> grants from the prototype should stay revoked.) If the bot was granted `blumeops`/`project-template`/
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

## 5. Log in (OAuth) — interactively, then again every 5 days

Remote Control needs a **full-scope subscription OAuth login**: the credential
an interactive `claude auth login` writes to `~/.claude/.credentials.json` on
the PVC. It is the *only* credential Remote Control accepts — a
`claude setup-token` / `CLAUDE_CODE_OAUTH_TOKEN` token is inference-only and
claude refuses to start Remote Control with one (v0.16.0 shipped that and
crash-looped; see [[agent-workspaces#Authentication]]).

This is **not** a one-time step: the login's refresh token hard-expires ~7
days after login. Seed it now by performing one rotation —
[[rotate-agent-ws-claude-login]] has the commands — and the recurring 5-day
"Rotate agent-ws Claude OAuth login" heph chore (Blumeops project) keeps it
alive from then on.

Two pieces of first-run state live outside the credential and still need
seeding on a fresh PVC:

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
  `projects["<path>"].hasTrustDialogAccepted`). A login trusts only
  its own cwd — with the single home-base workspace that is the only cwd that
  needs it (`~agent/code/personal/agents`). If the workspace cwd ever moves,
  pre-seed the new path (set `hasTrustDialogAccepted=true`, then
  `chown agent:agent ~agent/.claude.json && chmod 600 ~agent/.claude.json`) or
  the service crash-loops on the untrusted dir.

## 6. Start the services

```fish
ssh ringtail 'sudo systemctl start agent-repos-init.service'
ssh ringtail 'sudo systemctl start "agent-ws-*"'
ssh ringtail 'systemctl status "agent-ws-*" --no-pager'
```

Open the **Code** tab in the Claude mobile app — `ringtail-agent` should appear
online. Tapping it and starting a session spawns an isolated worktree of the
`agents` home-base repo, with the sibling repos alongside at
`~/code/personal/`.

## 7. Seed the heph spoke (one-time)

The agent runs a `hephd` spoke (see [[agent-workspaces#The heph spoke (deliberately in-boundary)]]).
The mechanical parts — `cargo install` via mise, the services, owner adoption
(`--owner-id`) — are source-controlled and come up on `provision-ringtail`. These
are the irreducible secret/identity steps a human does once. **They are fiddlier
than they look; read the gotchas.**

1. **Give `heph-agents` a password + MFA — logged in AS `heph-agents`.** The
   blueprint creates the `heph-agents` user (heph-scoped group, not `admins`). Set
   its password (`ak shell` → `u.set_password(...)`, or the UI) and store it in the
   **blumeops** vault (item `heph-agents-login`) — the human reads blumeops, not
   the agents vault. Then, **in a private/incognito window** (see the gotcha),
   sign in to `https://authentik.ops.eblu.me` as `heph-agents` and complete the
   forced **TOTP enrollment** (MFA is enforced on the default flow — appropriate,
   this identity reaches your tasks). Save the TOTP secret into `heph-agents-login`.

2. **Seed the token — approve the device code in that same `heph-agents` session.**
   Confirm the build finished (`systemctl status agent-heph-install`), then:

   ```sh
   # heph-token-save is a nix store path; resolve it from the spoke unit:
   SAVE=$(ssh ringtail 'systemctl show agent-heph-spoke -p ExecStart --value' \
     | grep -oE '/nix/store/[a-z0-9]+-heph-token-save/bin/heph-token-save')
   ssh ringtail "sudo -u agent -H env HOME=/home/agent ~agent/.cargo/bin/heph auth login \
     --hub-url http://indri.tail8d86e.ts.net:8787 \
     --issuer https://authentik.ops.eblu.me/application/o/heph/ \
     --client-id heph --no-browser --token-save-cmd $SAVE"
   ```

   Approve the printed URL in the **incognito `heph-agents` session**. On success
   `heph-token-save` writes the token to `op://agents/heph-spoke-token/token`.

   > **THE trap:** the device flow authorizes as whoever the browser is logged
   > into. If you open the URL in your normal browser (logged in as *you*), it
   > silently binds **you** as the hub owner and puts *your* token in the agents
   > vault — not what you want. Always approve from a session logged in as
   > `heph-agents`. Device codes also **expire in a few minutes**, so do the TOTP
   > enrollment (step 1) *first*, then the approval is a single click. If they keep
   > expiring, pull the current code straight from Authentik:
   > `DeviceToken.objects.filter(provider__name="Heph").order_by("-pk").first().user_code`.

3. **Record the authorized sub for the hub.** Decode the token's `sub` (a
   `hashed_user_id`) and store it in the **blumeops** vault (`heph-agents-sub`/`sub`):

   ```fish
   # as the agent; base64URL needs padding — python is more reliable than `base64 -d`
   op read op://agents/heph-spoke-token/token \
     | python3 -c 'import sys,json,base64; t=json.load(sys.stdin)["access_token"].split(".")[1]; t+="="*(-len(t)%4); print(json.loads(base64.urlsafe_b64decode(t))["sub"])'
   op item create --vault blumeops --category "API Credential" \
     --title heph-agents-sub "sub[text]=<the-sub>"
   ```

4. **Authorize on the hub, then (re)start the spoke on a clean store.**

   ```fish
   mise run provision-indri -- --tags heph        # hub picks up --authorized-sub
   # the spoke's fresh store minted its own owner_id before adoption; reset it so
   # it re-pulls under the adopted --owner-id:
   ssh ringtail 'sudo systemctl stop agent-heph-spoke; \
     sudo rm -f /home/agent/.local/share/heph/heph.db*; \
     sudo systemctl start agent-heph-spoke'
   ssh ringtail 'sudo -u agent -H env HOME=/home/agent ~agent/.cargo/bin/heph list --project Blumeops'
   ```

   Expect your real Blumeops tasks. `heph sync --status` should show
   `auth_failure=false, last_error=null`.

> **Revoke** by disabling the `heph-agents` Authentik user, or by removing the
> `heph-agents-sub` vault item and re-provisioning indri (drops it from
> `--authorized-sub`) — either cuts the spoke without touching your own logins.

**Other gotchas banked while bootstrapping this:**

- If `git push` (or any forge SSH) *hangs*, it's an unapproved **1Password SSH-agent
  biometric prompt**, not the network.
- `nix build`/`nixos-rebuild --flake git+https://…?ref=main` **caches** the ref;
  use `--refresh` (or `?rev=<full-sha>`) to pick up a just-pushed commit.
- Owner model: `heph-agents` is only the **login credential** (revocable). The hub
  still has one owner — *you* — and the spoke **adopts** your `owner_id`
  (`--owner-id`) so the agent works your actual nodes. It is *not* a second owner.

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
