---
title: Agent Workspaces
modified: 2026-07-21
last-reviewed: 2026-07-08
tags:
  - reference
  - infrastructure
  - ai
---

# Agent Workspaces

A persistent [Claude Code](https://code.claude.com) **Remote Control** server on
[[ringtail]] — a single **home-base** session environment rooted in the `agents`
repo — that Erich steers on demand from the Claude mobile app or claude.ai/code.
The server spawns isolated per-session git worktrees of the home-base repo, so
several sessions can run concurrently; every other repo is a sibling checkout
the session `cd`s into.

This is the infrastructure landing of a prototype researched in the `research`
repo (`2026/July/Remote-Agent-Sessions-On-Ringtail/`). BlumeOps is the platform;
the agent workflows are built *upon* it.

## Design

```
Claude mobile app / claude.ai/code
        │   Anthropic relay (outbound-only from ringtail; no inbound ports)
        ▼
ringtail — user `agent` (isolated, non-wheel)
  systemd: agent-ws-agent.service  (the single home-base workspace)
    └─ claude remote-control --spawn worktree --name ringtail-agent
         cwd = ~/code/personal/agents
         PATH prepends the transparent `op` shim + ~/.cargo/bin (heph)
                   + the report toolchain (mise/uv/pandoc/typst/weasyprint)
  systemd: agent-repos-init.service  (oneshot, clones/updates repos first)
```

Checkouts live at **`~/code/personal/<repo>`** (not under a per-workspace dir) so
the paths agents read in the repo docs — every `AGENTS.md`/`CLAUDE.md` assumes
`~/code/personal/…` — actually resolve on the agent box.

### The home base: the `agents` repo

The session root is the [`agents` repo](https://forge.eblu.me/eblume/agents):
a small repo whose `AGENTS.md` (with `CLAUDE.md` symlinked to it) carries the
**base instructions** every remote session wakes up with — the repo map
(blumeops, hephaestus, research, …), the shared toolbox (heph, mise, uv, op,
tea, …), and the execution environments (`gilbert`, `ringtail`,
`ringtail-agent`). Per-repo details stay in each repo's own
`AGENTS.md`/`CLAUDE.md`, which the session reads after `cd`ing in.

Repos cloned by `agent-repos-init`:

| Repo | Role |
|------|------|
| `agents` | **Primary** — session cwd, worktree-isolated, base instructions |
| `hephaestus`, `hephaestus.nvim` | Sibling checkouts |
| `research` | Sibling checkout |
| `timberborn-parsimony` | Sibling checkout |
| `blumeops` | Pool-only, author-only — see [§blumeops](#blumeops-author-only-not-a-server) |

> **Concurrency caveat.** Only the **primary** repo gets per-session worktree
> isolation (that is what `--spawn worktree` operates on). Sibling checkouts are
> **shared** between concurrent sessions — the base instructions tell agents to
> work siblings on a session-named branch (or a manual `git worktree add` into
> the session's own worktree) so two sessions never fight over a checkout.

### Why one home-base server

A Remote Control server is rooted in its start directory; new sessions spawn as
worktrees of that repo and inherit its `CLAUDE.md`/tooling. The home-base shape
exploits that once: a session wakes up with the *base* instructions loaded and
`cd`s to whatever repo the task needs. One environment in the app, one service
to operate, one trust seed, one place to keep cross-repo instructions — and
adding a repo to the fleet is a one-line clone entry plus a paragraph in the
`agents` repo, not a new server. Idle servers cost nothing either way (no
inference until a session is active).

> **Superseded decision: per-repo servers (2026-07-08 → 2026-07-11).** The
> first landing ran one server per repo (`ringtail-hephaestus`,
> `ringtail-research`, `ringtail-playground`, briefly `ringtail-parsimony`) so
> each session woke up inside its repo with instructions preloaded. In practice
> the per-repo environment picker added friction (N environments, N services, N
> trust seeds, duplicated base instructions) for little gain — sessions
> regularly needed to cross repos anyway. Replaced by the single `agents`
> home base; the per-repo trick (cwd sets the instruction context) still does
> the work, just once. The `playground` workspace was dropped outright — a
> home-base worktree is already a safe scratch space.

### blumeops: author-only, not a server

blumeops is cloned into the pool at `~/code/personal/blumeops` (agent-owned, so
`git` works) but is **not** a workspace — there is no `ringtail-blumeops` Remote
Control server. Agents `cd` into it from any session to **author** changes and
open PRs as the [[agents-forgejo-bot|bot]]. The bot has only **read** on the
canonical repo and works through its fork **`agents/blumeops`**: the clone's
`origin` is the fork (push), `upstream` is `eblume/blumeops` (fetch) — branch off
`upstream/main`, and PRs are cross-repo. This is safe because blumeops is a
**public, secret-free** repo: the gate has never been the code, it is the
**blumeops 1Password vault**, **cluster access**, and **CI execution** — and an
agent holds none of them.

- **No deploy via ansible.** `provision-{indri,ringtail}` and most `mise` tasks
  `op read` the blumeops vault in `pre_tasks` (so even `--check --diff` dies at
  the lookup, not just apply). An agent authenticates only as the `agents`-vault
  service account → `403`. Vault access is per-vault, all-or-nothing (no
  item-level whitelist), and biometric `op` can't be routed to a headless worker
  anyway — so there is no least-privilege subset to grant. That is by design: the
  vault is the operational-secret blast-radius boundary (argocd break-glass,
  every ansible secret).
- **No deploy via k8s.** The k3s admin kubeconfig is `0600` root-only
  (`--write-kubeconfig-mode=600`), so the agent can neither `kubectl` nor read
  the `argocd-*` secrets; it is non-`wheel` with no sudo. (It was `0644` until
  2026-07-10 — a hole that *did* hand the agent cluster-admin and an ArgoCD-admin
  deploy path; see [§Isolation](#isolation--security).)
- **No deploy via CI.** blumeops' deploy workflows carry Actions secrets
  (`ARGOCD_AUTH_TOKEN`, `FLY_DEPLOY_TOKEN`, `ZOT_CI_API_KEY`, `MAIN_PUSH_TOKEN`).
  `workflow_dispatch` is write-gated and the bot has only **read**, so it cannot
  run a workflow — not even a modified one on a branch — to read those secrets.
  Without this, write access would let the bot dispatch a branch workflow that
  exfiltrates the deploy tokens (Forgejo has no per-run approval gate for write
  users), which is exactly why the bot is read-only + fork here.

Net: an agent can edit code/docs and open a blumeops PR, but a human
provision/sync on gilbert (biometric `op`) always sits between that PR and
production, and `main` is branch-protected (push + merge whitelisted to
`eblume`) on top. The agent-owned pool clone is distinct from the **root-owned
deploy checkout at `/etc/blumeops`** that `nixos-rebuild` builds from (the agent
can read its files but not `git` it — dubious-ownership guard).

> **Superseded decision.** blumeops was *dropped entirely* on 2026-07-08 on the
> reasoning that author-only was too thin to bother standing up. Reinstated
> 2026-07-10 as a pool-only clone: authoring blumeops from other workflows turned
> out to be valuable context worth having, and the deploy gate holds without a
> server. (`project-template` and `adelaide-baby-shower-app`, once cloned
> alongside, can be added the same way if wanted — no vault dependency.)

## Isolation & security

The boundaries, weakest-first:

1. **Vault boundary** — agents authenticate to 1Password only as the
   `agents-ringtail-rw` [[security-model|service account]] (read/write, the
   `agents` vault *only*). Everything outside that vault is unreachable. This is
   the hard secrets wall.
2. **User boundary** — the `agent` user is not in `wheel`, has its own home, and
   never sees Erich's `~/.claude` credentials, repo checkouts, or shell history.
   Also (co-tenant on the k3s host): the k3s admin kubeconfig is `0600` root-only
   (`--write-kubeconfig-mode=600`), so the agent cannot `kubectl` the cluster or
   read k8s secrets. **This was `0644` (world-readable) until 2026-07-10** — a
   real hole that gave the agent cluster-admin and, via `argocd-initial-admin-secret`,
   an ArgoCD-admin deploy path entirely bypassing the vault gate below. Locking it
   is what makes the k8s deploy surface actually inaccessible to agents.
3. **Credential handling** — the service-account token lives at
   `/etc/agents/op-token` (owned by `agent`, mode 0400) and is injected by a
   transparent `op` shim (see below) so it never appears in a session's
   environment (agents dump `env` while debugging, and transcripts get
   archived).
4. **Git-mediated writes** — agents push as a dedicated Forgejo bot
   ([[agents-forgejo-bot]]) and open PRs rather than committing to `main`. For
   the repos the bot has *write* on (`hephaestus`, …) this is convention backed
   by human PR review. For **`blumeops` it is enforced**: the bot has only
   **read** on the canonical repo and pushes to its **fork** (`agents/blumeops`),
   opening cross-repo PRs. Read-not-write is deliberate — `workflow_dispatch` is
   write-gated, so a read-only bot **cannot run blumeops CI** and therefore
   cannot reach the deploy-credentialed Actions secrets (`ARGOCD_AUTH_TOKEN`,
   `FLY_DEPLOY_TOKEN`, `ZOT_CI_API_KEY`, `MAIN_PUSH_TOKEN`); `main` is also
   push+merge-whitelisted to `eblume`. This is what actually keeps **deploy
   credentials out of agent reach** — layered over the fact that the bot holds
   neither the blumeops vault nor cluster access, so even a hypothetical `main`
   commit deploys nothing until a human provisions. PRs are opened with `tea`,
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

**Shape (all source-controlled — see `agent-workspaces.nix`; the version pin,
hub/OIDC endpoints, and install/timer/path machinery are shared with Erich's
own `eblume-heph-spoke` via `heph-common.nix` — see [[ringtail]] §Heph
Spokes):**

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
sessions. The `research` repo's `compile-report` / `save-session` tasks
(`mise run …`, each a `uv run --script` program) therefore need their toolchain
added explicitly. `agent-workspaces.nix` puts **mise, uv, pandoc, typst, and
weasyprint** (all nixpkgs builds) on the session PATH.

Alongside the report toolchain the launcher also adds a **general CLI toolbox**
(`cliTools`: **gawk, jq, curl, python3**) — the staples a plain shell agent
reaches for to munge text/JSON and write quick scripts. Without them sessions hit
`command not found` on `awk`/`jq` pipelines and fall back to slower workarounds
(WebFetch for `curl`, a full `uv run --script` for a `python3` one-liner). `uv`
is already present for `uv run --script`; `python3` is a bare interpreter for
one-off snippets and stdlib. All are nixpkgs builds on the curated PATH, so no
`/run/current-system/sw/bin` exposure is implied.

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

## Build toolchain

The curated PATH also omitted a **C toolchain**, so `cargo build` — and anything
that links a native binary — failed in a session with ``linker `cc` not found``.
The heph *install* oneshot sidesteps this with its own `gcc`/`pkg-config` env
(`hephBuildDeps`), but interactive sessions inherited none of it, so agents could
not compile or verify Rust they authored.

The launcher now adds **`buildTools`** (`gcc`, `binutils`, `pkg-config`,
`gnumake`) to the session PATH and exports `CC=gcc`. Rust itself still comes from
**mise** (`rust@stable`) — nixpkgs' `rustc` lags, exactly as for the heph install
— so this change supplies only the linker and pkg-config that mise's toolchain
needs to actually build.

For the `gamedev` **Bevy** project specifically, the launcher also exposes Bevy's
Linux native deps the same way the report toolchain exposes WeasyPrint's: `alsa`
and `udev` (pkg-config-probed at build) go on `PKG_CONFIG_PATH` via
`gameBuildDeps`, and the windowing/graphics libs that Bevy `dlopen`s at run time
(`vulkan-loader`, `libxkbcommon`, `wayland`, `libGL`, and the core `xorg`
client libs) go on `LD_LIBRARY_PATH` via `gameLibs`.

> This lets agents `cargo build`/`cargo check` to verify their work. It does
> **not** make the headless box *run* a windowed Bevy app — there is no GPU or
> display — so actually playtesting a build stays a human job on gilbert/ringtail,
> consistent with the timberborn-parsimony playtest rule.

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
- **Status:** `ssh ringtail 'systemctl status agent-ws-agent'`
- **Logs:** `ssh ringtail 'journalctl -u agent-ws-agent -f'` — only errors
  (stderr); the Remote Control status TUI (stdout) is discarded to avoid ~1M
  journal lines/day. Live session activity is in the app; add
  `--debug-file` to the launcher for deep diagnostics.
- **Restart the workspace:** `ssh ringtail 'sudo systemctl restart agent-ws-agent'`
  (ends live sessions; the `ringtail-agent` environment reappears in the app).

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
