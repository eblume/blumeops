---
title: Agent Workspaces
modified: 2026-07-09
last-reviewed: 2026-07-08
tags:
  - reference
  - infrastructure
  - ai
---

# Agent Workspaces

Persistent [Claude Code](https://code.claude.com) **Remote Control** servers on
[[ringtail]], one per repository, that Erich steers on demand from the Claude
mobile app or claude.ai/code. Each server spawns isolated per-session git
worktrees, so several agents can work concurrently without colliding.

This is the infrastructure landing of a prototype researched in the `research`
repo (`2026/July/Remote-Agent-Sessions-On-Ringtail/`). BlumeOps is the platform;
the agent workflows are built *upon* it.

## Design

```
Claude mobile app / claude.ai/code
        │   Anthropic relay (outbound-only from ringtail; no inbound ports)
        ▼
ringtail — user `agent` (isolated, non-wheel)
  systemd: agent-ws-<name>.service  (one per workspace)
    └─ claude remote-control --spawn worktree --name ringtail-<name>
         cwd = ~/code/personal/<primary-repo>
         PATH prepends the transparent `op` shim + ~/.cargo/bin (heph)
                   + the report toolchain (mise/uv/pandoc/typst/weasyprint)
  systemd: agent-repos-init.service  (oneshot, clones/updates repos first)
```

Checkouts live at **`~/code/personal/<repo>`** (not under a per-workspace dir) so
the paths agents read in the repo docs — every `AGENTS.md`/`CLAUDE.md` assumes
`~/code/personal/…` — actually resolve on the agent box. The workspace *name*
only names the Remote Control session (`ringtail-<name>`); it is independent of
where the checkout lives.

### Workspaces

| Workspace | Primary repo (cwd) | Also cloned alongside |
|-----------|--------------------|-----------------------|
| `hephaestus` | `hephaestus` | `hephaestus.nvim` |
| `research` | `research` | — |
| `playground` | *(empty git repo)* | — |

Sibling repos are plain checkouts alongside the primary in `~/code/personal/`;
the agent can `cd` to them to read/reference. Only the **primary** repo gets
per-session worktree isolation (that is what `--spawn worktree` operates on).

> **blumeops is deliberately not a workspace** — see [§Why blumeops is not a
> workspace](#why-blumeops-is-not-a-workspace). blumeops changes are made
> locally on gilbert with biometric `op`, not by a remote agent.

### Why per-repo servers

A Remote Control server is rooted in its start directory; new sessions spawn as
worktrees of that repo and inherit its `CLAUDE.md`/tooling. So "an agent working
on hephaestus" is just: open the `ringtail-hephaestus` environment in the app →
new session → it wakes up in a hephaestus worktree, repo instructions already
loaded. No clone-and-orient preamble. Idle servers cost nothing (no inference
until a session is active).

### Why blumeops is not a workspace

blumeops was prototyped as the hub workspace, then **deliberately dropped**
(2026-07-08). The reasoning, because it constrains any future attempt to add it
back:

- **Real blumeops work needs the whole blumeops vault.** Ansible `pre_tasks`
  resolve secrets via `op` before anything runs (so even `--check --diff` dies
  at the lookup, not just apply), and many `mise` tasks — PR creation via `tea`,
  container releases, `runner-logs` — `op read` the blumeops vault too. A remote
  agent authenticates only as the `agents`-vault service account, so it gets
  `403` on all of it.
- **There is no least-privilege subset to grant.** The blumeops vault exists
  *precisely* to be the operational-secret blast-radius boundary — isolating
  infra secrets from personal ones (bank, etc.). 1Password service-account
  access is **per-vault, all-or-nothing** (no item-level whitelist), so the only
  "subset" that covers blumeops work is the entire vault. Granting it would put
  the argocd break-glass password and every ansible secret in agent reach —
  collapsing both the vault boundary **and** the deploy backstop that makes an
  unprotected `main` tolerable (§Isolation).
- **Biometric `op` and a headless worker are mutually exclusive.** Biometric
  approval needs an interactive desktop 1Password session; a background
  service-account process can't route that prompt anywhere. So "gate blumeops
  secrets behind biometric approval" and "run blumeops on a remote worker"
  cannot both be true.

Net: a remote blumeops worker could only *author* (edit code/docs, syntax-check)
— it could never verify or deploy — and even a PR would need a vault-backed
token. That sliver of value isn't worth standing up a worker that trips over
`op` at every real step. **blumeops changes are made locally on gilbert with
biometric `op`.** (The `project-template` and `adelaide-baby-shower-app` repos,
previously cloned alongside blumeops, went with it; add them as their own
workspaces if remote work on them is ever wanted — they carry no vault
dependency.)

## Isolation & security

The boundaries, weakest-first:

1. **Vault boundary** — agents authenticate to 1Password only as the
   `agents-ringtail-rw` [[security-model|service account]] (read/write, the
   `agents` vault *only*). Everything outside that vault is unreachable. This is
   the hard secrets wall.
2. **User boundary** — the `agent` user is not in `wheel`, has its own home, and
   never sees Erich's `~/.claude` credentials, repo checkouts, or shell history.
3. **Credential handling** — the service-account token lives at
   `/etc/agents/op-token` (owned by `agent`, mode 0400) and is injected by a
   transparent `op` shim (see below) so it never appears in a session's
   environment (agents dump `env` while debugging, and transcripts get
   archived).
4. **Git-mediated writes** — agents push as a dedicated Forgejo bot
   ([[agents-forgejo-bot]]) and, by convention, open PRs rather than committing
   to `main`. Note this is **convention, not enforcement**: `main` is *not*
   branch-protected against the bot (a username push-whitelist rejects the
   automatic Forgejo Actions token — Forgejo
   [#11159](https://codeberg.org/forgejo/forgejo/issues/11159) — which would
   break the release workflows, so protection was intentionally dropped). The
   real gate is that **deploy credentials (argocd, ansible, the provision
   tasks) are never in agent reach** — a bot commit to `main` still deploys
   nothing until a human runs a provision/sync. PRs are opened with `tea`,
   authenticated by an agents-owned `write:repository`+`write:issue` PAT
   (`agents-forgejo-token` in the agents vault) that the launcher exports as
   `FORGEJO_TOKEN` and seeds into tea's config — no blumeops-vault dependency,
   and the PAT is self-bounded to the bot's own repos ([[agents-forgejo-bot]]).
5. **Network** *(future)* — bare-metal phase has ambient tailnet reach; the
   planned containerized phase adds an egress allowlist (Anthropic, 1Password,
   `forge.ops.eblu.me`).

**Residual risk (bare-metal phase):** a same-uid agent can read
`/etc/agents/op-token` and the `agent` user's own OAuth credential file — the
shim prevents *accidental* leakage, not a determined read. The vault scoping
(1) bounds the blast radius; the container phase closes the uid gap. The main
live threat is prompt injection driving malicious commits or vault-secret
exfiltration; because the bot *can* push to `main` (see 4), the backstop is
that no credential the agent can reach triggers a deploy on its own — a human
provision/sync step always sits between a commit and production.

### The transparent `op` shim

Existing scripts call plain `op` and must work inside *and* outside agent
environments. The shim (`pkgs.writeShellScriptBin "op"`) is prepended to the
workspace `PATH`: if `OP_SERVICE_ACCOUNT_TOKEN` is unset it reads
`/etc/agents/op-token`, then execs the real `op`. Outside agent services the
shim is not on `PATH`, so normal `op` (desktop/biometric) is unchanged.

> **op gotchas** (learned the hard way): Claude Code's Bash tool does **not**
> persist environment between calls, so `export OP_SERVICE_ACCOUNT_TOKEN=…` in
> one call is gone by the next — the shim exists precisely so nothing needs to
> export it. Also, `op` parses non-TTY stdin as a JSON item template, so inside
> scripts call it with `</dev/null` or writes fail with a misleading
> "invalid JSON" error that looks like a permission denial.

### Writing secrets into the vault

When an agent (or a human) stores a **sensitive** value in the `agents` vault,
put it in a **concealed** field, not a plain-text one, so the 1Password GUI
masks it when the item is examined: `op item edit <item> --vault agents
"api-key[password]=…"` (the `[password]` field type is concealed;
`[text]`/`STRING` is shown in the clear). Only truly public values (e.g. an SSH
*public* key) belong in a `[text]` field. This is defence-in-depth behind an
already-unlocked vault — minor, but free.

## The heph spoke (deliberately in-boundary)

[[hephaestus|heph]] is the **counterpoint** to the vault isolation above: it is
*intentionally inside* the agent trust boundary, because it is the substrate
agentic workflows run on (task discovery, logging, canonical-context docs). So
the `agent` user runs a real `hephd` **spoke** synced to the indri hub and can
read/write the owner's real tasks — this is the point, not a leak. (The blumeops
1Password vault stays isolated; heph is a separate, deliberately-included
substrate.)

**Shape (all source-controlled — see `agent-workspaces.nix`):**

- `agent-heph-install.service` — a oneshot that `cargo install`s `heph`+`hephd`
  at a pinned tag (`hephTag`) using a **mise-resolved** Rust toolchain. nixpkgs'
  `rustc` lags heph's fast-moving floor (it shipped 1.91 vs the ≥1.92 a heph dep
  needs), so the toolchain comes from `mise x rust@stable` over the `nix-ld` +
  build-deps setup the host already provides for mise runtimes. Idempotent: it
  version-checks and only recompiles on a tag bump.
- `agent-heph-spoke.service` — runs `hephd --mode local --hub-url
  http://indri…:8787` (spoke sync is HTTP-only) authenticating via OIDC.
- The spoke's token lives in the **agents vault** (`op://agents/heph-spoke-token`),
  not a file, via hephd's **command token store** (`--token-load-cmd 'op read …'`
  / `--token-save-cmd heph-token-save`) — no plaintext token at rest. The
  `heph-token-save` wrapper writes refreshes back to the vault **without ever
  putting the token in argv** (`/proc/<pid>/cmdline` is world-readable) using op
  template files + `jq --rawfile`.

**Identity & revocation.** The spoke authenticates as a dedicated
**`heph-agents`** Authentik user in a heph-scoped group (*not* `admins` — that
would grant every admin-gated app), so it is independently revocable from the
human login. The hub admits it as a co-owner via `hephd --authorized-sub <sub>`
(the sub is a `hashed_user_id`, kept in the blumeops vault and templated into the
indri unit). Two independent kill switches, neither touching your own logins:
disable the `heph-agents` Authentik user, or drop its sub from the hub's
`--authorized-sub` and restart (the vault token goes inert even if unexpired).
Bound the refresh-token lifetime on the Authentik provider as the third lever.

See [[bootstrap-agent-workspaces]] for the one-time seeding steps.

## Report toolchain

The workspace PATH is a deliberately minimal curated set (op shim, git, ssh, tea,
coreutils, `~/.cargo/bin`, `~/.local/bin`) — it does **not** include
`/run/current-system/sw/bin`, so system-wide tools there are invisible to agent
sessions. The `research` workspace's `compile-report` / `save-session` tasks
(`mise run …`, each a `uv run --script` program) therefore need their toolchain
added explicitly. `agent-workspaces.nix` puts **mise, uv, pandoc, typst, and
weasyprint** (all nixpkgs builds) on the session PATH.

WeasyPrint is the wrinkle: `compile-report` pip-installs it into uv's *ephemeral*
venv, and that venv can only render a PDF if WeasyPrint's **native libraries**
(Pango, HarfBuzz, fontconfig, …) are discoverable. nix store libs live in no
default loader path, so the launcher exports `LD_LIBRARY_PATH` over
`pkgs.{pango,glib,harfbuzz,fontconfig,freetype,gdk-pixbuf,cairo,libffi}` — the
Linux counterpart of the repo's macOS Brewfile. (`pkgs.weasyprint` is on PATH so
`weasyprint` resolves as a CLI, but the render path is the uv venv, not that
binary.) `MISE_TRUSTED_CONFIG_PATHS=~/code/personal` is set so `mise run …` never
stalls on an interactive trust prompt.

> A **global `mise.toml`** installing these tools via mise backends was
> considered and rejected: mise's prebuilt binaries fight NixOS's dynamic linker
> (they need `nix-ld` at best), whereas nixpkgs builds are deterministic and
> already patched. The task's goal — the report tasks run unchanged — is met by
> the nix PATH, not a mise config.

## Authentication

Remote Control requires a **claude.ai subscription OAuth login** (not an API
key, not `claude setup-token`). On Linux the credential is a portable file at
`~/.claude/.credentials.json`; it is refreshed in place on use, so it must live
on a writable path. The `agent` user logs in once during [[bootstrap-agent-workspaces|bootstrap]].

### Terms of use

This deployment is *unsupported* (Anthropic won't treat breakage as a bug; see
[Known warts](#known-warts)) but not *prohibited*. It stays within subscription
terms as **ordinary, individual usage**: one human (Erich), one subscription,
native Claude Code via OAuth, steered on demand. Claude Code's
[legal terms](https://code.claude.com/docs/en/legal-and-compliance) peg Pro/Max
limits to *"ordinary, individual usage"* and reserve OAuth for *"ordinary use of
Claude Code and other native Anthropic applications"* — so the line to respect
is **attended, bounded use**, not a constantly-running autonomous fleet. Two
guardrails keep it clearly inside: (1) one human, one subscription, on demand —
never multi-user or serving others (that would require **API-key auth** via the
Agent SDK/Console instead); (2) cap or human-gate anything scheduled, since the
token-wasteful always-on pattern is also the fair-use risk.

## Operations

- **Deploy:** `mise run provision-ringtail` (writes `/etc/agents/*` secrets via
  ansible, then `nixos-rebuild switch`). First-ever deploy needs the one-time
  [[bootstrap-agent-workspaces]] steps (OAuth login, trust + consent seeding).
- **Status:** `ssh ringtail 'systemctl status "agent-ws-*"'`
- **Logs:** `ssh ringtail 'journalctl -u agent-ws-hephaestus -f'` — only errors
  (stderr); the Remote Control status TUI (stdout) is discarded to avoid ~1M
  journal lines/day/workspace. Live session activity is in the app; add
  `--debug-file` to the launcher for deep diagnostics.
- **Restart a workspace:** `ssh ringtail 'sudo systemctl restart agent-ws-hephaestus'`
  (ends that workspace's live sessions; the environment reappears in the app).

## Known warts

- `claude` for the `agent` user is installed by the official self-updating
  installer during bootstrap (imperative), not from nixpkgs — nixpkgs lags the
  npm channel and Remote Control is fast-moving. The service `ExecStart` points
  at `~agent/.local/bin/claude`.
- The service uses `util-linux`'s `script` to allocate a PTY (Remote Control
  renders a status TUI and has no `--headless` flag yet:
  [anthropics/claude-code#30447](https://github.com/anthropics/claude-code/issues/30447)).
- This whole deployment shape (Remote Control server, headless, multi-session)
  is unsupported by Anthropic — treat upgrades as capable of breaking it.

## Related

- [[bootstrap-agent-workspaces]] — one-time setup runbook
- [[agents-forgejo-bot]] — the bot account and its key
- [[security-model]] — service accounts and the `agents` vault
- [[ringtail]] — the host
