---
title: Configure the launchd Forgejo Runner on indri
modified: 2026-09-19
last-reviewed: 2026-09-04
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Configure the launchd Forgejo Runner on indri

Run the Forgejo Actions runner as a native macOS LaunchAgent on
[[indri]] — the unit is nix-managed (the [[indri]] flake) and the
config is rendered by the `forgejo_runner` ansible role. Jobs run
directly on the host with indri's mise toolchain (host-mode); Docker
Desktop stays only as the dagger engine host (the runner keeps dagger for the hephaestus/cv CI it hosts). This replaced the
minikube-hosted runner as phase 0 of [[retire-minikube]], so source
builds no longer compete with the LGTM stack inside the minikube VM;
phase 6 then dropped the per-job container entirely.

## Architecture

- **Daemon:** the nixpkgs `forgejo-runner` binary (13.1.0, the [[indri]]
  flake's nixpkgs pin) runs as the nix-managed LaunchAgent
  `mcquack.eblume.forgejo-runner` (same pattern as [[forgejo]]); the
  source checkout at `~/code/3rd/forgejo-runner` is the rollback
  re-write's target only.
- **Jobs:** run directly on the host as `erichblume` with indri's
  mise toolchain (labels are registered `:host`) — no per-job
  container and no `runner-job-image` (phase 6). Docker Desktop stays
  (right-sized 2cpu/4GiB) solely as the Dagger engine host; the host
  `dagger`/`docker` CLIs reach its daemon at the default
  `/var/run/docker.sock` — the role the privileged DinD sidecar used
  to play.
- **Labels:** advertises `indri` (the honest name) only. Originally
  also advertised `k8s` for compatibility with existing workflows;
  once blumeops workflows migrated to `runs-on: indri` the `k8s`
  label was dropped from `forgejo_runner_labels` (see
  [[forgejo-runner]]). Other forge repos still on `runs-on: k8s`
  will need to migrate before the label can be dropped there too.
- **Registry mirror:** Docker Desktop's `daemon.json` gets
  `registry-mirrors: ["http://host.docker.internal:5050"]` ([[zot]]
  pull-through cache, replacing the DinD config's
  `host.minikube.internal:5050`). Mirrors only affect docker.io
  pulls (base images during builds).

## One-time setup

### 1. The binary (nix-managed — no manual step)

Since PR 7 of the indri nix-darwin series (2026-09), the runner binary
is the nixpkgs `forgejo-runner` package (13.1.0, pinned by the [[indri]]
flake's nixpkgs input), and the LaunchAgent unit is the flake's
`launchd.user.agents."mcquack.eblume.forgejo-runner"`. Version bumps are
flake PRs applied through the usual `mise run provision-indri --
--tags rebuild`; activation swaps the plist in place and restarts the
agent. The original source checkout at `~/code/3rd/forgejo-runner`
stays on disk only as the ansible rollback re-write's target (see
[[provision]] §Rolling back a service flip).

### 2. Register the runner identity

A new, distinct identity (not the k8s runner's) so both runners can
coexist during the transition and rollback stays trivial:

```fish
# secret must be exactly 40 hex chars; omit --scope for instance-wide
ssh indri 'cd ~/code/3rd/forgejo && ./forgejo forgejo-cli actions register \
  --name indri-runner \
  --secret "$(openssl rand -hex 20)" \
  --config ~/forgejo/custom/conf/app.ini --work-path ~/forgejo'
```

This prints the runner UUID; the generated secret is the token. Store
both on the "Forgejo Secrets" 1Password item as `runner_indri_uuid` /
`runner_indri_token`. The playbook `pre_tasks` fetch them with
`op read` and the role renders them into the runner config
(mode 0600).

### 3. Provision

```fish
mise run provision-indri -- --tags forgejo_runner
```

If the role changed Docker Desktop's `daemon.json` (registry mirror),
it does **not** restart Docker Desktop. Restart Docker Desktop
manually at a quiet moment; until then the mirror simply isn't active.

## Verification

- `mise run services-check` — the `forgejo-runner (indri)` launchd
  check is green.
- The runner appears as `indri-runner` (idle) under forge admin →
  Actions → Runners.
- Trigger a real workflow (the prometheus container build is the
  stress case that motivated this) and watch with
  `mise run runner-logs`.
- Logs: `~/Library/Logs/mcquack.forgejo-runner.{out,err}.log`,
  shipped to Loki by the [[alloy]] role.

## Cutover from the k8s runner (historical — completed with [[retire-minikube]])

1. Run both runners side by side; confirm several green runs on the
   launchd runner (jobs may land on either while both advertise
   `k8s`).
2. Scale the k8s runner to 0
   (`kubectl --context=minikube-indri -n forgejo-runner scale deploy/forgejo-runner --replicas=0`).
3. After a few days of clean runs: delete the `forgejo-runner` ArgoCD
   app + manifests, remove the runner from forge admin, and delete
   the `runner_k8s_uuid`/`runner_k8s_token` 1Password fields.

Rollback at any point before step 3: scale the k8s deployment back to
1 and unload the LaunchAgent.

## Related

- [[forgejo-runner]] — service reference
- [[retire-minikube]] — the umbrella migration plan
- [[validate-forgejo-workflows]] — workflow schema validation
