---
title: Forgejo Runner
modified: 2026-10-16
last-reviewed: 2026-10-16
tags:
  - service
  - ci-cd
---

# Forgejo Runner

Forgejo Actions runner daemon for CI/CD job execution. Runs as a
native macOS LaunchAgent on [[indri]] — the unit, the main
runner's `config.yaml` and the cache maintenance agents are
nix-managed (the [[indri]] flake's generation, eblume/blumeops#1528),
and the `forgejo_runner` ansible role renders only the build
runner's config and colima profile (eblume/blumeops#1627); jobs
run
host-mode with no container engine. (Previously
a minikube pod with a Docker-in-Docker sidecar — replaced in phase 0 of
[[retire-minikube]].)

## Quick Reference

| Property | Value |
|----------|-------|
| **LaunchAgent** | `mcquack.eblume.forgejo-runner` (unit nix-managed — [[indri]] §Maintenance Notes) |
| **Ansible role** | `ansible/roles/forgejo_runner/` (build runner's config and colima profile; eblume/blumeops#1627) |
| **Runner Name** | `indri-runner` |
| **Labels** | `indri` + `indri-priv` (dedicated to warrant-dispatched provision-indri; same physical runner) |
| **Capacity** | 2 concurrent jobs |
| **Timeout** | 3h |
| **Forgejo Instance** | https://forge.ops.eblu.me |
| **Binary** | nixpkgs package (13.1.0, the [[indri]] flake's nixpkgs pin); the source checkout at `~/code/3rd/forgejo-runner` is the build runner's rollback re-write's target |
| **Config** | `~/forgejo-runner/config.yaml` (indri) |
| **Logs** | `~/Library/Logs/mcquack.forgejo-runner.{out,err}.log` → Loki via [[alloy]] |
| **Cache maintenance** | Nightly sweep at 5:30 AM; monthly prune day 1 at 3:30 AM |

## Architecture

The daemon polls forge for jobs and launches each job step host-mode
as `erichblume` — see Job Execution below. The runner has no container
engine (Docker Desktop was retired in eblume/blumeops#1382); the [[zot]]
registry mirror for docker.io pulls lives in the indri-build colima
profile's `docker:` block (`host.lima.internal:5050`), where the pulls
now happen.

The main runner's `config.yaml` (including the runner token, labels and
the forge-ci GitHub PAT) is rendered by the [[indri]] flake's generation
from `forge/runners.json` plus the seed-secrets identity files, and a
content change kickstarts the agent (eblume/blumeops#1528) — so label,
capacity and identity changes apply with `--tags rebuild`. Only the
`indri-build` runner's config and colima profile (until
eblume/blumeops#1627) stay managed by the `forgejo_runner` ansible role;
the LaunchAgent unit is nix-managed
(`launchd.user.agents."mcquack.eblume.forgejo-runner"` in the [[indri]]
flake) and runs the nixpkgs `forgejo-runner` binary.

There are also four sandboxed NixOS runner services on [[ringtail]]
(`services.gitea-actions-runner` in `nixos/ringtail/configuration.nix`),
each with its own repo-scoped registration token (three of them share the
`nix-container-builder` label, one each for eblume/blumeops, eblume/horkos
and eblume/talos):

- `ringtail-nix-builder-{blumeops,horkos,talos}` (`nix-container-builder` label) — the
  `build-container.yaml` nix build job, as the module's DynamicUser
  `gitea-runner`. That user is **not** a trusted nix user
  (`nix.settings.trusted-users` is the nixos-26.05 default `[ "root" ]`);
  `allowed-users = *` gives it plain daemon access, which `nix build`
  needs (blumeops#1358 amendment 1).
- `ringtail-priv-runner` (`priv` label) — privileged workflows
  ([[warrant-approval-gated-runs]] Phase 2): the warrant dispatch-only
  class, plus the `class: auto` push-triggered ringtail-rebuild
  ([[auto-apply]]). Deliberately NOT host-mode-as-erichblume:
  a hostile privileged job compromises a sandbox, not the forge owner's
  account. Runs as the static system user `horkos-runner`, which the
  ringtail-rebuild polkit rule names ([[warrant-approval-gated-runs]]).

## Second runner: indri-build (unprivileged)

`indri-build` is a dedicated unprivileged macOS user on [[indri]] (uid 503
in its own primary group - the nix-darwin default of `staff` would let it
read erichblume's 0750 home - no sudo, home `/Users/indri-build` 0700)
running the instance's second
forgejo runner (label `indri-build`, eblume/blumeops#1357). It exists
because host-mode jobs as `erichblume` can reach anything erichblume can,
which is everything; the build user is the scoped-down alternative for
workloads that do not need that reach, until #1358 gives it per-repo
isolation.

| Property | Value |
|----------|-------|
| **User** | `indri-build` (uid 503, own primary group, no sudo, home 0700) |
| **Runner name** | `indri-build` |
| **Label** | `indri-build` (host-mode) |
| **Capacity** | 4 concurrent jobs (`forgejo_runner_build_capacity`) |
| **Daemons** | `mcquack.eblume.colima-build` + `mcquack.eblume.forgejo-runner-build` (system launchd domain, nix-managed) |
| **Engine** | colima (nixpkgs `colima`, v0.10.1 at the 26.05 pin), profile `~indri-build/.colima/indri-build/` |
| **Socket** | `~indri-build/.colima/indri-build/docker.sock` (mode 0660, owned by `indri-build` - not world-reachable, not under /Users/Shared) |
| **Config** | `/Users/indri-build/forgejo-runner/config.yaml` (role-rendered, gated on registration) |
| **Logs** | `~indri-build/Library/Logs/mcquack.colima-build.{out,err}.log`, `mcquack.forgejo-runner-build.{out,err}.log` |

### Isolation

- The homes are 0700 **both ways**: `indri-build` cannot read
  `/Users/erichblume` and erichblume cannot read `/Users/indri-build`.
- Host-mode jobs are isolated by the 0700 homes: `indri-build` is in its
  own primary group (not `staff`), so it cannot even stat erichblume's
  0750 home, and host-mode jobs never enter the VM at all.
- For docker-mode jobs the colima profile's explicit `mounts:` list
  (`/Users/indri-build` only) is the container boundary - a job step cannot
  `-v` another user's home into a container - and the socket is mode 0660
  rather than world-reachable. The `colima.yaml` itself lives in the build
  user's home, so it is not an isolation control: jobs can rewrite it; what
  is controlled is the VM's mounts and the socket's reach.

### Toolchain

Host-mode steps resolve tools through `~indri-build/.local/share/mise/shims`
(the runner daemon's PATH), so the build user's mise global config
(`environment.etc."mise/config-build-user.toml"` in the flake) is what every
indri-build job sees: the erichblume pins plus `rust` - its jobs run the
macOS-native cargo check on the host, and its 0700 home can't reach
erichblume's rustup install. A first run of a newly pinned version
auto-installs through the shims (or `mise install` as indri-build, once).

**Nix:** host-mode steps also resolve `nix` (the default profile's bin dir,
last on the daemon's PATH) and build through the Determinate multi-user
daemon as the untrusted `indri-build` user. The #1358 trigger
split moves the two nix-building PR jobs onto indri-build, so it has to hold. **`indri-build` is never a trusted
Nix user**: the daemon's `allowed-users = *` lets it submit builds, which
then run **unsandboxed, with network access, as the shared `nixbld` build
user** (indri's daemon config read as root 2026-10-08: `sandbox = false`,
`sandbox-fallback = true`, `trusted-users = root`, `allowed-users = *`).
Widening its trust is a deliberate change to Determinate's host-side
`/etc/nix/nix.custom.conf`, never the flake.

### Known gaps (accepted for now, scoped by #1358)

- **Cross-repo cache persistence**: the runner's home - mise shims and the
  cargo/dagger/uv caches - is shared across ALL repos' jobs on this
  instance-wide runner. A job from one repo can poison another repo's
  toolchain or cache until #1358 scopes the runner per repo.
- **Localhost/tailnet reach**: the build user can reach indri's localhost
  services (for example the registry mirror, the forge itself) and carries
  a tailnet identity. Accepted, and on the #1358 scope-down list.

## Job Execution

Host-mode ([[retire-minikube]] phase 6): workflow steps run directly as
`erichblume` on indri with the mise-managed toolchain. The dagger
pipelines that once ran here now run on indri-build, whose engine is a
container in the colima VM (eblume/blumeops#1357); Docker Desktop's
engine role is retired (eblume/blumeops#1382). The old arm64
`runner-job-image` is retired.

The host toolchain is declared in the indri nix-darwin flake's global mise
config (`darwin/indri/configuration.nix`, entry `[tools]`) — read it there
rather than trusting a list here, which is how this card came to advertise a
`jq` the role never installed. Anything else a job needs comes from the
repo's own `mise.toml`, or from a Dagger container.

**`prek` needs company.** prek downloads the environment for most hooks, but a
`*-system` hook runs whatever is on `PATH` by definition — so `actionlint` and
`stylua` are the host's responsibility, and a missing one is reported as a
*failed* hook, not a skipped one. Adding a `*-system` hook to any repo's
`prek.toml` means adding its binary here.

## Cache Maintenance

Host-mode jobs run `uv run --script` with the global cache, and uv keys
per-script environments on the script's **absolute path** — and the
runner gives every job a fresh `~/.cache/act/<random8>/` scratch path —
so every job's `mise-tasks/*` scripts get a fresh environment that never
gets reused. The environments accumulated until `~/.cache/uv` reached
66G at ~2G/day (2026-09); wheels stay shared in the archive cache, so
only the per-script venv scaffolding leaks. As dependency pins move,
orphaned wheel archives pile up too (`archive-v0` reached 16G over
18 months).

`uv cache prune` is deliberately not used for the scheduled sweep:
tested, it removes *every* script environment, including ones whose
script still exists and ones with a Python process currently running in
it — an idle-runner operation, so it runs in its own monthly window
with the runner stopped. Two LaunchAgents (in the nix-darwin generation) handle the
recurrence:

- **Nightly sweep** — `mcquack.eblume.runner-cache-sweep` (default
  5:30, clear of borgmatic's 2:00 and 4:00 runs):
  - Deletes `~/.cache/uv/environments-v2` entries not modified in
    240 minutes. The threshold deliberately exceeds the runner's
    3-hour job timeout, so a live job's environment (created when its
    job starts) is never touched.
  - Runs `prek cache gc`.
  - Logs before/after `du -sm` of both caches to
    `~/Library/Logs/mcquack.runner-cache-sweep.{out,err}.log`, shipped
    to [[loki]] by the [[alloy]] role.
- **Monthly `uv cache prune`** — `mcquack.eblume.runner-cache-prune`
  (day 1, 03:30, clear of borgmatic at 02:00). The script boots the
  runner LaunchAgent out, then polls (bounded — the prune aborts if the
  process is still alive past its window) for it to exit, prunes, and
  bootstraps the runner back — a `trap` restores the runner even if the
  prune fails. Note launchd clamps `ExitTimeOut` to 60 s in the per-user
  gui domain, so the plist's declared value is not what bounds the
  bootout; the script's own poll window is. Jobs queued during the
  window simply wait on forge. Log:
  `~/Library/Logs/mcquack.runner-cache-prune.{out,err}.log`.

## Credentials

| Secret | Source | Purpose |
|--------|--------|---------|
| runner UUID | 1Password ("Forgejo Secrets" → `runner_indri_uuid`) | Static runner identity for `server.connections` |
| runner token | 1Password ("Forgejo Secrets" → `runner_indri_token`) | Static runner credential for `server.connections` |
| GitHub PAT | 1Password ("Forgejo Secrets" → `forge-ci-github-pat`) | `MISE_GITHUB_TOKEN` in `runner.envs`, injected into every job |

For the main runner the three values are declared in
`darwin/indri/secrets.json` and seated by `mise run seed-secrets
indri` (a human, on gilbert) as the identity files under the runner's
home (`~/forgejo-runner/identity/`, 0600 erichblume:staff); the
generation renders them into `config.yaml` (0600), and a content
change kickstarts the agent. Rotation = re-register (see
[[configure-launchd-runner]]) → update the "Forgejo Secrets"
1Password item → `mise run seed-secrets indri` (re-seat + kick the
agent) → the next `--tags rebuild` apply re-renders the config. The
`indri-build` runner still works the old way — playbook `pre_tasks`
fetches its values via `op` (`op item get` for the identity fields,
`op read` for the PAT) and the role renders its config at provision
time — until eblume/blumeops#1627, so the table above reads
correctly for both runners.

The GitHub PAT exists because Forgejo injects `GITHUB_TOKEN` (a *forge*
job token) into every job, and mise honours that name for
`api.github.com` — so any GitHub-backed tool resolution takes a 401.
`MISE_GITHUB_TOKEN` outranks it in mise's lookup order (first non-empty
of `MISE_GITHUB_TOKEN`, `GITHUB_API_TOKEN`, `GITHUB_TOKEN` wins). The
token is the same zero-permission public-read PAT the mirror sync uses
— rotation and constraints in [[manage-forgejo-mirrors]]. Because
`runner.envs` is readable by every job on this runner, the no-scopes
rule is load-bearing: a credential that needs *any* scope needs its own
token and a narrower home. On the main runner a runner-env change
takes effect when the `mise-github-token` file is re-seeded (`mise
run seed-secrets indri`) and the generation re-applied — the
`--tags rebuild` switch — so a PAT rotation is not live for CI until
then.

## Related

- [[configure-launchd-runner]] — setup, registration, cutover
- [[forgejo]] — the forge this runner connects to
- [[zot]] — registry mirror for job image pulls
- [[build-container-image]] — how container images are built via this runner
