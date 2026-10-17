---
title: changelog
tags:
  - meta
---

# Changelog

All notable changes to BlumeOps are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## Archives

- [v1.20](docs/changelog/archive/v1.20.md)
- [v1.19](docs/changelog/archive/v1.19.md)
- [v1.18](docs/changelog/archive/v1.18.md)
- [v1.17](docs/changelog/archive/v1.17.md)
- [v1.16](docs/changelog/archive/v1.16.md)
- [v1.15](docs/changelog/archive/v1.15.md)
- [v1.14](docs/changelog/archive/v1.14.md)
- [v1.13](docs/changelog/archive/v1.13.md)
- [v1.12](docs/changelog/archive/v1.12.md)
- [v1.11](docs/changelog/archive/v1.11.md)
- [v1.10](docs/changelog/archive/v1.10.md)
- [v1.9](docs/changelog/archive/v1.9.md)
- [v1.8](docs/changelog/archive/v1.8.md)
- [v1.7](docs/changelog/archive/v1.7.md)
- [v1.6](docs/changelog/archive/v1.6.md)
- [v1.5](docs/changelog/archive/v1.5.md)
- [v1.4](docs/changelog/archive/v1.4.md)
- [v1.3](docs/changelog/archive/v1.3.md)
- [v1.2](docs/changelog/archive/v1.2.md)
- [v1.1](docs/changelog/archive/v1.1.md)
- [v1.0](docs/changelog/archive/v1.0.md)
- [v0.1](docs/changelog/archive/v0.1.md)

<!-- towncrier release notes start -->

## [v1.21.0] - 2026-10-17

The first blumeops release under the release-PR model: prepared with the shared release kit's `cut-release`, reviewed and merged like any other PR — the merge cuts the tag and publishes this release. The `Build BlumeOps` dispatch flow is retired with it, and with it the main-push PAT arrangements that supported it: no workflow in this repo pushes to `main` anymore.

Since v1.20.3 the work concentrated on the fleet's trust boundary. The `cli-agent` fork-model principal for interactive CLI agent sessions is live (read grants, `forge-reconcile`-reconciled principals, talos's human-proxy setting), the forge bot was renamed `talos` and gained fail-safe PAT rotation, branch protections are declared for the seven write/canonical repos, and `forge-reconcile` now models tag protections and drifts on the release-kit writer invariant. The hosts moved deeper into their declarative shapes: indri's forge runners (both of them) are rendered by the nix-darwin generation and Remote Login is enabled, ringtail's deploy path is the push-to-main auto-apply with the human-local break-glass apply documented, and heph runs from the nix-store package on the hub and every spoke. Also in: the authentik principals reconcile with its retiring queue, declared ntfy topics, the forgejo mirror guard, horkos's late-asset release recovery, and the monthly dependency refresh.

### Bug Fixes

- `forge-bot-pat-rotate` retains the `horkos-forge-read` token on the bot user instead of counting it as an incumbent or revoking it.

### Infrastructure

- Onboard eblume/release-kit (the shared release-PR implementation from eblume/blumeops#1628) to the fleet as read/fork: every repo's release runs code from that repo, so its tag is a supply-chain choke point and the agents bot gets read-only access instead of the freestanding write default, with main protected (push and merge whitelisted to eblume, CI / test required).
- The talos deployment sets TALOS_HUMAN_PROXY_PRINCIPALS="cli-agent", so the cli-agent principal's issue/PR input is accepted by talos as human input equivalent to eblume's (eblume/blumeops#1583; the trusted-actor gate code is eblume/talos#350, deployed via the v0.4.223 pin PR #1710).
- Declared the `cli-agent` principal in repos.json (P3 of eblume/blumeops#1583): listed in the top-level `principals` set with `read` on every repo of the talos pool — the Forge Reconcile apply on main grants them now that the forge user exists (HC1 done 2026-10-15). Read-only on this axis; `write` is refused at load time.
- `forge-reconcile` now reconciles a declared set of read-only fork-model principals: a top-level `principals` list in repos.json declares the set (every listed user is reconciled against every repo, so removing a principal's last per-repo entry revokes its live grant instead of forgetting it, and a one-step removal of a granted principal from the list fails the PR check), per-repo `principals` entries grant `read` on named repos, and write is refused at load time — the axis the `cli-agent` principal lands on.
- `forge-reconcile` now models tag protections (Forgejo 16) declaratively from `forge/tag-protections.json`: load-time validation (exact fields, duplicate refusal, the bot whitelist fence), create/update/delete with read-back, and drift reporting in `--check` and the PR check. No rule is seeded yet — the `release-kit` `v*` rule arrives in a follow-up (Part of [#1661](https://forge.ops.eblu.me/eblume/blumeops/issues/1661)).
- The `forgejo_runner` role now strips host-only credential helpers (`credsStore`/`credHelpers`) from the indri-build runner's docker client config on the macOS host. A Docker-Desktop-era `credsStore: osxkeychain` (left over from before the colima migration, eblume/blumeops#1382) was breaking every uncached image pull on the build runner: the host's dagger CLI reads that config for buildkit's session-auth credential callback, and the keychain helper is no longer installed on the host.
- The fly git-mirror's dumb-HTTP metadata (`info/refs`, pack index) is kept
  fresh entirely by a non-fatal, logged `post-receive` (failures to
  `/volume/git-mirror/hooks.log`) whose final `update-server-info` runs
  after the repack, with an EXIT-trap backstop — a failing cosmetic hook
  step can no longer serve stale refs (eblume/blumeops#1640).
- Reconcile indri's `[tools]` `flyctl` pin with `mise.toml` (`0.4.87` → `0.4.118`, both blocks in `darwin/indri/configuration.nix`) and reword the forgejo-runner note in `service-versions.yaml`: prek stays at the fleet environment default (talos image `prekVersion`, chezmoi, indri — bumped in lockstep), while blumeops's `mise.toml` pin is a deliberate repo-level override, not a mirror source (eblume/blumeops#1715).
- `forge-reconcile` `--check` now drifts on the release-kit tag invariant — any write-or-above collaborator other than eblume, any write deploy key — instead of a tag-protection rule the release workflow can't satisfy (the kit's own release creates tags as `forgejo-actions`, id -2, which Forgejo v16 tag-protection whitelists can't resolve; [#1661](https://forge.ops.eblu.me/eblume/blumeops/issues/1661)).
- Adopted the release-PR model for blumeops releases: merging a `release vX.Y.Z` PR tags and publishes via `eblume/release-kit@v0.1.1`; the `Build BlumeOps` dispatch workflow is retired.
- The ringtail agent heph spoke now runs the nix-store heph package built by the hephaestus release flake (the `hephaestus` input in nixos/ringtail/flake.nix, pinned to the v1.10.7 tag) instead of the `cargo install` oneshot: heph compiles into the toplevel (covered by ringtail-flake-check CI, whose job timeout was raised to 90 minutes for the cold compile), the install oneshot/timer/path unit are gone, and the spoke starts at boot like any other service. Erich's desktop spoke still installs from `hephTag` (the flake input pin replaces `hephTag` for the agent spoke only). Part of [eblume/blumeops#1541](https://forge.ops.eblu.me/eblume/blumeops/issues/1541).
- indri: the nix-darwin generation now renders the build runner's `config.yaml` (from `forge/runners.json` plus the seed-secrets identity files, registration-gated, kickstart on change) and installs its colima profile (double-install with the `.applied` drift baseline, `colima stop` on change), plus the docker client config repair. The build runner's identity files are declared in `darwin/indri/secrets.json` and seated root-owned under `/usr/local/etc/forgejo-runner-build/identity/` (outside the build home, so `seed-secrets` never root-writes into the attacker-controlled home). Part of eblume/blumeops#1627.
- The indri Forgejo collector now labels `forgejo_ci_queue_wait_seconds` and `forgejo_ci_job_duration_seconds` by repo, workflow, job and runner label, so per-workflow queue waits and job runtimes are a single PromQL query. Combo counts stay cumulative, but a combo with no task in the last 30 days stops being exported, so retired matrix legs don't grow the series set forever.
- The ringtail eblume desktop heph spoke now runs the same nix-store heph package as the agent spoke (the `hephaestus` flake input, v1.10.7) instead of the `cargo install` oneshot — the `eblume-heph-install` oneshot/timer, the spoke's path unit, `hephTag`, and the install machinery in `heph-common.nix` are gone, the session shims and sway popover launcher re-point at the store bin dir, and the hand-built pre-v1.8.0 `~/.cargo/bin/heph-quickadd` drift is rendered inert (the leftover `~/.cargo/bin` heph binaries stay on disk until the step-6 cleanup removes them); part of [eblume/blumeops#1541](https://forge.ops.eblu.me/eblume/blumeops/issues/1541).
- Remove the temporary `e2e-proof` label from indri-runner now that the e2e proof of the nix runner-config apply landed (#1528).
- New `mise run forge-bot-pat-rotate` task + how-to: fail-safe rotation of the talos Forgejo bot PAT (mint → prove → vault write → pod roll → revoke), the automated half of the #1656 scheduled-rotation design.
- A launchd guard on indri (`mcquack-forgejo-mirror-guard`) alerts on `ops-approvals` and exports 0/1 textfile metrics when a forge push-mirror remote carries a fetch refspec targeting `refs/heads/*`, or when the newest `main` reflog entry on any bare repo is not a fast-forward.
- Clear the dead `unprotected_file_patterns` changelog carve-out on `eblume/hephaestus`'s `main` branch protection — the retired `MAIN_PUSH_TOKEN` flow was its only consumer — and record in the forgejo secrets docs that the live secret was deleted by the 2026-10-15 reconcile apply and the `hephaestus-main-push-token` PAT revoked the same day.
- The heph hub on indri now runs from the nix-store: the darwin/indri flake pins the `hephaestus` flake (v1.10.9, `cli` output) and the generation owns the `mcquack.eblume.heph` user agent - a static wrapper execs the store `hephd` with the seeded authorized-sub file (hephd takes the flag argv-only). The role's daemon legs sit behind the `heph_ansible_managed` gate (default false) for the rollback window; the PWA checkout and stamp stay role-managed.
- Lint runs the hook set in changed-file mode on PRs (`prek run --from-ref`), falling back to `--all-files` for delete-only and hook-config diffs, keeping `--all-files` on main, and ansible-lint now runs once over the whole `ansible/` tree instead of in per-file batches.
- darwin/indri/secrets.json declares the two metrics-collector API keys (the forgejo token and the jellyfin key) under `~/.config/metrics-keys/`, and `invariants.nix`'s referenced list gains the same two paths in lockstep. The entries carry no restart — the collectors re-read the files on every 60s run; the collector flip and the four metrics roles' deletion follow as PR 2 of eblume/blumeops#1700.
- Ntfy topics get a single declared-state file, `ntfy/topics.json` (purpose, producers, notification budget): `mise run ntfy-lint` (prek hook + Ntfy Lint PR check) fails on undeclared or retired topic literals in the tree and on producers not listed there; `ceramics` stays declared as retired. Part of eblume/blumeops#1611.
- The ringtail-rebuild and provision-indri auto-apply workflows resolve their refusal topic from `ntfy/topics.json` at runtime (raw fetch at `main` — the bound commit may predate the declaration, which is exactly the case being refused) instead of a hardcoded topic literal; an unresolvable topic falls back to the `ops-approvals` literal with a `::warning::` in the run log.
- The ringtail and indri apply watchers read their ntfy topic from the ntfy/topics.json declaration at nix eval time (ntfy/topics.nix); a topic change ships on the next apply of either host.
  Both flake checks (ringtail, indri) now also run on ntfy/** and forge/runners.* changes, so edits to the shared flake inputs get a build check on each host before merge.
- `forge-bot-pat-rotate` now reads the talos login item's built-in `password` field (where `op item create --generate-password` puts the value) instead of the `login-password` field name, and the migration how-to documents exactly that ref; the redundant `login-password` field on the live item is harmless and can be dropped later.
- Indri's OpenSSH (Remote Login) is now enabled declaratively by the darwin/indri flake (`services.openssh.enable` + activation-written real files for the sshd policy and erichblume's authorized keys): key-only auth, `AllowUsers erichblume`, Tailscale SSH stays on until the series' PR 4 removes it (eblume/blumeops#1484).
- `mise run reconcile-authentik-principals` reconciles live Authentik against
  the principals rosters: it lists every live account the files do not know
  about and empties the retiring queue (`--delete --apply`, with a zot
  key-revocation gate and a Grafana JIT-user sweep). `zot-apikey-rotate` now
  reads its identity table from the `credential` blocks in `principals.yaml`,
  and a new Lint hook fails when the zot accessControl template grants a group
  the roster does not declare.
- Authentik blueprint user/group/policybinding entries are now rendered from `argocd/manifests/authentik/principals.yaml` plus a `retiring.yaml` deletion queue (`mise run render-authentik-principals`; Lint fails on drift). First queue entries: `agent-ringtail`, `zot-ci`, `talos-heph-stray` (eblume/blumeops#1194).
- The `k3s-run-script` warrant identity can now roll the talos Deployment — a namespaced Role in `talos` (`argocd/manifests/talos/rbac.yaml`) grants the `run-script` SA `get`/`list`/`patch`/`watch` on the single `talos` deployment, covering `kubectl rollout restart`/`status` for the `forge-bot-pat-rotate` ceremony with no cluster-wide or other-namespace grant.
- The indri forgejo-runner's cache-sweep and cache-prune LaunchAgents move from the Ansible forgejo_runner role to the nix-darwin generation.
- Temporary `e2e-proof` label on indri-runner to prove a runners.json label change applies end to end (#1528); removed in a follow-up.
- The main forgejo runner's `config.yaml` on indri is now rendered by the nix-darwin generation from `forge/runners.json`, and the runner is kicked only on a content change.
- `seed-secrets` can now seed the darwin host: a non-empty `darwin/indri/secrets.json` runs through the same write + mandatory read-back as ringtail, and `restart` entries are launchd labels kicked with `launchctl kickstart -k gui/<uid>/<label>` (uid resolved from the entry owner, which must be non-root) and confirmed from `launchctl print` output. Part of eblume/blumeops#1528.
- Declared `main` branch protections for the seven write/canonical repos (hephaestus.nvim, project-template, RexWorks, myeve, gamedev, research, timberborn-parsimony): no bot merge-removal, required CI check where the repo has one, rejected-review and outdated-branch blocking. Retired the two main-push PAT arrangements — hephaestus's `MAIN_PUSH_TOKEN` (secret declaration and 1Password source removed; the live secret is deleted on the next `forge-reconcile` apply) and blumeops's own changelog/docs_version push to main in `build-blumeops.yaml` (the release job hard-fails until the release-PR model replaces it — blumeops releases paused) — and cleared `protected_file_patterns: "*"` on blumeops and release-kit, where Forgejo's glob semantics (`*` matches only extensionless root files) made the pattern block any release PR bumping the root `version` file — per the release-PR model ([eblume/blumeops#1628](https://forge.ops.eblu.me/eblume/blumeops/issues/1628)).
- The pre-switch cargo-installed heph binaries are cleaned up on ringtail: a `heph-cargo-bin-cleanup` one-shot removes `heph`, `hephd`, `heph-tui`, and `heph-quickadd` from the agent and eblume users' `~/.cargo/bin` at each boot (a no-op once gone), so no shell can shadow the nix-store heph bins anymore; the heph docs drop their last references to the retired install oneshot (part of [eblume/blumeops#1541](https://forge.ops.eblu.me/eblume/blumeops/issues/1541)).
- Grafana: new talos event-loop alert (main thread blocked >20% of the trailing 15m, sustained 5m, outside the first 15m after a pod start) and a blocked-wall-time panel on the Talos dashboard, closing the guard half of [eblume/talos#345](https://forge.ops.eblu.me/eblume/talos/issues/345).
- `forge-reconcile` now reports live branch-protection rules not declared in `forge/branch-protections.json` as drift (weekly `--check`, PR check) and deletes them on a human apply, so branch protections on `eblume/*` are IaC-only.
- Warrant-gated CI half of the talos Forgejo bot PAT rotation: dispatch-only priv workflow `forge-bot-pat-rotate.yaml` (bound SHA, runs `mise-tasks/forge-bot-pat-rotate --ci`), its `warrant-policy.yaml` entry, and the new `FORGE_PAT_ROTATE_OP_TOKEN` Actions secret (agents-vault service account) declared in `forge/actions-secrets.json` + `forge-reconcile`.
- release-targets.json: the eblume/cv artifact target gains release_workflow (cv-release.yaml), enabling late-asset recovery (eblume/horkos#62); horkos.md's Release publishing section documents the asset flow and corrects the deployed-version references.
- release-targets.json gains the per-target release_workflow field enabling late-image recovery (eblume/horkos#59): set to the source repo's release workflow file name for the eblume/horkos and eblume/talos image targets.
- Rename the Forgejo bot `agents` → `talos` in declared state: the `repos.json` `collaborator`, the talos deployment env (`TALOS_FORGE_BOT` + git-author identity), and the `talos-forgejo-token` 1Password item the mise tasks read.
- horkos v0.5.41: auto-release from eblume/horkos `6d6bda1` — image pin bumped to `v0.5.41-6d6bda1-nix`.
- horkos v0.5.42: auto-release from eblume/horkos `30493d5` — image pin bumped to `v0.5.42-30493d5-nix`.
- horkos v0.5.44: auto-release from eblume/horkos `c02cc7f` — image pin bumped to `v0.5.44-c02cc7f-nix`.
- blumeops-pg (the CloudNativePG operand) is bumped from PostgreSQL 18.4 to 18.6 (argocd/manifests/databases-ringtail/blumeops-pg.yaml): an in-place minor upgrade (no dump/restore, no pg_upgrade), where 18.6 (released 2026-08-13) is the cumulative fix set from 18.4 — 18.5 was never shipped — fixing 28 CVEs.
- Split the ringtail flake's frozen nixpkgs pin: forgejo-runner now comes from a new `nixpkgs-runner` input (13.2.0) while snowflake, k3s, and kubectl stay on the unchanged `nixpkgs-services` rev.
- Monthly dependency refresh: ruff v0.16.8 -> v0.17.1 and mirrors-prettier v3.9.7 -> v3.9.10 (prek hook revs), plus mise, uv, and PEP 723 pin bumps.
  service-versions.yaml synced; Fly proxy digests moved (nginx 1.30.6-alpine, tailscale v1.104.1, alloy v1.20.1, anubis v1.28.1) and take effect on the next deploy-fly.
- talos v0.4.214: auto-release from eblume/talos `dc26b03` — image pin bumped to `v0.4.214-dc26b03-nix`.
- talos v0.4.215: auto-release from eblume/talos `de5c432` — image pin bumped to `v0.4.215-de5c432-nix`.
- talos v0.4.216: auto-release from eblume/talos `069faf8` — image pin bumped to `v0.4.216-069faf8-nix`.
- talos v0.4.217: auto-release from eblume/talos `84cca7b` — image pin bumped to `v0.4.217-84cca7b-nix`.
- talos v0.4.218: auto-release from eblume/talos `506954f` — image pin bumped to `v0.4.218-506954f-nix`.
- talos v0.4.220: auto-release from eblume/talos `8331e9c` — image pin bumped to `v0.4.220-8331e9c-nix`.
- talos v0.4.223: auto-release from eblume/talos `541091e` — image pin bumped to `v0.4.223-541091e-nix`.
- Protected `main` branches now require one approval from eblume at the current head, so a scheduled merge can no longer land commits pushed after it was scheduled.
- Protected `main` rules no longer apply to admins, so eblume can "merge anyway" his own PRs (which he cannot approve); scheduled merges stay fully enforced.

### Documentation

- The ArgoCD card documents why a "Synced" app can still carry keys its manifests no longer declare — a bootstrap `kubectl`-owned `argocd-cm` account key plus orphaned `argocd-secret` API-token records owned by `argocd-server`, which nothing garbage-collects (the stale `workflow-bot` account left by the #1039 principals sweep) — and the principals reference points at it for account sweeps.
- Add the reference doc for the `cli-agent` Forgejo principal — the
  fork-model identity for interactive CLI agent sessions (Claude Code, Codex),
  second instance of the talos-bot pattern: read-only on canonical, own fork,
  cross-repo PRs, no CI trust, consent fence, and the biometric-gated
  credential layout (eblume/blumeops#1583, P1).
- Doc review of the `deploy-prowler` card (#1696): corrected the check counts to the v5.39.1 reality (82 CIS-mapped of 93 shipped; Apiserver 28), recorded the 5.39.1 self-pinned nixos-unstable rev, and reduced the card to current facts (history lives in the commit history).
- TeslaMate service doc reviewed and updated: ArgoCD app and kustomization paths now point at `teslamate-ringtail`, database location and Grafana dashboard sourcing noted.
- The principals reference ([[principals]]) consolidates the naming scheme, the live inventory of every non-human principal, and the `FORGE_REPO_WRITE_TOKEN` exception (the old `agents-forgejo-bot` card is renamed and expanded). Grandfathered principal names are purged from docs, manifests, and `horkos-forge-provision` (blumeops#1039 step 7). The `blumeops-ci/horkos-dispatch` mirror item keeps its artifact name by ruling; the pointer to `horkos-forge` lives in the item's notes.
- Docs no longer claim the Forgejo bot's SSH key is deployed to ringtail or rotatable: the key was retired in Oct 2026, the bot authenticates over HTTPS with its Forgejo token, and no SSH key is seated on the host. Part of eblume/blumeops#1635.
- Document the human-local break-glass ringtail apply (`ringtail-apply@<sha>`) in the disaster-recovery rebuild walkthrough, replacing the rebuild row's `provision-ringtail` reference (retired for the rebuild path by this #1527 series); the `ringtail-apply` no-checkout error message now points at the one-time blumeops clone instead.
- The ArgoCD bootstrap runbook gains the 1Password Connect bootstrap (namespace + `op-credentials`/`onepassword-token` via `op inject`) as step 7, and the `1password-connect-ringtail` app's prerequisite now points at that runbook step instead of the ansible play.
- The hephaestus version-management pin table now records the talos pod image as a pin site — the `hephaestus` flake input in `eblume/talos:flake.nix`, bumped as a PR on the talos repo through its auto-release.
- Document the accepted risk of a single-provider offsite photos copy (B2 + Object Lock second copy dropped) in [[backups]], noting the restore-test cadence is load-bearing for the acceptance (eblume/blumeops#1417 wrap-up).
- Docs: refresh the Prometheus service card — fix the manifest path
  (prometheus → prometheus-ringtail), the PVC size (50Gi → 20Gi), the scrape
  target table (now 9 jobs; the tailscale CNPG hostname and the dropped
  kube-state-metrics entry are gone), add the alloy-ringtail remote-write
  source, and add forgejo to the textfile metrics list. Last-reviewed stamp
  moved to 2026-10-15.
- Retire `ansible/playbooks/ringtail.yml`, the `provision-ringtail` mise task, and the task's `class: deny` warrant-policy entry: the ringtail deploy path is now `mise run seed-secrets ringtail` for on-host secret files, the `ringtail-rebuild.yaml` auto-apply of merged blumeops PRs (via the detached `ringtail-apply@<sha>` unit), and the ArgoCD bootstrap runbook — with the human-local break-glass apply documented in the disaster-recovery doc. Doc references swept to the new path. Part of eblume/blumeops#1527.
- The forgejo-runner docs (`configure-launchd-runner.md`, `forgejo-runner.md`, `update-documentation.md`) now describe the nix shape: the main runner's config and the cache maintenance agents are generation-owned, the `forgejo_runner` ansible role holds only the indri-build half (config + colima profile), and the Indri Flake Check is the main side's pre-apply check replacing the role's old `--check --diff`. `provision.md` §Rolling back a service flip names the cache agents as the rollback exception (dropping a pre-#1667 generation unloads them and nothing re-writes them). Part of eblume/blumeops#1528.
- Document that the cli-agent PR-authoring PAT also carries `read:user` (needed by `GET /user` and `tea login`) alongside `write:repository` + `write:issue`, matching the HC2-minted token, id 31 (eblume/blumeops#1583).
