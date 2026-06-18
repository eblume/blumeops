---
title: Forgejo Runner
modified: 2026-06-17
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
| **Labels** | `k8s` (compat), `indri` |
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

There is also a second, independent runner: the
`nix-container-builder` on [[ringtail]] (NixOS systemd service) used
by the `build-container.yaml` workflow (its nix build job).

## Job Execution

Host-mode ([[retire-minikube]] phase 6): workflow steps run directly as
`erichblume` on indri with the mise-managed toolchain (node, uv, yq,
jq, prek, dagger — installed by the role). Dagger pipelines work
unchanged: the CLI runs on the host and its engine runs as a container
in Docker Desktop, which survives solely for this purpose (right-sized
2cpu/4GiB). The old arm64 `runner-job-image` is retired.

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
