---
title: Configure the launchd Forgejo Runner on indri
modified: 2026-09-04
last-reviewed: 2026-09-04
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Configure the launchd Forgejo Runner on indri

Run the Forgejo Actions runner as a native macOS LaunchAgent on
[[indri]], managed by the `forgejo_runner` ansible role. Jobs run
directly on the host with indri's mise toolchain (host-mode); Docker
Desktop stays only as the [[dagger]] engine host. This replaced the
minikube-hosted runner as phase 0 of [[retire-minikube]], so source
builds no longer compete with the LGTM stack inside the minikube VM;
phase 6 then dropped the per-job container entirely.

## Architecture

- **Daemon:** the `forgejo-runner` binary, source-built from the
  mirror at `~/code/3rd/forgejo-runner`, runs as LaunchAgent
  `mcquack.eblume.forgejo-runner` (same pattern as [[forgejo]]).
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

### 1. Build the binary

```fish
ssh indri 'cd ~/code/3rd/forgejo-runner && git fetch --tags && git checkout v13.1.0 && mise x go@1.26.5 -- env GOTOOLCHAIN=local make build'
```

> **Use the explicit `mise x go@…` form.** The checkout's untracked
> `mise.toml` pins whatever go it was created with, and mise hard-sets
> `GOROOT`, which defeats `GOTOOLCHAIN=auto`: when the tag's `go.mod` asks
> for a newer toolchain, a plain `make build` dies with
> `compile: version "goX" does not match go tool version "goY"` (bit us on
> the v12 → v13 bump, which raised the floor to go 1.26). Same mechanism as
> [[upgrade-forgejo#Go toolchain pin]]; the version comes from the role's
> `forgejo_runner_go_version`, bump it whenever a tag raises its floor.

The role verifies the binary exists and that `--version` matches its
pinned `forgejo_runner_version`, and fails with these instructions
otherwise. Version bumps = check out the new tag, rebuild, bump the
role default (and `forgejo_runner_go_version` if the floor moved), then
**restart the LaunchAgent by hand** — a version-only bump changes no
template, so `provision-indri` verifies the new binary but its restart
handler never fires and the old daemon keeps running:

```fish
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.eblume.forgejo-runner.plist; launchctl load ~/Library/LaunchAgents/mcquack.eblume.forgejo-runner.plist'
ssh indri 'tail -3 ~/Library/Logs/mcquack.forgejo-runner.err.log'   # "with version: vX.Y.Z … declared successfully"
```

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
