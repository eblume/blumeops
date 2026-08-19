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
  `hephaestus`, `hephaestus.nvim`, `research`, `myeve`, `timberborn-parsimony`,
  `gamedev`, `talos`. Access is per-repo **collaborator** grants, not an org-wide role —
  the bot sees nothing it was not explicitly added to.
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

## Sharing a repo with the bot

Most of Erich's repos are **private**, and the bot is a plain Forgejo user — it
gets no access by owning nothing. Both halves — the forge grant and the
workspace checkout — are declared in **one** file:

**`repos.json`** (repo root)

```json
{ "name": "myeve", "access": "write", "pool": "canonical" }
```

- `access` (`write` | `read` | `none`) is reconciled onto the forge as a
  collaborator grant by `mise run agent-repo-access`, which the
  **Agent Repo Access** workflow runs on merge to `main`.
- `pool` (`canonical` | `fork` | `none`) is compiled into the pod's clone loop
  by `containers/talos/default.nix` via `builtins.fromJSON`.

So adding a repo is: edit the file, open a PR, merge. No clicking in the forge
UI — and nothing to forget, which is the point. See [[agent-containerization]]
§"The repo pool" for what the `pool` values mean.

> **Reconcile is authoritative.** A repo *absent* from `repos.json` has its
> `agents` collaboration **removed**. The PR job runs `--check`, so any
> revocation shows up in review before the merge that applies it. Grants made
> by hand in the forge UI will be reverted on the next run.

> **Two repos are pinned read-only in code, not data.** `blumeops` and `agents`
> cannot be granted `write` no matter what `repos.json` says — the reconciler
> refuses and exits non-zero (`PINNED_READ_ONLY` in `mise-tasks/agent-repo-access`).
> Their read-only-on-canonical status is what keeps blumeops CI, and its
> deploy-credentialed Actions secrets, out of agent reach; that fence should not
> be flippable by a one-line edit to a data file in a routine-looking PR.

### Why a missing grant is hard to diagnose

Forgejo returns **404, not 403**, for a private repo the caller cannot see. So a
missing collaboration is indistinguishable from a misspelled repo name: the
pod's clone loop (deliberately non-fatal, so one bad repo can't crashloop the
workspace) logs `talos: clone <repo> failed (continuing)` and the repo is
simply absent from `~/code/personal`. `timberborn-parsimony` sat documented as a
sibling checkout for three weeks while being absent for exactly this reason —
which is what motivated collapsing the two steps into one file.

If an agent reports a repo missing, check the grant before debugging the clone.
To see what the bot can currently reach, from an agent session:

```sh
curl -s --socks5-hostname localhost:1055 -H "Authorization: token $FORGEJO_TOKEN" \
  "https://forge.ops.eblu.me/api/v1/repos/search?limit=100" \
  | jq -r '.data[] | "\(.full_name)\t\(.permissions)"'
```

**Revoking** is `"access": "none"`, or deleting the entry outright. It takes
effect for new clones immediately — but the pod's PVC keeps any checkout it
already made, so also delete `~/code/personal/<repo>` in the pod if the intent
is to actually take it away.

The reconciler needs **admin** on the target repos — collaborator management is
admin-level, and a `write:repository` token gets 403. In CI that arrives as the
`FORGE_ADMIN_TOKEN` Actions secret, declared in the `forgejo_actions_secrets`
ansible role and pushed by a human:

```fish
mise run provision-indri -- --tags forgejo_actions_secrets
```

It reuses `forgejo_api_token` — the same `eblume` PAT that role already
authenticates with, since writing Actions secrets is itself admin-level — rather
than minting a second credential. Locally the task falls back to `op read` on
that same 1Password item.

The reconciler deliberately avoids `/api/v1/user*` (those need the `read:user`
scope, which a repo-scoped PAT may not carry) and enumerates via
`/api/v1/repos/search` instead. It also reads **only** `$FORGE_ADMIN_TOKEN`,
never `$FORGEJO_TOKEN`: the indri runner is host-mode, so jobs inherit
`erichblume`'s LaunchAgent environment, and an earlier version silently picked
up a token the workflow never passed it.

> **Why a Forgejo secret and not `op` in CI.** The vault split is the boundary:
> the `agents` vault is the agent's, the **blumeops** vault is privileged and a
> human is meant to be part of any decision to use it. Forgejo Actions secrets
> are the curated subset that crosses that line, and `provision-indri` — run
> from gilbert under biometric `op` — is the human step that moves them. Giving
> a runner a blumeops-vault service account would erase exactly that gate, since
> 1Password service accounts scope per *vault*, not per item.

## Rotating the key

1. Generate a new `ed25519` keypair; update the `agents-forgejo-bot` item's
   `private key` / `public key` fields in the `agents` vault.
2. Replace the public key on the `agents` Forgejo user.
3. `mise run provision-ringtail` to redeploy `/etc/agents/ssh/id_ed25519`.

## Related

- [[agent-workspaces]] — what uses this identity
- [[bootstrap-agent-workspaces]] — first-time creation steps
- [[forgejo]] — the forge
