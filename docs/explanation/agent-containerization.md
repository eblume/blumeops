---
title: Agent Containerization
modified: 2026-07-30
last-reviewed: 2026-07-30
tags:
  - explanation
  - infrastructure
  - ai
  - security
---

# Agent Containerization

Why the `ringtail-agent` workspace is moving from a **shared-host OS user** to a
**pod with its own Tailscale identity** — and why that migration is the *only*
real fix for the device-trust hole it closes, not merely defense-in-depth.

This is the executed recommendation for the containerization spike (heph
`01KXBNMY…`). It supersedes the "Network *(future)*" and "container phase" notes
in [[agent-workspaces]] §Isolation.

## The problem: device identity, not file modes

The [[agent-workspaces|current model]] runs the agent as a real local user
(`agent`) on [[ringtail]], sharing the host with root-owned services (k3s,
forgejo-runner, tailscale). Two consequences, one known and one worse:

1. **Unix file modes are the only boundary.** Every root secret dropped on the
   box becomes a "can `agent` read this?" audit. We already hit one live
   ([`k3s.yaml` shipped `0644`](../reference/infrastructure/agent-workspaces.md)
   = cluster-admin kubeconfig, since locked to `0600`). This is the whack-a-mole
   the spike set out to dissolve.

2. **The tailnet cannot tell the agent apart from the host.** Tailscale ACL
   identity attaches to the **device**, not the OS user. `ringtail` carries
   `tag:homelab`, and the ACL grants `tag:homelab → tag:homelab` full L3/L4 plus
   an SSH `accept` rule. Any local user — including `agent` — egresses through
   ringtail's `tailscale0`, so **`agent` inherits ringtail's device trust
   wholesale**. Confirmed 2026-07-22 (heph `01KY57XB…`): from ringtail as OS
   user `agent`, `ssh erichblume@indri` drops an interactive shell as the owner
   of Forgejo canonical, the runner, and deploy tooling — bypassing the entire
   read-only-bot fence.

### Why we can't just fix the ACL

The obvious patch — delete the `tag:homelab → tag:homelab` SSH `accept` rule —
**does not work**, for two independent reasons:

- **It's load-bearing.** Borgmatic on indri SSHes into `eblume@ringtail` to run
  `sudo k3s kubectl` for the mealie/shower/navidrome pre-backup DB dumps
  (`ansible/roles/borgmatic/templates/k8s-sqlite-dump.sh.j2`). Removing the rule
  breaks backups.

- **It wouldn't be enough anyway.** Even with SSH gone, a shared-host `agent`
  can send packets straight out ringtail's `tailscale0` interface — the
  `tag:homelab → tag:homelab ip:*` grant gives it full L3/L4 reach to indri
  (forge, everything) regardless of the SSH rule. No ACL or tag can gate a user
  the tailnet sees as the *same device* as the host.

**A network namespace is the fix.** Give the agent its own Tailscale node — a
sidecar in the pod, carrying a distinct `tag:agent` — and the ACL can finally
express "the agent reaches X but not Y." That is why containerization *is* the
fix here, not a layer on top of one.

## Target architecture

```
k3s-ringtail cluster
  namespace: agent-ws
    Deployment: agent-ws
      ├─ container: agent            (claude Remote Control + curated toolchain)
      │    - runAsNonRoot, no host mounts, dropped caps
      │    - envFrom: op-token Secret  → OP_SERVICE_ACCOUNT_TOKEN (agents vault only)
      │    - volumeMount: forge SSH key Secret (0400)
      │    - volumeMount: PVC  → ~/.claude (OAuth cred, refreshed in place)
      │                          + ~/code/personal (repo pool, per-session worktrees)
      │    - ServiceAccount: agent-ws (NO cluster access; see below)
      └─ container: tailscale (sidecar)
           - authenticates with an auth key tagged tag:agent
           - the pod's ONLY tailnet identity; all agent egress routes through it
    NetworkPolicy: egress allowlist (Anthropic relay, 1Password, indri:{443,2222,8787})
```

### The repo pool

`containers/agent-ws/repos.json` is the source of truth for what lands in
`~/code/personal` on the PVC — and, via `mise run agent-repo-access`, for the
forge collaborator grants that make those clones possible at all. `default.nix`
reads it with `builtins.fromJSON` to generate the entrypoint's clone loop:

| Repo | Model | Why |
|------|-------|-----|
| `agents` | **fork** (`origin` = `agents/agents`, `upstream` = canonical) | Session cwd + base instructions; edits go via cross-repo PR so the agent can't rewrite its own instructions unreviewed |
| `blumeops` | **fork** | Author-only; the read-only-on-canonical fence keeps CI (and its deploy secrets) out of reach |
| `hephaestus`, `hephaestus.nvim`, `research`, `myeve`, `timberborn-parsimony`, `gamedev` | canonical, bot has push | Ordinary author repos — branch + PR |

> **A pooled repo has to be *buildable*, not just present.** `gamedev` was
> granted but held at `pool: none` for exactly this reason, and adding it meant
> carrying Bevy's native libraries in the image (`gameLibs` in `default.nix` —
> `PKG_CONFIG_PATH` for the `-sys` crates that probe at build time,
> `LD_LIBRARY_PATH` for the ones `dlopen`'d at run time). Rust itself stays out
> of the image and comes from mise onto the PVC. When adding a repo, check what
> its toolchain needs from the image before flipping `pool`.

Adding a repo is one edit to `repos.json`. It used to be two independent manual
steps — clone-loop entry *and* forge collaborator grant — and a missing grant is
indistinguishable from a typo (Forgejo 404s rather than 403s on a private repo
you cannot see), while the clone loop is deliberately non-fatal, so the only
symptom was an absent directory. `timberborn-parsimony` was absent that way for
three weeks. See [[agents-forgejo-bot]] §"Sharing a repo with the bot".

`blumeops` and `agents` are pinned read-only by an invariant in the reconciler
that `repos.json` cannot override — that fence lives in reviewed code, not in a
data file.

Only `agents` gets per-session worktree isolation (`--spawn worktree` operates
on the cwd repo); every other checkout is **shared** across concurrent sessions,
which is why the base instructions tell agents to work siblings on a
session-named branch.

### The Tailscale fence (`tag:agent`)

The sidecar makes the pod a first-class tailnet device with its own identity, so
the ACL grants it **exactly** what an authoring agent needs and nothing else:

| Needs | Endpoint | ACL |
|-------|----------|-----|
| Forge push (git SSH via Caddy L4) | `forge.ops.eblu.me:2222` → indri | `tag:agent → tag:homelab tcp:2222` |
| Forge / `tea` PRs (HTTPS via Caddy) | `forge.ops.eblu.me:443` → indri | `tag:agent → tag:homelab tcp:443` |
| heph spoke sync | `indri:8787` (HTTP) | `tag:agent → tag:homelab tcp:8787` |
| Claude relay, 1Password, `forge.eblu.me` | public internet | NetworkPolicy egress, not tailnet |

Everything else is default-deny: **no `tag:agent` SSH rule at all** (Tailscale
SSH to any host is refused), no `:22`, no k8s API, no NAS, no registry, no other
homelab port. The `tag:homelab → tag:homelab` grant and SSH `accept` rule stay
**unchanged** — borgmatic keeps working, because the agent is no longer a
`tag:homelab` device.

This foundation (tagOwner + grant + ACL tests) ships **first**, in
`pulumi/tailscale/policy.hujson`. The tests assert the denials hold even before
a device carries the tag, so the fence is validated as policy logic independent
of the pod rollout.

> **The node-NAT trap (must prove on-box).** A k3s pod egresses through the
> node by default, so a pod reaching indri's tailnet IP would appear as
> *ringtail's* `tag:homelab` identity — silently re-opening the exact hole this
> closes. The `tag:agent` identity is only real if the agent's forge/heph
> traffic routes through the **sidecar's** tailscale interface, and a
> NetworkPolicy blocks the pod's direct node path to the tailnet CGNAT range
> (`100.64.0.0/10`). Internet traffic (Claude relay, 1Password) still egresses
> via the node — that's fine, it carries no tailnet identity. Proving that the
> pod reaches indri *only* as `tag:agent` (and not as the node) is the first
> deploy milestone, ahead of any cutover.

### Secrets, unchanged in spirit

- **1Password:** the `agents`-vault service-account token becomes a k8s Secret
  injected as `OP_SERVICE_ACCOUNT_TOKEN`. The [[agent-workspaces|op shim]]
  already prefers that env var over the host file, so it works unmodified in a
  pod. The blumeops vault stays unreachable — that fence is untouched.
- **Forge:** the [[agents-forgejo-bot]] SSH key + the scoped `FORGEJO_TOKEN`
  become mounted Secrets. The "read-only on canonical, author via fork, can't
  push main, can't dispatch CI" fences are *easier* to hold in a pod — it has no
  kubeconfig and a restricted ServiceAccount.
- **heph:** the spoke's OIDC token store (`op read` command-token pattern) works
  from the pod the same way; the spoke stays deliberately in-boundary.

### What stays host-bound

- **Timberborn playtest** already required host DLLs and a GPU — it was always a
  human job on gilbert/ringtail, unchanged.
- **The report/build toolchain** (mise, uv, pandoc, typst, weasyprint,
  gcc/rust) moves *into the image* rather than onto a curated host PATH — the
  same tools, sourced deterministically at build time.

## Migration plan

1. **Identity foundation (this PR).** `tag:agent` tagOwner + fence grant + ACL
   tests in `policy.hujson`; this design doc. No behavior change until a device
   carries the tag. Deploy: `mise run tailnet-up`.
2. **Image.** A Nix `dockerTools` image (per repo convention) with the curated
   toolchain baked in — `containers/agent-ws/default.nix`. `claude` is **not**
   baked: it self-installs at pod-start onto the PVC via Anthropic's official
   installer, so the image rebuilds only on toolchain changes, not claude
   releases. The image symlinks the glibc loader so the prebuilt `claude`/rust
   ELF binaries run in the non-FHS nix image (the container analogue of the
   host's `nix-ld`).
3. **Manifests.** `argocd/manifests/agent-ws/`: Deployment (agent + userspace
   `tag:agent` tailscale sidecar), restricted ServiceAccount (no cluster API,
   token not mounted), PVC for `$HOME`, two ExternalSecrets (the op token from
   the blumeops vault; the tag:agent auth key synced there by
   `mise run agent-ws-authkey-sync`), and the egress NetworkPolicy. **The whole
   egress mechanism was proven on-box first** (throwaway proof-pod): the pod
   registers as its own `tag:agent` device, reaches forge/heph via the sidecar
   SOCKS proxy (ACL grant confirmed), the node-NAT trap is real, and the
   NetworkPolicy closes it while leaving the SOCKS path intact. The agent talks
   to the forge over **HTTPS+token through the SOCKS proxy** (not ssh — the bot
   ssh key is agents-vault-only, unreachable by external-secrets; HTTPS also
   dodges ssh-over-SOCKS). **One-time bootstrap:** claude's OAuth login must be
   seeded onto the PVC once — temporarily run the agent container as `sleep`,
   `kubectl exec` in, run `claude` → `/login`, then let the entrypoint launch
   Remote Control (mirrors the host bootstrap).
4. **Cutover.** Retire `agent-ws-agent.service` + the host-user heph spoke from
   `nixos/ringtail/`; the pool clone and `/etc/agents/*` host secrets go away.
5. **Verify** the read-only-bot fences from inside the pod (folds in heph
   `01KXBEZF…` / Phase 4 `01KY3ZTVX6…`): push-to-fork OK, push-to-canonical
   denied, `workflow_dispatch` denied, `ssh erichblume@indri` **denied**.

## Liveness: zombies, not crashes

The observed failure mode of Remote Control (2026-08-01, first day in the pod)
is a **zombie, not a crash**: after a transient WAN blip the process survived
but never re-dialed Anthropic — it sat idle holding only unix sockets while
Kubernetes reported a healthy container for six hours and every Claude client
saw a dead server. Crashes already self-heal (claude exits → `script` exits →
container restarts), so the gap is detection, not recovery.

The `agent` container therefore carries an exec `livenessProbe`
(`agent-ws-health`, baked into the image): healthy iff **some claude process
holds at least one ESTABLISHED TCP connection** — a healthy Remote Control
keeps a persistent gateway websocket even when idle. Because `/proc/net/tcp*`
is netns-wide (the ts sidecar's always-up control-plane connections would mask
the signal), the probe matches each claude process's socket-fd inodes against
the ESTABLISHED rows rather than testing the table globally. Timing is
generous (~10 min of confirmed zombie before restart) because boot legitimately
spends minutes cloning the repo pool and self-installing claude — and the
penalty is small: a container-only restart preserves the PVC and the ts
sidecar's tailnet identity, so a recycled zombie comes back as the same
`agent-ws` node with the same repo pool. A live session that still streams
counts as healthy, so the probe never kills active work.

### The one unknown to prove on-box

Remote Control is unsupported and needs a **PTY** (the `script` hack) plus an
**OAuth credential file refreshed in place** — there is no `--headless` flag
([claude-code#30447](https://github.com/anthropics/claude-code/issues/30447)).
Running that shape in a pod (PTY allocation, OAuth cred on a writable PVC,
outbound-only relay) is the risk the spike flagged. It must be proven with a
deploy-and-drive loop on the box before the host-user service is retired — the
one step that can't be desk-checked. Steps 1–3 are safe to land ahead of it.

## Related

- [[agent-workspaces]] — the model being migrated
- [[agents-forgejo-bot]] — the identity whose fences this hardens
- [[security-model]] — service accounts and vault scoping
- [[ringtail]] — the host / cluster
