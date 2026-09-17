---
title: Forgejo Runner
modified: 2026-09-13
last-reviewed: 2026-06-10
tags:
  - service
  - ci-cd
---

# Forgejo Runner

Forgejo Actions runner daemon for CI/CD job execution. Runs as a
native macOS LaunchAgent on [[indri]], managed by the
`forgejo_runner` ansible role; jobs execute as containers against
Docker Desktop's daemon. (Previously a minikube pod with a
Docker-in-Docker sidecar — replaced in phase 0 of
[[retire-minikube]].)

## Quick Reference

| Property | Value |
|----------|-------|
| **LaunchAgent** | `mcquack.eblume.forgejo-runner` |
| **Ansible role** | `ansible/roles/forgejo_runner/` |
| **Runner Name** | `indri-runner` |
| **Labels** | `indri` |
| **Capacity** | 2 concurrent jobs |
| **Timeout** | 3h |
| **Forgejo Instance** | https://forge.ops.eblu.me |
| **Binary** | source-built at `~/code/3rd/forgejo-runner/forgejo-runner` (version pinned in role defaults) |
| **Config** | `~/forgejo-runner/config.yaml` (indri) |
| **Logs** | `~/Library/Logs/mcquack.forgejo-runner.{out,err}.log` → Loki via [[alloy]] |
| **Cache maintenance** | Nightly sweep at 5:30 AM; monthly prune day 1 at 3:30 AM |

## Architecture

The daemon polls forge for jobs and launches each job step in a
container via Docker Desktop (`/var/run/docker.sock`). The socket is
mounted into job containers (docker-outside-of-docker), so `docker`
and `dagger` invocations inside jobs talk to the same host daemon —
Dagger engine containers run as siblings, not children. Docker
Desktop's `daemon.json` carries the [[zot]] registry mirror
(`http://host.docker.internal:5050`) for docker.io pulls.

There are also two independent NixOS runners on [[ringtail]]
(`services.gitea-actions-runner` in `nixos/ringtail/configuration.nix`,
both sandboxed systemd DynamicUsers sharing the instance-global
registration token):

- `ringtail-nix-builder` (`nix-container-builder` label) — the
  `build-container.yaml` nix build job.
- `ringtail-priv-runner` (`priv` label) — privileged dispatch-only
  workflows ([[warrant-approval-gated-runs]] Phase 2): argocd-deploy
  today, `provision-*` later. Deliberately NOT host-mode-as-erichblume:
  a hostile privileged job compromises a DynamicUser sandbox, not the
  forge owner's account.

## Job Execution

Host-mode ([[retire-minikube]] phase 6): workflow steps run directly as
`erichblume` on indri with the mise-managed toolchain. Dagger pipelines work
unchanged: the CLI runs on the host and its engine runs as a container
in Docker Desktop, which survives solely for this purpose (right-sized
2cpu/4GiB). The old arm64 `runner-job-image` is retired.

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
with the runner stopped. Two LaunchAgents (this role) handle the
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
  runner LaunchAgent out (its `shutdown_timeout` of 3h lets in-flight
  jobs finish), waits for the process to exit, prunes, and bootstraps
  the runner back — a `trap` restores the runner even if the prune
  fails, and a runner that fails to drain aborts the prune. Jobs
  queued during the window simply wait on forge. Log:
  `~/Library/Logs/mcquack.runner-cache-prune.{out,err}.log`.

## Credentials

| Secret | Source | Purpose |
|--------|--------|---------|
| runner UUID | 1Password ("Forgejo Secrets" → `runner_indri_uuid`) | Static runner identity for `server.connections` |
| runner token | 1Password ("Forgejo Secrets" → `runner_indri_token`) | Static runner credential for `server.connections` |
| GitHub PAT | 1Password ("Forgejo Secrets" → `forge-ci-github-pat`) | `MISE_GITHUB_TOKEN` in `runner.envs`, injected into every job |

Fetched by playbook `pre_tasks` via `op read`, rendered into the
config file (mode 0600) at provision time. Rotation = re-register
(see [[configure-launchd-runner]]) and re-provision.

The GitHub PAT exists because Forgejo injects `GITHUB_TOKEN` (a *forge*
job token) into every job, and mise honours that name for
`api.github.com` — so any GitHub-backed tool resolution takes a 401.
`MISE_GITHUB_TOKEN` outranks it in mise's lookup order (first non-empty
of `MISE_GITHUB_TOKEN`, `GITHUB_API_TOKEN`, `GITHUB_TOKEN` wins). The
token is the same zero-permission public-read PAT the mirror sync uses
— rotation and constraints in [[manage-forgejo-mirrors]]. Because
`runner.envs` is readable by every job on this runner, the no-scopes
rule is load-bearing: a credential that needs *any* scope needs its own
token and a narrower home. Note a runner-env change takes effect at
provision time, so a PAT rotation is not live for CI until the next
`provision-indri`.

## Related

- [[configure-launchd-runner]] — setup, registration, cutover
- [[forgejo]] — the forge this runner connects to
- [[zot]] — registry mirror for job image pulls
- [[build-container-image]] — how container images are built via this runner
