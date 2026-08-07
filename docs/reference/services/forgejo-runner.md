---
title: Forgejo Runner
modified: 2026-08-07
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

The toolchain the role installs is exactly `forgejo_runner_host_tools` in
`ansible/roles/forgejo_runner/defaults/main.yml` — read it there rather than
trusting a list here, which is how this card came to advertise a `jq` the role
never installed. Anything else a job needs comes from the repo's own
`mise.toml`, or from a Dagger container.

**`prek` needs company.** prek downloads the environment for most hooks, but a
`*-system` hook runs whatever is on `PATH` by definition — so `actionlint` and
`stylua` are the host's responsibility, and a missing one is reported as a
*failed* hook, not a skipped one. Adding a `*-system` hook to any repo's
`prek.toml` means adding its binary here.

## Credentials

| Secret | Source | Purpose |
|--------|--------|---------|
| runner UUID | 1Password ("Forgejo Secrets" → `runner_indri_uuid`) | Static runner identity for `server.connections` |
| runner token | 1Password ("Forgejo Secrets" → `runner_indri_token`) | Static runner credential for `server.connections` |

Fetched by playbook `pre_tasks` via `op read`, rendered into the
config file (mode 0600) at provision time. Rotation = re-register
(see [[configure-launchd-runner]]) and re-provision.

## Related

- [[configure-launchd-runner]] — setup, registration, cutover
- [[forgejo]] — the forge this runner connects to
- [[zot]] — registry mirror for job image pulls
- [[build-container-image]] — how container images are built via this runner
