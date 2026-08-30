---
title: changelog
tags:
  - meta
---

# Changelog

All notable changes to BlumeOps are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<!-- towncrier release notes start -->

## [v1.20.1] - 2026-08-30

### Features

- One-off script execution: `run-script.yaml` warrant workflow executes an approved script on the priv runner and records the full run in Horkos; `request-run` gains `--script`.
- Transmission RPC now requires authentication (credentials in 1Password via
  external-secrets), closing the open-RPC finding from the 2026-07 DMCA
  investigation. The kiwix torrent-sync sidecar and Prometheus exporter
  authenticate with the same secret, and the homepage Transmission widget is
  enabled now that credentials exist.

### Bug Fixes

- Fix `INJECT_FACTS_AS_VARS` deprecation warnings in Ansible runs by reading `ansible_env.HOME` via `ansible_facts` in the borgmatic and jellyfin roles.
- Fixed `mise run agent-repo-access` (and `warrant-bot-drift`) failing to parse: the `#USAGE` flag help strings contained a `\$` escape, which KDL quoted strings don't allow, so mise warned and dropped the flag definitions. The help text now references `$FORGE_REPO_WRITE_TOKEN` plainly (eblume/blumeops#725).
- The `jellyfin` Ansible role (indri) now detaches stray DMG mounts by image
  path instead of a fixed list of guessed mountpoints, removes a stale
  mountpoint directory before attaching, stops passing `-quiet` to
  `hdiutil attach` so mount failures log the actual error, and asserts the app
  bundle is visible at the pinned mountpoint before copying.
- The jellyfin role checked `jellyfin_binary_stat.exists`, but recent ansible-core releases no longer expose the stat module's flattened top-level result keys, so `provision-indri` failed with "object of type 'dict' has no attribute 'exists'". The role now uses the nested `jellyfin_binary_stat.stat.exists` form, matching the other roles.
- forgejo: allow webhook deliveries to `*.ops.eblu.me` (`webhook.ALLOWED_HOST_LIST`) — the default `external` denied the talos PR-label webhook target on the tailnet.
- In-cluster HTTPS clients now name the forge `forge.ops.eblu.me` instead of `forge.eblu.me`. The CoreDNS rewrite that makes ArgoCD's webhook matching work (eblume/blumeops#701) points `forge.eblu.me` at indri for every pod — correct for ArgoCD's `ssh://…:2222` traffic, which carries no SNI, but fatal for HTTPS: the connection reaches Caddy while the client still presents SNI `forge.eblu.me`, and Caddy has no certificate for that name, so the handshake fails with a TLS alert. Horkos re-checks `warrant-policy.yaml` on main immediately before dispatching, so the failed fetch made approving a request mint a warrant and then silently dispatch nothing; the homepage Forgejo widget was failing the same way. Horkos now sets `HORKOS_FORGE_API` and the widget its `url`.
- Fixed the Jellyfin release install failing with `hdiutil: attach failed - Resource busy`. The cleanup task detached the DMG by image path, which `hdiutil detach` does not accept, so a mount left by an interrupted run was never cleared and every subsequent run collided with it. Detaching now resolves the image's device nodes from `hdiutil info -plist`, which finds the attachment wherever it landed.
- `run-script.yaml` now always files a run record, and no longer depends on the exec bit. Two defects surfaced on the first real warranted run (1749). The step that runs the approved script documented "`-e` off: the script's exit code is data, not a step abort" but only ran `set -uo pipefail`, which does not clear the `-e` the runner already applied via `bash -e {0}` — so a failing script aborted the step before `.run/exit` was written, and the report step then died in `jq` with nothing to file. A failed script is precisely the case the audit trail exists for, so it must not be the case that loses the record; the executor now sets `set +e` explicitly and the report step defaults missing values (`exit_code: -1`) rather than exiting. Separately, the script was invoked as `./.run/script`, which returned 126 (cannot execute) on the priv runner; the interpreter is now taken from the shebang and invoked by name through `PATH`, which sidesteps the exec bit and suits NixOS, where the absolute paths shebangs name mostly do not exist.
- Fixed `build-container.yaml` pushes of large images: the nix-container-builder
  runner's sandbox (`DynamicUser` → `PrivateTmp`) mounts /var/tmp as a ~3.2G
  tmpfs, and skopeo staged the whole docker-archive there — big images failed
  with `short write` (runs 1659/1662, prowler 5.39.1). skopeo now uses
  `--tmpdir` pointed at the disk-backed job workspace.
- `mise run request-run` crashed on gilbert ("Cannot open a client instance
  more than once"): `_ops_client()`'s healthz probe implicitly opened the
  client it returned, so the caller's `with` failed on `__enter__`. Only the
  direct route hit it — in the pod the probe fails and the SOCKS fallback
  client is returned unopened, which is why agent sessions never saw it. The
  probe now uses a throwaway client.
- Fixed `mise run verify-runs` crashing with "Cannot open a client instance
  more than once" when run from gilbert — same probe-opens-the-returned-client
  bug fixed in `request-run` (b92042d3); `_ops_client()` now probes with a
  throwaway client.
- Fixed the borgmatic k8s sqlite dump helper to stream and clean up the staged
  backup via `python3` instead of `cat`/`rm` — the horkos image ships no
  coreutils, so the nightly dump produced a 0-byte file and aborted the whole
  backup run. Also corrected `ansible_facts.ansible_env` → `ansible_facts.env`
  (borgmatic + jellyfin roles), which broke provisioning after the injected-facts
  deprecation cleanup.
- The transmission blackbox probe now expects 401 (RPC auth is required as of
  PR #661) — clearing the ServiceProbeFailure alert the auth rollout tripped,
  and doubling as an alert if auth is ever accidentally disabled.

### Infrastructure

- talos webhook hooks on every pooled repo now subscribe to the `issues`
  umbrella event (issue creation/assign/label/milestone/comment deliveries, not
  just assign/label/comment) and the `agent-repo-access` reconcile now also
  creates a `no-agents` suppression label alongside the `agents` engagement
  label — the hook + label half of auto-kicking talos cycles off issues I create
  ([eblume/blumeops#725](https://forge.eblu.me/eblume/blumeops/issues/725);
  the receiver half ships in [eblume/talos#63](https://forge.eblu.me/eblume/talos/pulls/63)).
- `agent-repo-access` now reconciles the `agents` engagement label onto every
  pool repo (create-if-missing), alongside the collaborator grant and the talos
  webhook. The label is the only UI path for engaging talos on issues in the
  read-only repos (the assignee dropdown excludes read-only collaborators), and
  it only existed on blumeops — which is why `horkos#4` never spawned a session
  despite a fully working webhook. Label API calls need Forgejo's issue scope,
  which the narrow CI PAT lacks, so the label half falls back to the
  blumeops-vault api-token locally and skips with a loud warning in CI.
- Ringtail heph install oneshots now restart their spoke daemon after the
  pinned heph tag changes, so a spoke no longer runs a stale binary (and 400s
  against a newer hub) until someone restarts it by hand.
- Jellyfin on indri no longer comes from the Homebrew cask. The Ansible role pins the official v10.11.11 release DMG (sha256-verified) from repo.jellyfin.org, deploys it to ~/opt/jellyfin-<version>/, strips quarantine, and uninstalls the cask — version bumps are now blumeops PRs followed by a provision run, so brew can no longer sneak updates in.
- Ollama: shelved the 128K-context local-model evaluation after ollama
  silently capped the effective context at 4K tokens on the 16GiB card
  (eblume/talos#64). Reverted the evaluation config: the Qwen3.8-27B
  UD-IQ3_S pull entry and the q4_0 KV cache setting. The service stays
  scaled to 0 by default; the `ollama-up` / `ollama-down` tasks, the
  case-insensitive model sync fix, and the 0.32.14 version bookkeeping are
  kept. The local execution choice is moving to a dedicated host (Mac
  Studio M5 Ultra); ringtail is being upgraded for stability, not LLM
  serving.
- borgmatic now backs up the paperless-ngx document library (the sifaka NFS media PVC — originals, archived, thumbnails) via in-pod tar. The paperless image gains gnutar for the in-pod tar, and the k8s tar dump helper accepts an optional container for multi-container pods. The paperless PostgreSQL database was already covered by the pg_dump stream.
- Add `TALOS_ADMINS` (Erich's operator identity) to the talos deployment so the
  emergency stop (eblume/talos#38) can be released after being armed — the
  release path is admin-gated and fails closed without this.
- borgmatic now backs up the talos data dir (all session transcripts + meta/crons/settings) via in-pod tar, and the horkos approval-queue SQLite DB via the k8s sqlite dump helper.
- A Forgejo push webhook now drives ArgoCD, so a merge to `main` reaches the cluster in seconds instead of waiting out the reconciliation interval (up to ~3 minutes). ArgoCD matches a push to its Applications by comparing the payload's `repository.html_url` host against `spec.source.repoURL` — literally — so the blumeops Applications now name the forge `forge.eblu.me`, the host Forgejo's `ROOT_URL` puts in the payload, and a CoreDNS rewrite shipped with ringtail's NixOS config keeps that name resolving to indri over the tailnet rather than out through the Fly proxy. The rewrite lives with the node rather than in an ArgoCD app because ArgoCD needs it to fetch the repo that would otherwise contain it. (eblume/blumeops#701)
- The warrant-bot PAT is down from three independently-rotating copies to two, and the remaining mirror is maintained by tooling rather than by hand. `RELEASE_FORGE_TOKEN` was a copy of `op://blumeops/warrant-dispatch-token/token` held as an Actions secret in both eblume/talos and eblume/horkos; adding `blumeops-ci/horkos-dispatch` for the run-script executor made a third. Both release workflows now read the vault at job time (eblume/talos#55, eblume/horkos#9), leaving the canonical copy in `blumeops` — where 1Password Connect can reach it for the horkos pod — and the CI-readable mirror in `blumeops-ci`. Two vaults are unavoidable because the readers sit on opposite sides of a fence neither can cross, so `mise run warrant-bot-provision` now writes the mirror on every run, not just on `--rotate`, which makes that task the drift check as well. Delete the two `RELEASE_FORGE_TOKEN` Actions secrets only after those PRs merge.
- CI no longer holds the eblume admin PAT: `agent-repo-access` and
  `warrant-bot-drift` now use `FORGE_REPO_WRITE_TOKEN`, a `write:repository,read:user`-scoped
  eblume PAT (1Password `forge-repo-write-token`), replacing `FORGE_ADMIN_TOKEN`.
  Empirical test showed collaborator management and branch-protection reads need
  repo-admin *permission* (which eblume has as owner) but only the repository
  token *scope* — the old "write:repository 403s" note was wrong, and is retired
  from the workflow and script comments.
- ringtail: mise now installs prebuilt runtimes (python-build-standalone, node) that run through nix-ld instead of compiling them. Compiled builds baked `/nix/store` RUNPATHs that a later rebuild + GC removed, breaking every `uv run` mise task with `ImportError: libz.so.1` for months; the `CFLAGS`/`LDFLAGS`/`PKG_CONFIG_PATH` session variables that supported compiling are gone. After the rebuild, open a new shell and `mise install -f python@<ver> node@<ver>` once. `SSL_CERT_FILE` is now set system-wide so the bundled-OpenSSL python trusts the NixOS CA bundle.
- talos: wire TALOS_FORGE_WEBHOOK_SECRET via ExternalSecret (1Password item "talos forge webhook (blumeops)") so the Forgejo PR-label webhook (POST /api/webhooks/forge) can be HMAC-gated.
- `mise run agent-repo-access` now reconciles the forge→talos webhook onto
  every pool repo in repos.json alongside the collaborator grants: all 11 pool
  repos get the full trigger set (`issue_assign`, `issue_label`,
  `issue_comment`, plus the PR-review events), with stale hooks removed when a
  repo leaves the pool. `issue_label` is new fleet-wide — groundwork for
  label-driven issue engagement, since Forgejo's assignee dropdown refuses the
  read-only `agents` collaborator (the API allows it; the UI does not). Also
  documents the Forgejo hook-API asymmetry: writes take `pull_request_review`,
  reads report the expanded `pull_request_review_*` trio — sending read-names
  silently drops the review events.
- Scrape talos /metrics in alloy and add a Talos Grafana dashboard (sessions, model calls, tokens, spend).
- Rebuilt `blumeops/transmission-exporter` on current nixpkgs (python 3.14.7, prometheus-client 0.25.0, transmission-rpc 7.0.11) during the recurring service review; exporter source is unchanged since v1.0.1 and the new image tag is pinned in the `torrent-ringtail` manifest.
- Ollama: added the 12GB Qwen3.8-27B UD-IQ3_S quant (fully GPU-resident at
  128K context with q4_0 KV cache) as a declaratively pulled model, case-
  insensitive model matching in the sync sidecar for mixed-case hf.co refs,
  and `mise run ollama-up` / `mise run ollama-down` to scale the service on
  demand for evaluation windows. Part of eblume/talos#64.
- Pin paperless image to v2.20.15-737b7ae-nix (rebuilt from #672 with gnutar so the new borgmatic in-pod media tar dump works); the ArgoCD sync is the deploy.
- horkos v0.5.3: auto-release from eblume/horkos `b6f98ab` — image pin bumped to `v0.5.3-b6f98ab-nix`.
- horkos v0.5.4: auto-release from eblume/horkos `d6c9fbc` — image pin bumped to `v0.5.4-d6c9fbc-nix`.
- horkos v0.5.5: auto-release from eblume/horkos `67395cc` — image pin bumped to `v0.5.5-67395cc-nix`.
- horkos v0.5.6: auto-release from eblume/horkos `aa53039` — image pin bumped to `v0.5.6-aa53039-nix`.
- horkos v0.5.7: auto-release from eblume/horkos `cdb7ae0` — image pin bumped to `v0.5.7-cdb7ae0-nix`.
- horkos v0.5.8: auto-release from eblume/horkos `75f988c` — image pin bumped to `v0.5.8-75f988c-nix`.
- Bumped the Grafana dashboard ConfigMap watcher (kiwigrid k8s-sidecar) from
  2.6.0 to 2.10.1 in the Nix-built `blumeops/grafana-sidecar` container:
  health server now falls back to IPv4 when IPv6 is unavailable (plus a
  `HEALTH_HOST` override), LIST-mode cache cleanup is scoped per namespace,
  and `REQ_USERNAME_FILE`/`REQ_PASSWORD_FILE` env vars were added. No changes
  to the WATCH/LIST ConfigMap behaviour the deployment uses. The 2.10.1 fetch
  hash was computed and the full image built and import-smoke-tested inside
  the talos pod; the Build Container CI dispatch and the ArgoCD deploy are
  human-side.
- Bump Prowler 5.12.3 -> 5.39.1 (nixpkgs container; cis_1.11_kubernetes scan, verified against the built 5.39.1 binary).
- Daily service review: borgmatic role pin drifted to 2.1.4 (indri's actually
  installed version) while mise.toml and service-versions.yaml claimed 2.1.7.
  Bumped ansible/roles/borgmatic/defaults/main.yml to 2.1.7, the upstream
  latest. Changelog 2.1.5-2.1.7 reviewed — the only breaking change (Cronhub
  monitoring hook removal) is not used by indri's config.
- Daily service review: kiwix (kiwix-ringtail) is at upstream stable latest
  3.8.2 (published 2026-03-02, no newer tag on kiwix/kiwix-tools), so no
  version bump was needed. Deployed image v3.8.2-f386e2e-nix unchanged;
  ArgoCD app synced and healthy. Stamped last-reviewed in
  service-versions.yaml.
- Bumped forgejo-runner v12.8.2 -> v12.13.2 on indri (latest of the 12.x line; v13.0.0 carries breaking changes and is tracked as its own task), and re-aligned forgejo_runner_host_tools against their sources (dagger 0.21.8, prek 0.4.14, flyctl 0.4.87).
- Bumped dagger 0.21.8 -> 0.21.9 in mise.toml, dagger.json engineVersion, forgejo_runner_host_tools, and the tool card. Patch release: SSHFS-backed volumes added, six fixes, no breaking changes.
- talos v0.4.13: auto-release from eblume/talos `816c760` — image pin bumped to `v0.4.13-816c760-nix`.
- talos v0.4.14: auto-release from eblume/talos `0c988ae` — image pin bumped to `v0.4.14-0c988ae-nix`.
- talos v0.4.15: auto-release from eblume/talos `c6ad45f` — image pin bumped to `v0.4.15-c6ad45f-nix`.
- talos v0.4.16: auto-release from eblume/talos `d89ea0f` — image pin bumped to `v0.4.16-d89ea0f-nix`.
- talos v0.4.17: auto-release from eblume/talos `3b49724` — image pin bumped to `v0.4.17-3b49724-nix`.
- talos v0.4.18: auto-release from eblume/talos `6507702` — image pin bumped to `v0.4.18-6507702-nix`.
- talos v0.4.19: auto-release from eblume/talos `efc4693` — image pin bumped to `v0.4.19-efc4693-nix`.
- talos v0.4.20: auto-release from eblume/talos `25ea56a` — image pin bumped to `v0.4.20-25ea56a-nix`.
- talos v0.4.21: auto-release from eblume/talos `574c903` — image pin bumped to `v0.4.21-574c903-nix`.
- talos v0.4.22: auto-release from eblume/talos `16a4682` — image pin bumped to `v0.4.22-16a4682-nix`.
- talos v0.4.23: auto-release from eblume/talos `7481971` — image pin bumped to `v0.4.23-7481971-nix`.
- talos v0.4.24: auto-release from eblume/talos `a4f7fd6` — image pin bumped to `v0.4.24-a4f7fd6-nix`.
- talos v0.4.25: auto-release from eblume/talos `6118b2a` — image pin bumped to `v0.4.25-6118b2a-nix`.
- talos v0.4.26: auto-release from eblume/talos `01c8eb9` — image pin bumped to `v0.4.26-01c8eb9-nix`.
- talos v0.4.27: auto-release from eblume/talos `31c2ba7` — image pin bumped to `v0.4.27-31c2ba7-nix`.
- talos v0.4.28: auto-release from eblume/talos `adcc83e` — image pin bumped to `v0.4.28-adcc83e-nix`.
- talos v0.4.31: auto-release from eblume/talos `8c6763f` — image pin bumped to `v0.4.31-8c6763f-nix`.
- talos v0.4.32: auto-release from eblume/talos `dcc73ff` — image pin bumped to `v0.4.32-dcc73ff-nix`.
- talos v0.4.34: auto-release from eblume/talos `49b0894` — image pin bumped to `v0.4.34-49b0894-nix`.
- talos v0.4.35: auto-release from eblume/talos `e9d712c` — image pin bumped to `v0.4.35-e9d712c-nix`.
- talos v0.4.36: auto-release from eblume/talos `fb15a49` — image pin bumped to `v0.4.36-fb15a49-nix`.
- talos v0.4.37: auto-release from eblume/talos `22dfff9` — image pin bumped to `v0.4.37-22dfff9-nix`.
- talos v0.4.38: auto-release from eblume/talos `a88dd94` — image pin bumped to `v0.4.38-a88dd94-nix`.
- talos v0.4.39: auto-release from eblume/talos `4669fb7` — image pin bumped to `v0.4.39-4669fb7-nix`.
- talos v0.4.40: auto-release from eblume/talos `5964b4e` — image pin bumped to `v0.4.40-5964b4e-nix`.
- talos v0.4.41: auto-release from eblume/talos `5120e19` — image pin bumped to `v0.4.41-5120e19-nix`.
- talos v0.4.42: auto-release from eblume/talos `2d9714a` — image pin bumped to `v0.4.42-2d9714a-nix`.

### Documentation

- First review of docs/reference/services/flyio-proxy.md (was never reviewed): removed the obsolete Spider Trap Mitigation section, which pointed at the retired Quartz container's nginx depth guards (`containers/quartz/default.conf`) and its 200-URI SPA fallback — docs now ship as a static Quartz build served by Caddy on indri with a 404 fallback ([[docs-on-indri]]), so the phantom-URI trap and its guards are gone. Added a related link to docs-on-indri; stamped last-reviewed: 2026-08-28.
- First review of docs/reference/services/forgejo.md (was never reviewed):
  fixed the runner table for the Phase 2 host split — the
  `ringtail-priv-runner` (`priv` label, sandboxed DynamicUser) is the third
  runner and hosts the warrant-gated dispatch workflows; replaced the
  two-entry workflow list with the current twelve in `.forgejo/workflows/`;
  Secrets section — `runner_k8s_uuid`/`runner_k8s_token` are gone (the k8s
  runner was retired with minikube) and `runner_reg` is the instance-global
  registration token for the two ringtail runners, with per-runner identity
  secrets now linked to the forgejo-runner card; rewrote Forgejo Actions
  Secrets for the blumeops-ci item migration (the role no longer syncs
  ARGOCD_AUTH_TOKEN et al. — workflows read blumeops-ci items at job time
  with BLUMEOPS_CI_OP_TOKEN; it now syncs FORGE_REPO_WRITE_TOKEN /
  BLUMEOPS_CI_OP_TOKEN / RELEASE_FORGE_TOKEN); corrected the API-token PAT
  scope to all-scopes admin (CI carries the scoped FORGE_REPO_WRITE_TOKEN
  since 2026-08-22); restructured the Repositories table — eblume/alloy and
  eblume/tesla_auth are pull mirrors under mirrors/, not eblume repos.
  Stamped last-reviewed: 2026-08-29.
- Reviewed the Log Stream Silent runbook (never reviewed) against the alert
  rules, the alloy role, and live Prometheus metrics. Everything checked out
  except the `zot.err` "known exception" paragraph: the broken tail is fixed
  (positions wedge cleared, alloy's `loki.process` guard drops the Trivy
  progress-bar lines over 255KB) and the referenced heph audit task is done —
  the paragraph now states the current guard behavior instead.
- Reviewed and fixed the Service Probe Failure runbook: the resource-exhaustion step recommended `kubectl top`, but ringtail's k3s runs with `--disable=metrics-server` so the Metrics API does not exist; it now points at pod events and the Prometheus queries in the Pod Not Ready runbook. The sifaka NFS dependency list in the mount-check step is expanded to all seven probed NFS-dependent services (frigate, immich, kiwix, navidrome, paperless, shower, transmission).
- Reviewed and fixed the Textfile Stale runbook against the `*_metrics` ansible roles: the affected-textfiles table named the service agents (`mcquack.eblume.borgmatic`, `mcquack.eblume.zot`) instead of the metrics-writer agents (`mcquack.eblume.borgmatic-metrics`, `mcquack.eblume.zot-metrics`); `macos_power.prom`'s writer is a root LaunchDaemon, not a LaunchAgent; the "other five textfiles at 20-50s" count predates the minikube retirement (now four at 30-60s); and the log paths pointed at `~/Library/Logs/mcquack/` instead of the real `/opt/homebrew/var/log/` (daemon: `/var/log/`). Stamped last-reviewed.
- First review of docs/how-to/zot/wire-ci-registry-auth.md (was never
  reviewed): verified all claims against current repo state — the zot-ci
  artifact-workloads ["read", "create"] policy, the nix-container-builder +
  nix-build + skopeo push path in build-container.yaml, the
  BLUMEOPS_CI_OP_TOKEN job-time op read of blumeops-ci/zot-ci, the 90-day key
  expiry, and all wiki-links. No content drift; stamped last-reviewed:
  2026-08-30.
- Reviewed and refreshed the Routing card (`docs/reference/infrastructure/routing.md`), which had never been reviewed. Corrected for the minikube retirement (2026-06): the Tailscale-only section now points at ringtail's k3s (the `k8s.tail8d86e.ts.net` Minikube endpoint and port 44491 no longer exist), and the indri port map's retired 5432 PostgreSQL proxy is replaced by the 5433 (immich-pg) and 5434 (blumeops-pg) L4 proxies. The Caddy service table, previously 17 entries, now tracks the full 27-host table in `ansible/roles/caddy/defaults/main.yml` (adds pypi, heph, photos, docs, cv, nvr, authentik, ntfy, horkos, ollama, shower); the retired `pg.ops.eblu.me:5432` row moved to the port map. Added the public `shower.eblu.me` guest-surface route to the Fly proxy table.
- Horkos cutover cleanup completed: deleted the orphaned `warrant`
  namespace/PVC (DB safety-copied first), the stale Authentik `Warrant`
  provider/app, and the ghost dashboard tile; horkos doc updated to match.
- Documented that `horkos` is a fifth manual-sync ArgoCD application, and the deadlock that follows from it. The gate deliberately does not redeploy itself from a merge alone, so a merged manifest change sits undeployed until someone syncs it — and the documented route for that, `request-run argocd-deploy.yaml`, runs through horkos itself. A change that repairs horkos's dispatch therefore cannot be deployed through the warrant path: the request files, a human approves, and the dispatch fails for the same reason it was already failing. `argocd app sync horkos` from gilbert is the intended escape hatch and is now written down as one, in AGENTS.md, [[argocd]], and [[warrant-approval-gated-runs]].
- Reviewed docs/reference/tools/dagger.md (was never reviewed): updated engine version to v0.21.8 to match dagger.json and mise.toml, and removed the Secrets section — no current Dagger function takes a Secret.

### AI Assistance

- `pr-comments` now reads the full review feedback of a PR: every conversation
  comment, every review (state, body, commit), and every review comment
  grouped into threads per diff location, including follow-up posts. Each
  comment carries its file path, commit, diff position, and hunk so feedback
  pins to exact lines. Resolved threads collapse to one-line pointers by
  default (`--resolved` expands them); new `--repo` and `--json` options for
  other repos and machine polling.
- Recurring service reviews now file build/deploy warrant requests themselves
  instead of instructing the human to dispatch CI: fixed the stale
  "ask the human to dispatch" steps in `review-services.md` (written before
  Horkos request-run existed), updated the talos service-review cron prompt
  to match, and added a "file it, don't recommend it" rule to AGENTS.md
  §Privileged actions. Verified PR-branch (fork-head) SHAs are dispatchable
  pre-merge from canonical.

### Miscellaneous

- Bump pinned `pulumi` from 3.258.0 to 3.259.0 (daily service review).
- Monthly deps refresh: ruff 0.16.3 -> 0.16.4 (prek hook), Fly proxy tailscale v1.102.2 -> v1.102.3 (digest-pinned), ty 0.0.72 -> 0.0.74 and flyctl 0.4.84 -> 0.4.87 (mise pins). nginx stays at 1.30.4-alpine (latest on the 1.30 stable train; house policy tracks stable, not mainline 1.31.x). All other hook revs, PEP 723 pins and actions/checkout v7.0.1 already current.


## [v1.20.0] - 2026-08-22

### Infrastructure

- horkos v0.5.2: auto-release from eblume/horkos `ab9fdba` — image pin bumped to `v0.5.2-ab9fdba-nix`.
- talos v0.4.12: auto-release from eblume/talos `6402c2c` — image pin bumped to `v0.4.12-6402c2c-nix`.


## [v1.19.1] - 2026-08-22

### Features

- `ArgoCD Deploy` takes a `prune` input, so clearing orphaned resources is
  reachable through the approval-gated route instead of only from gilbert. Apps
  sync with `prune: false`, so the thirteen whose manifests use a kustomize
  `configMapGenerator` strand their previous hash-suffixed ConfigMap on every
  content edit; ArgoCD counts the orphan as pending-prune and the app reads
  `OutOfSync` forever, tripping `ArgoCDAppOutOfSync` on a merge that deployed
  exactly as intended. `argocd app sync --prune` is the documented fix and neither
  automated sync nor the gated workflow could run it.

  `prune` defaults to false, is refused without `sync=true` rather than silently
  no-op'ing, and logs an `--dry-run` preview of what it is about to delete before
  deleting it — this run log is the audit record. The `warrant-policy.yaml` entry
  lands in the same change, per the rule that a capability and its boundary get
  reviewed together.

  Also adds `indri` and `priv` to `.github/actionlint.yaml`. actionlint errors on
  an unrecognised `runs-on` label and that error is per-file, so their absence made
  10 of the repo's 12 workflows unlintable; all 12 now pass.
- Warrant 0.4.0 can retire an obsoleted request. `POST
  /api/requests/{id}/supersede` marks a **pending** request `superseded` and
  names its replacement, and `mise run request-run … --supersedes <id>` drives
  the whole loop: file the new request, retire the old one, note it on the old
  PR comment, close its heph tracking task. Before this, a PR that took review
  feedback left two near-identical requests in the queue with nothing to say
  which was live (warrant #21/#22 on PR #525), and the only recourse was prose
  in the new request's `--why`.

  The route only ever reduces (invariant 4): `superseded` is not `pending`, so
  no warrant can be minted and nothing can be dispatched, and it is scoped to
  the caller's own undecided requests — an agent cannot retire another
  identity's request or undo a human's decision.
- Deploy Talos at talos.ops.eblu.me — first-party agent workflow service
  (pi runtime + OpenRouter, per-session cost tracking, voice dictation)
  behind Authentik SSO with the agent-ws-parity access model. Includes the
  `forge-api` mise task (authenticated Forgejo API calls from gilbert).
- talos now trusts the shared `agents-m2m` machine identity as a second bearer
  issuer (companion talos#22), so scripts, services, and non-talos agent
  sessions can drive the talos API — e.g. create scheduled cron jobs (talos#21)
  — without a browser login. Warrant + human approval still gates every
  privileged action. Credential: `agents-m2m-app-password` (blumeops vault); no
  wrapper task, just the API.
- Talos v0.2.0 reaches agent-ws workspace equivalence: pod-start bootstrap
  with the agents bot git identity (HTTPS+token through the tag:agent
  SOCKS sidecar), the shared repos.json clone pool, and the heph + tea
  CLIs baked into the image.

### Bug Fixes

- Clear out the last references to the Homebrew-era forgejo tree, which the
  brew→source migration left behind in three places. The husk at
  `/opt/homebrew/var/forgejo` still exists on indri, frozen at 2026-04-06, so each
  of these read something plausible rather than erroring — the reason none of them
  were noisy.

  - `mirror-update-pats` queried the husk's `forgejo.db` for the mirror list and
    resolved bare repos under the husk's `forgejo-repositories`. Against a
    four-month-old snapshot it would skip any mirror added since, and rewrite
    remotes on paths that are no longer the live ones. It now reads
    `~/forgejo/data`, matching `forgejo_work_path`.
  - The alloy role tailed `/opt/homebrew/var/log/forgejo.log` for the `forgejo`
    service. The forge writes `~/Library/Logs/mcquack.forgejo.{out,err}.log` as a
    LaunchAgent, so **the forge's own log has never reached Loki since the brew
    exit.** Moved to `alloy_mcquack_logs` with both streams.
  - The backup policy doc still listed the husk as the critical forgejo source
    directory; borgmatic has backed up `~/forgejo` plus a WAL-safe `forgejo.db`
    dump since the migration.

  `mirror-update-pats` also grows a preflight check on the database path. It
  swallowed sqlite3's stderr and treated an empty result as "No GitHub mirrors
  found", so a wrong path exited 0 with a success-shaped message; since the task
  is driven by the forge-ci-github-pat rotation, that surfaces as mirrors quietly
  going stale after a rotation rather than as an error during it. The query is
  now `-readonly`, appropriate for a database forgejo is serving live.
- Fixed `mise run agent-metrics` and `mise run agent-health` crashing with `RuntimeError: Cannot open a client instance more than once` everywhere the direct network path works — which is to say, on gilbert, the primary place a human runs them. `client_for()` probed connectivity by sending a request on the very client it returned, and httpx refuses to enter a client that has already sent one; the probe is now a throwaway request. The bug was invisible from agent pods because their direct tailnet path always fails, taking the fallback branch that builds a fresh client — the scripts were only ever verified from the environment that couldn't hit the bug.
- `mise run request-run`'s ntfy approval notification now goes through the `*.ops.eblu.me` client with the tailscale sidecar SOCKS fallback, so the notification actually reaches the tailnet when the task runs from an agent pod.
- `mise run request-run` takes `--repo <owner/name>` for the repo that holds the
  PR the request attaches to (default blumeops): the request comment, the heph
  task title, and Warrant's queue and approve page now link that PR instead of a
  same-numbered, unrelated blumeops PR. Warrant stores `pr_repo` (0.4.1) and
  links the PR's diff in its own repo.
- Retire `minikube.prom`, which `TextfileStale` was still evaluating on indri two
  months after the minikube cluster itself was retired. node_exporter exports
  `node_textfile_mtime_seconds` for every `.prom` file it finds, so a collector's
  series outlives the service it measured — and with `noDataState: Alerting`, a
  retired thing ends up positioned to page about its own absence.

  The alloy role grows an `alloy_retired_collectors` list: for each entry it
  removes the `.prom` file and unloads/removes any `mcquack.eblume.*<name>*.plist`
  still writing it — plist first, since removing the file while a writer is loaded
  just gets it rewritten. Declaring the tombstone is the point; a hand `rm` on
  indri doesn't survive whichever of the two is still live.

  The runbook grows the matching instruction, since "the alert names a file that
  isn't in this table" is exactly the symptom.
- talos pod: fix nix builds colliding with the image's own store paths. The
  image's root-owned store paths were unknown to the pod's fresh store DB, so
  any substitution whose closure overlapped them failed (nix tried to
  delete-and-replace the incumbent; root ownership refused). The image now
  bakes closureInfo's registration dump of the image closure, which the
  entrypoint loads, gcrooting the toolchain; registered
  paths are reused instead of re-downloaded. Also create `/nix/var/nix` in the
  image — its absence made nix fall back to a chroot store that cannot build.
  Verified in-pod on v0.2.9: registration + `hello` build end-to-end.
- Every `op read` in `mise-tasks/` now runs with `stdin=subprocess.DEVNULL` and a
  30s timeout, and every caller handles `TimeoutExpired`. `subprocess.run(...,
  capture_output=True)` redirects stdout and stderr but leaves stdin inherited, so
  `op` — which misparses a non-TTY stdin — could block forever on a parent whose
  stdin was a pipe, with no timeout to break it. Four tasks (`branch-cleanup`,
  `dns-acme-cleanup`, `spork-create`, `container-build-and-release`) were missing
  the stdin redirect outright, and `spork-create` and `container-build-and-release`
  turned a nonzero exit into an uncaught `CalledProcessError` traceback rather than
  a message saying which secret could not be read.

  The hang is reproducible without touching a real vault: give a parent process a
  stdin pipe nobody writes to, put a shell `op` that does `read x` on PATH, and the
  call never returns; `stdin=DEVNULL` makes it return immediately.
- `provision-ringtail` no longer hangs, or half-applies a switch, when activation
  restarts the network under it. Two independent causes, one per fix:

  `nixos-rebuild switch` ran as a child of the SSH session it was invoked over,
  and activation restarts `sshd`, `tailscaled` and the network stack — so a session
  teardown mid-activation could kill the switch partway through. It now runs as a
  transient systemd unit (`blumeops-nixos-rebuild`) via `systemd-run`, outside the
  session's lifetime; the play reconnects with `wait_for_connection`, polls the
  unit to completion, and fails with the unit's journal if systemd's `Result` is
  anything but `success`.

  Separately, `ansible.cfg` had no `[ssh_connection]` keepalives. When the far end
  goes away mid-task the TCP connection is not closed, only silent, so ssh waited
  on it forever and a playbook that had finished its work hung until someone
  noticed. `ServerAliveInterval=15` with `ServerAliveCountMax=20` bounds that to
  about five minutes; `ConnectTimeout=30` bounds the initial dial, which the
  keepalives do not cover. This applies to every playbook, indri included.
- An approved SHA now has to reach the run it approves. `warrant-policy.yaml`
  gives every warrant-class action a `binds_sha` naming the dispatch input that
  carries the commit, and `mise run request-run` refuses a request that omits it,
  sends a different SHA, or sends a mutable ref like `main`. Previously the bound
  SHA and the dispatch inputs were unrelated fields: warrant #22 approved
  `bcb2b55`, dispatched with no `ref`, built main, and reported success.
  `verify-runs` audits the same property afterwards — comparing the request record
  against itself, never the run's `head_sha`, which is main's tip at dispatch time
  — and leaves a mismatched task open instead of closing it. Request comments now
  link the Warrant queue entry, and a bare `#N` in `--why` no longer autolinks to
  an unrelated PR.
- agent-ws now authenticates to Anthropic with a long-lived `claude setup-token`
  credential read from `op://agents/claude-oauth-token/token`, instead of the
  interactive OAuth login stored on the PVC. That login's refresh token carried a
  hard ~7-day expiry and died silently — remote-control kept reporting
  `✔︎ Connected` and the liveness probe stayed green while every session start
  failed `OAuth session expired and could not be refreshed`. Auth now survives PVC
  loss and rotates without a shell in the pod.
- Remote Control refuses `claude setup-token` credentials — with
  `CLAUDE_CODE_OAUTH_TOKEN` exported, claude exits at startup ("Long-lived
  tokens … are limited to inference-only"), so the v0.16.0 agent-ws pod
  crash-looped on its startup probe. v0.17.0 drops the export and returns to
  the PVC `claude auth login` credential; its ~7-day expiry is now managed by a
  recurring 5-day rotation chore documented in the new
  [[rotate-agent-ws-claude-login]] how-to.
- Stop zot's Trivy DB downloads from poisoning log shipping. The CVE extension
  downloads trivy-db (~90MiB) and trivy-java-db (~900MiB) daily with trivy's
  progress bar enabled — zot hardcodes `quiet=false`, no config knob — and under
  launchd's file redirection the carriage-return animation frames of one download
  pile up into a single newline-less line of up to 3.7MB. Loki rejects any entry
  over its 256KB limit with a 400 that fails the whole batch, which is how
  `mcquack.zot.err.log` shipped zero lines despite being actively written (the
  zot.err half of the indri log-shipping audit): only 9 of the file's 37k lines
  were progress bars, but they wedged alloy's position tracking and dragged the
  normal lines down with them.

  Three layers, in order of the pipeline:

  - The zot LaunchAgent now starts via a wrapper (`zot-serve.sh`) that passes
    stderr through an awk filter which splits physical lines on CR and drops the
    bar frames, keeping any real content that shares the line. stdout is
    untouched.
  - A one-time idempotent task truncates the polluted stderr log (its real
    content is already in Loki; the bar frames are unshippable), which also
    resets alloy's saved tail position — parked mid-file at the end of the first
    giant line — via truncation detection.
  - The alloy role gains a `loki.process` guard that drops any line over 255KB
    from any tailed service instead of letting it fail the batch, counted in
    `loki_process_dropped_lines_total{reason="line_too_long"}`.
- Stop spelling `prune: false` / `selfHeal: false` in Application manifests: the controller strips explicit-false fields (Go omitempty) on every automated sync, leaving a field-level diff that flapped the `apps` root OutOfSync (2026-08-18 ntfy alert; recurring since automated sync landed).
- `mirror-update-pats` works again on Forgejo v16, which broke both halves of it.

  The query half died outright: `mirror.remote_address` is now
  `encrypted_remote_address`, a BLOB, so the task failed with `no such column` —
  and then printed `No GitHub mirrors found.` and exited 0, the same
  success-shaped failure the previous fix was meant to end. Discovery now comes
  from the API (`/repos/search`, filtered on `mirror`, reading `original_url`),
  which needs no database access and cannot break on an internal schema change.

  The write half died more quietly. v16 moved the credential off disk into that
  encrypted column and rewrites each mirror's git config to a sanitized,
  password-free URL, so `git remote set-url` no longer sets the secret Forgejo
  actually uses. There is no API for it — `routers/api/v1/api.go` exposes
  `mirror-sync` and the `push_mirrors` group and nothing else, and the repo
  settings form is the only sanctioned writer.

  So the task drives Forgejo's own recovery path. `DecryptOrRecoverRemoteAddress`
  treats a NULL `encrypted_remote_address` as "credentials may be on disk": it
  reads the URL from git config, encrypts it into the database, and re-sanitizes
  the config. Writing the authenticated URL and then clearing the column hands
  Forgejo the new credential through the door it already opens for mirrors that
  predate the encrypted column. Each mirror is then synced immediately, rather
  than left up to 8h in a state indistinguishable from having no credential.

  A new guard compares the API's mirror count against `SELECT COUNT(*) FROM
  mirror` and refuses to proceed if they differ. The API returns only what the
  token can see — 33 of 35 for a token without full visibility — so without this
  the task would rotate a subset and report success, leaving the invisible
  mirrors on the expiring PAT.

  Two caveats worth knowing. Clearing the column is a write to a live WAL
  database behind a running Forgejo, done with a busy timeout and immediately
  followed by a sync. And the recovery path is documented upstream as being for
  mirrors predating the column, so it may be removed — at which point this breaks
  again. A pull-mirror credential endpoint is the durable fix and needs asking
  for upstream.
- Fix zot registry outage: the Trivy stderr progress-bar filter (awk,
  line-oriented) buffered the newline-less CR-stream of a DB download
  indefinitely, wedging zot's stderr pipe — zot froze at "updating cve-db"
  before binding HTTP, leaving the registry dark for ~12h. Replaced with an
  unbuffered byte-stream filter (`tr -u` + line-buffered grep).

### Infrastructure

- The thirteen ArgoCD apps that render config through a kustomize
  `configMapGenerator` now sync with `prune: true`. Each content edit produces a
  new hash-suffixed ConfigMap; with prune off the superseded one was never
  deleted, so the app read `OutOfSync` indefinitely and `ArgoCDAppOutOfSync` fired
  on a deploy that had worked exactly as intended. `selfHeal` stays off, and the
  remaining apps keep `prune: false`.
- Restored two of the three checks that the Lint workflow's prek cleanup removed rather than reinstated as-is. A `secret-scan` job now runs gitleaks over the repository's full git history on every PR (~7s for ~1500 commits) — the removed trufflehog hook's `--since-commit HEAD` range had scanned nothing in CI, and on a public repo a historical leak matters as much as a new one. A first full-history scan found six findings, all one false-positive class (nix-built image tags like `authentik:v2025.10.1-b8bc0bf-nix`, whose git-hash segment reads as entropic), now allowlisted by shape in `.gitleaks.toml`; the history is otherwise clean. A `workflows-validate` job validates `.forgejo/workflows/` against the runner's own schema by invoking indri's source-built `forgejo-runner` directly — `validate` is a plain subcommand, so the docker/dagger requirement that pushed this check out of prek never applied to CI. That made the `validate_workflows` dagger function and `mise run validate-workflows` fully redundant, and both are retired; the how-to keeps a docker one-liner for off-runner use. `ty-check` remains the one capability still missing, tracked separately.
- New `.forgejo/CODEOWNERS` requests review from `eblume` on every PR, so an
  agent-opened one lands in the "Review requests" filter rather than in no queue
  at all. It is a notification, not a merge gate, and unlike a workflow it costs
  no runner job per PR. Same file is going into every agent-ws repo.
- Trade Warrant Bot Drift's `pull_request` trigger for a `push` on `main` over
  the same paths. The job reads collaborator permissions and branch protections,
  which needs `FORGE_ADMIN_TOKEN`; fork PRs receive no secrets and every agent PR
  is a fork PR, so as a PR check it could only reach `--skip-if-no-token` — which
  exits 0 and renders as a green tick. That false pass is how PR #506 merged a
  check that could never have passed. The post-merge `push` run is the first one
  with a real token, and the weekly schedule remains the standing check; neither
  can pass by abstaining.
- Homepage: add static tile for the heph PWA (heph.ops.eblu.me) — indri-native, so no Ingress to auto-discover.
- Closed the observability gap where an indri log stream could stop reaching Loki and nothing would notice — the forge's own log was absent for two months (fixed in #548) and the audit that found it had no way to notice a recurrence. A new `log-shipping` Grafana alert group watches the four streams with guaranteed daily traffic (forgejo, forgejo-runner, zot, tailscaled), one rule per stream riding `noDataState: Alerting`, since a silent Loki stream returns no series rather than a zero; streams that currently write nothing or too sparsely to alert on are deliberately excluded, with the exclusions documented. Host inspection during review surfaced one live defect the new self-metrics are built to diagnose — `zot.err` is actively written but never reaches Loki — plus actively-written logs missing from the declared tail list entirely (`caddy.err` at 559MB, `heph`, `devpi`, `borgmatic-photos.err`), both tracked as follow-ups. All four rules go NoData together when alloy itself dies, and the new runbook (`runbook-log-stream-silent`) leads with that signature. Alloy on indri now also scrapes its own component metrics into Prometheus (`loki_source_file_*`, `loki_write_*`), so "is the file being tailed at all" is answerable from an agent pod instead of needing ssh.
- `ruff` now lints `mise-tasks/`, which it has never covered. The hooks select
  `types: [python]`, and `identify` derives that tag from the shebang — it reads
  `#!/usr/bin/env -S uv run --script` as the interpreter `uv`, so none of the 26
  uv-script tasks were ever tagged Python and no Python hook matched them. The
  directory holding most of this repo's logic was the least-linted part of it.

  A third ruff pass selects the directory by path. `mise-tasks/` is mixed bash and
  uv-python and ruff cannot parse the bash, so the split is `exclude_types =
  ["shell"]`: bash tasks carry a `shell` tag from their shebang, uv scripts are
  tagged only `executable, file, text`. Nothing needs updating as tasks are added
  in either language.

  Turning it on found 13 issues across 7 tasks — dead imports, f-strings with no
  placeholders, and one dead store in `docs-preview` where `card_file` was
  assigned in both branches and never read. All fixed here; only the existence
  checks that guard the not-found branch ever mattered.

  **No `ruff-format` pass over `mise-tasks/`, deliberately.** The formatter
  normalizes `#COMMENT` to `# COMMENT`, and mise matches its task metadata
  comments without a space. Running it rewrites every `#MISE description=` and
  `#MISE alias=` line, which silently empties the description column of
  `mise tasks` for all 26 tasks and breaks task aliases. That takes the `[human]`
  prefix with it — the marker AGENTS.md tells agents to check before reaching for
  a task they cannot run. Formatting is cosmetic; that fence is not.
- The four local prek hooks — `container-version-check`, `changelog-check`,
  `docs-check-links`, `docs-check-frontmatter` — now run their script directly
  instead of through `mise run`, which installed the whole `[tools]` block first
  and made the Lint job depend on the GitHub API it has no credential for.
- The prek hook set now runs on every PR, as a **Lint** workflow alongside Docs
  Checks. Until now the hooks ran nowhere: no workflow invoked prek, and no git
  hooks are installed in an agent pod, so enforcement was whoever remembered to
  run `prek run --all-files` on gilbert. That is not a theoretical gap — it is how
  five Python files drifted out of `ruff-format` shape unnoticed, and how ruff came
  to have never once looked at `mise-tasks/`, the directory holding most of this
  repo's logic.

  The runner needed nothing added. `prek` and `actionlint` are already in
  `forgejo_runner_host_tools` at revs mirroring `prek.toml`, and `uv` already runs
  the extensionless mise-tasks. The toolchain was provisioned for exactly this and
  then never wired up.

  `actionlint-system` therefore runs here for the first time. A `*-system` hook
  runs whatever is on PATH, and an absent binary does not skip — prek reports the
  hook FAILED — which is why blumeops' actionlint hook had never caught a workflow
  error in either state. The workflows are clean today, verified against actionlint
  1.7.12.

  **Three hooks are removed rather than skipped**, because CI is now the
  enforcement point and a hook that cannot run in a clean checkout is one nobody
  is running:

  - `ty-check` — `[tool.ty.environment]` points at `sdk/src`, the dagger-generated
    SDK. `/sdk/` is gitignored, so ty aborts in *any* fresh checkout, CI or local.
  - `validate-workflows` — shells to `dagger call`, needing Docker Desktop and an
    engine container. Still available as `mise run validate-workflows`.
  - `trufflehog` — pinned to `--since-commit HEAD`, an incremental range that
    scans nothing on a fresh checkout.

  Removing beats skipping: a skip list is a second place to drift, and it lets
  `prek.toml` keep accumulating hooks that only appear to run. What is left is
  25 hooks that all pass, so the job's result is the whole of what the hook set
  checks.

  The job blanks `GITHUB_TOKEN`. Forgejo Actions sets it to the *forge* job token,
  and mise honours that name for `api.github.com` — so it offers a Forgejo
  credential to GitHub and takes a 401 on any tool it has to resolve, which fails
  every hook whose entry is `mise run`. This is the per-repo workaround; the class
  fix is a scopeless `MISE_GITHUB_TOKEN` in the runner's `envs`.

  Two of these are real capabilities and their loss is not free. **Secret scanning
  is now the builtin `detect-private-key` alone**, which catches private keys and
  nothing else — on a repo whose first rule is that it is public. Workflow *schema*
  validation is likewise gone, though actionlint covers much of the same ground.
  Both are tracked for a CI-shaped rebuild rather than reinstatement as-is.
- Share `eblume/project-template` with the agents bot — `write` + `canonical` in
  `containers/agent-ws/repos.json`, so it lands in the pod's checkout pool like any
  other worked-on repo. Three open template tasks (rename `build.yaml`, pin the
  mise versions, reconcile the `prek` step) all stalled at the same line in their
  notes: *"NOT checked out under ~/code/personal — a later session must clone it to
  edit."* The repo is public, so it was always readable; what was missing was push,
  and a checkout to notice it from.

  Also corrects the bootstrap how-to, which still told a human to grant repo access
  by hand in the Forgejo web UI and listed a repo set predating `repos.json`. That
  instruction is now actively wrong: the reconcile is authoritative in both
  directions, so a hand-clicked grant is reverted on the next run.
- Move `repos.json` from `containers/agent-ws/` to the repo root. The file
  has outgrown agent-ws: it defines both the `agents` bot's forge access
  policy and the workspace checkout pool, and the pool is now consumed by two
  images (agent-ws *and* talos — the latter already read it cross-directory,
  `../agent-ws/repos.json`). Root placement reflects that it is org-level
  agent policy, not container config, and survives agent-ws' eventual
  retirement. Pure source-tree refactor: both container `default.nix` files
  bake it at build time (`readFile`), the reconciler mise task, the workflow
  path filters, and doc references are updated to match. Nothing reads it at
  runtime.
- Add `mise-tasks/_require`, a guard that refuses to start a task whose tools the
  machine does not have, and wire it into the four tasks whose blocker really is a
  missing binary: `validate-workflows`, `frigate-export-model` and `docs-preview`
  (docker, for Dagger's engine) and `services-check`,
  `ensure-k3s-ringtail-kubectl-config` (kubectl). It names what is missing, that
  you are in the agent pod, and what to do instead — a `[human]` description tag
  is invisible at the moment of failure and does nothing about a task that runs,
  half-works and exits 0.

  Also marks `[human]` on eleven tasks that cannot run from the pod but were not
  labelled, and corrects that label's definition: it means "needs something the
  pod does not have", of which the blumeops vault is only one case — a missing
  tool or an ssh route to indri/ringtail are the others.
- Retire agent-ws. Remove the agent-ws image (containers/agent-ws), its k8s
  manifests and ArgoCD app, its service-versions entry, and the claude-login
  rotation runbook; talos supersedes it. The shared tag:agent Tailscale auth key
  is renamed to generic agent naming (Pulumi `agent_authkey`, 1Password item
  'agent Tailscale Auth Key', `mise run agent-authkey-sync`).
- Install `actionlint` and `stylua` on the Forgejo runner. prek downloads the
  environment for most hooks, but a `*-system` hook runs whatever is on `PATH` by
  definition — and a missing binary is reported as a **failed** hook, not a skipped
  one. Two consequences had been sitting unnoticed:

  - blumeops' own `actionlint-system` hook has never linted a workflow. It would
    have been failing anyway: `.github/actionlint.yaml` was missing the `indri` and
    `priv` labels, which made 10 of 12 workflows unlintable (fixed separately).
  - `hephaestus.nvim`'s CI has its `prek run --all-files` step stubbed out with an
    `echo`, blamed on a runner without prek. prek has been installed for a while;
    what actually still blocked the restore was `stylua` and `actionlint`.

  The runner reference card also listed a toolchain that was never accurate — it
  advertised a `jq` the role does not install. It now points at
  `forgejo_runner_host_tools` as the source of truth rather than restating it.

  Realign `flyctl` 0.4.59 → 0.4.71, which had drifted from the `mise.toml` pin
  since 2026-07-19. Every version in `forgejo_runner_host_tools` mirrors a pin
  held elsewhere — `dagger.json`, `mise.toml`, `service-versions.yaml`, the
  `prek.toml` hook revs — and nothing bumps the mirror when the source moves, so
  it goes stale silently. The variable now documents which source each entry
  tracks, and the `forgejo-runner` entry in `service-versions.yaml` says to diff
  the list against those sources as part of the review.
- The indri runner now injects `MISE_GITHUB_TOKEN` into every job's environment
  via `runner.envs`, sourced at provision time from the `forge-ci-github-pat`
  1Password field. Forgejo sets `GITHUB_TOKEN` in every job to the *forge* job
  token, and mise honours that name for `api.github.com` — so any GitHub-backed
  tool resolution took a 401. `MISE_GITHUB_TOKEN` outranks it in mise's lookup
  order (first non-empty of `MISE_GITHUB_TOKEN`, `GITHUB_API_TOKEN`,
  `GITHUB_TOKEN` wins), fixing the class for every repo the runner builds with
  no workflow changes.

  The token is the same zero-permission public-read PAT the mirror sync uses —
  readable by every job on the runner, which is exactly why it must never grow a
  scope. Takes effect at the next `provision-indri`; after that,
  hephaestus.nvim's per-step `GITHUB_TOKEN: ""` workaround can come out
  (blumeops' own Lint keeps its blank deliberately — that job is
  credential-free by design and no longer touches the GitHub API at all).

  heph: 01KZKP8893WM8DQT5N97QF6PBD (design), 01KZP94PSDXAMV3GNN2WE51HGA
  (credential decision).
- Add an hourly `skagit-cce-watch` user timer on ringtail that polls the Skagit
  CCE course-catalog category and files a **red** heph task (under the new
  **Ceramics** project) the first time a new ceramics class is listed, keyed on
  the catalog's Item Number. State lives in `~/.local/state/skagit-cce-watch/`;
  first run baselines silently and a zero-course parse fails loudly without
  touching state.

  On a new ceramics class it also fires a **best-effort** ntfy push to
  `ntfy.ops.eblu.me/ceramics` (tapping opens the course page) so the alert
  reaches Erich's phone; a push failure never fails the tick.
- `containers/talos/default.nix` was bumped to 0.4.0 without the matching `service-versions.yaml` entry, which made `container-version-check` fail on every push. Sync the recorded current version to v0.4.0.
- Bake an eval-only nix into the talos image (agent-ws precedent):
  `$HOME`-relocated store on the PVC (`NIX_{STORE,STATE,LOG,CONF}_DIR` in the
  image config), `max-jobs = 0` nix.conf, size-swept by the entrypoint. Lets
  the talos pod compute `srcHash` values for its own image bumps via
  `nix-prefetch-git` instead of guessing and burning warrant-approved Build
  Container rounds on hash-mismatch errors — the pod that needed this was
  caught computing a wrong hash by hand during the v0.2.4 release. Version
  bump 0.2.3 → 0.2.4 for the toolchain change.
- The talos pod's nix can now **build**, not just evaluate: the image's top
  layer chowns the canonical `/nix/store` to the container user, so store-path
  hashes stay canonical and `cache.nixos.org` substitutes. Builds run
  unsandboxed (seccomp forbids user namespaces) inside the already-fenced pod,
  capped by `max-jobs = 2` and a new `ephemeral-storage` limit on the
  Deployment. `docs/explanation/agent-containerization.md` §"Nix in the pod"
  records the eval-only phase this supersedes.
- talos image v0.2.3: bake the `mise run` toolchain (mise, uv, python3,
  gnutar/gzip, which), a `/tmp`, and `/usr/bin/env` into the pod, and wrap
  `tea` to route through the tag:agent SOCKS sidecar. Filing a warrant
  request or opening a PR from the pod previously required hand-installing
  `uv`, hand-exporting proxy env for `tea`, and working around the missing
  `/tmp`; the uv-managed CPython it fell back to cannot execute in the
  non-FHS image, so `python3` now rides on `PATH` instead.
- The talos pod now enforces the lint gate locally instead of relying on agents to remember `mise run agent-lint` (#582): the entrypoint installs prek git hooks into every pool clone that carries a `prek.toml` (blumeops today). `pre-commit` runs prek over the staged changes; `pre-push` runs the exact CI hook set over all files, skipping prettier (a node hook the pod doesn't ship). The hooks land in the pool clone's common git dir, so every session worktree inherits them without any agent action, and the entrypoint reinstalls them idempotently at every pod start. prek resolves through `mise exec` at run time — nothing new is baked into the image — and `git commit/push --no-verify` remains the escape hatch. Agent PR checks sit pending until a human approval click, so catching lint failures at push time instead of in CI saves a review round; this complements #582's manual task, which stays as the on-demand form of the same gate.
- Add `talos` to the agents repo pool (`access: write`, `pool: canonical`),
  granting the `agents` bot collaborator write on `eblume/talos` and checking
  the repo out in agent workspaces. Talos is entering active agent-driven
  development (web-UI features land as branch + PR like the other canonical
  repos); without a pool entry the reconciler denies the bot access, so pushes
  from the talos pod are rejected.
- talos pod: wire the base pi subagent assets into `~/.pi/agent/` at pod
  start — symlink `agents` and `extensions` from the agents repo's new `pi/`
  directory (pool checkout stays the source of truth), ship a `pi` CLI wrapper
  at `~/.pi/agent/bin/pi`, and export `PI_BIN` for the extension's child
  processes. This is what lets talos sessions delegate bounded work to cheaper
  models (eblume/agents#13, eblume/talos#8). Image bumped to v0.2.9, pinning
  talos main at 65d9727 (includes the subagent tools allowlist). Toolchain
  gains `diffutils`, `gawk` and `hostname`.
- The talos pod `tea` wrapper now auto-assigns `eblume` on `tea pr create` (unless the caller specifies assignees), so agent-opened PRs surface in the assigned-to-me queue. Chosen over a per-repo Forgejo Actions workflow (eblume/hephaestus#43, closed). Takes effect on the next image rebuild + deploy.
- CI secrets migrated to job-time `op read` of `blumeops-ci` vault items
  ([[blumeops-ci-item-migration]]): `argocd-deploy`, `build-container`,
  `deploy-fly`, `build-blumeops` and `cv-deploy` now fetch their credentials
  with `BLUMEOPS_CI_OP_TOKEN` at runtime instead of per-secret Actions
  secrets, `_1password-cli` joins both ringtail runner sandboxes, and the
  `forgejo_actions_secrets` role stops syncing the migrated secrets (talos
  and horkos release CI get `BLUMEOPS_CI_OP_TOKEN` instead of the raw zot
  key, per the one-CI-trust-tier decision).
- Made the deploy-fly workflow's post-deploy health check fatal (with cold-start retries). With `strategy=immediate` a machine that fails to boot is a live outage, but the run still reported success — as happened 2026-08-15 when an expired `TS_AUTHKEY` crash-looped the new machine (run 957). Also documented the immediate-strategy downtime window in `fly/start.sh` and added a recurring 75-day heph task to rotate the 90-day Tailscale auth key before it expires.
- Horkos (né Warrant) cutover, additive half: ArgoCD Application (**manual sync** — the approval gate no longer redeploys itself on merge, which also ends the auto-sync/dispatch race), `argocd/manifests/horkos/` (namespace, PVC, external-secrets reusing the existing warrant vault items), Authentik `horkos` OIDC client, and the `horkos.ops.eblu.me` Caddy route. Warrant keeps running untouched until the decommission PR.
- Horkos cutover, decommission half: `containers/warrant/` and the warrant manifests/Application are removed (the service now lives in eblume/horkos), `request-run`/`verify-runs` point at `horkos.ops.eblu.me`, the Authentik `Warrant` provider and Caddy route retire, `warrant-test` becomes `horkos-test` (client tooling only — the service suite moved with the service), and the service card is now [[horkos]]. Kept on purpose: `warrant-policy.yaml`, `warrant-bot`, and the `Warrant request: #N` PR stamp — the minted artifact is still a warrant.
- Add `horkos` to `repos.json` so agent pods get a workspace checkout of it — as `access: read, pool: fork` (authors via `agents/horkos`, PRs to canonical), matching blumeops. horkos is pinned into the reconciler's `PINNED_READ_ONLY` set: it's the approval gate itself and its CI carries release secrets, so a write-capable bot could dispatch `release.yaml` from a doctored branch and exfiltrate them. The `agents/horkos` fork was created alongside.
- repos.json moved to `argocd/manifests/talos/` and delivered to the talos pod as a kustomize-generated ConfigMap: the hash-suffixed name changes the pod template on every policy merge, so a repos.json change now deploys itself (merge → ArgoCD sync → pod rolls) instead of waiting for someone to remember a restart. The talos app gains `prune: true` to garbage-collect superseded hashed ConfigMaps; the agent-repo-access reconciler and its workflow triggers follow the file.
- Talos agent pods can now inspect deployment state directly: new `agents-readonly` ArgoCD local account (apiKey, get-only on applications/projects — no sync, no logs, no exec, Secret values masked server-side), token in the agents 1Password vault read at runtime via the pod's `op` service account, and a proxied `argocd` CLI wrapper in the pod image. The kubectl leg was deliberately skipped: the tag:agent ACL denies the k8s API, and ArgoCD's resource tree covers health inspection.
- Talos releases are automated: the image derivation moved into the eblume/talos repo (built from its own checkout — no more rev+srcHash pinning here), and every merge to talos main now builds, pushes `vX.Y.Z-<sha>-nix`, and opens a pin-bump PR against blumeops. `containers/talos/` is retired; the repo pool policy (`repos.json`) is fetched by the pod at start instead of baked into the image.
- Deploy agent-ws 0.18.0 — `project-template` now lands in the agent workspace's
  checkout pool, so sessions get a worktree of it instead of cloning by hand.
- Tooling dependency cycle: bumped mise tool pins (ansible-core, borgmatic, prek,
  pulumi, dagger, ty, flyctl), the fly proxy's tailscale image, and warrant-test's
  unit-test dependencies to their latest stable releases; synced service-versions.yaml
  and stamped today's ansible-core service review. Closes heph 01KT5Q9HFG8TF8TSXDQP36CF3R.
- Monthly tooling dependency refresh: ruff v0.16.3, prettier v3.9.6, ansible-lint 26.8.0 / `ansible-core` 2.21.3, `actions/checkout` v7.0.1, `typer==0.27.1` across mise tasks, fly proxy alloy v1.18.1 and anubis v1.27.0. ruff's lint `select` is now pinned in `pyproject.toml` — 0.16 widened its implicit default from 60 rules to 414, so the enforced set no longer moves with a version bump.
- Forgejo upgraded 15.0.3 → 16.0.2, and `mise run runner-logs` moved onto the
  Actions job-log REST API that arrived with it. Private-repo CI logs were
  unreadable outside a browser: the only log route Forgejo 15 has is a **web**
  route, and Forgejo does not accept API-token auth on web routes at all — token,
  `Bearer`, basic and `?token=` all leave the request anonymous, which is enough
  for public `blumeops` and a 404 for every private repo. v16's
  `/repos/{owner}/{repo}/actions/jobs/{job_id}/logs` honours the token, so
  `runner-logs` prefers it, keeps the web route as a pre-upgrade fallback, and now
  says which of the two failed and why instead of "no log available".
- Ollama is re-enabled on ringtail (`replicas: 1`) and `qwen3.8:27b` is added to the synced model set, to evaluate local inference as a provider for talos.
- Pin the talos image to `v0.4.1-0444de5-nix` (built by warrant run 1173), deploying the `tea` wrapper auto-assign from #598. talos is an auto-sync app, so the argocd sync on merge is the deploy — no explicit argocd-deploy run needed.
- Pin the talos image to `v0.4.2-1b31ea6-nix` (built from the #605 bump by a warrant build-container run), deploying the tool/subagent transcript UI from eblume/talos#15. talos is an auto-sync app, so the argocd sync on merge is the deploy — no explicit argocd-deploy run needed.
- Pin the talos image to `v0.4.3-828dee6-nix`: archive/rename chat actions,
  auto session titles, and the stale-client auto-reload fix.
- Pin the talos image to `v0.4.4-b685cfc-nix`: programmatic API —
  non-interactive, token-authenticated runs via `POST /api/run` (eblume/talos#19).
- Release talos image v0.4.1: same upstream talos (rev unchanged) but the baked toolchain gained the `tea` wrapper auto-assign from #598, which needs a rebuilt image and a deploy to take effect.
- Bump talos image to 0.4.2 (talos `66448e8`): the chat UI now shows full
  tool/subagent transcripts in collapsed blocks, and tool activity survives
  session reloads (eblume/talos#15).
- Bump talos image to 0.4.3 (talos `56b430a`): per-session Archive/Restore
  and Rename actions in the chat header (eblume/talos#16), auto-generated
  session titles (eblume/talos#17), and stale-client auto-reload after a
  deploy — the fix for the broken transcript rendering seen after v0.4.2
  (eblume/talos#18).
- Bump talos image to 0.4.4 (talos `eaedc74`): programmatic API —
  `POST /api/run` for non-interactive, token-authenticated runs
  (eblume/talos#19).
- Bump talos image to 0.4.5 (talos `7b2d64c`): cron sessions —
  scheduled headless runs as a third session kind (eblume/talos#21).
- Pin the talos image to v0.2.10-b9c2cb3-nix (build run 1075). The v0.2.10
  image registers the image's own store paths into the pod's nix DB at
  startup and creates /nix/var/nix — the two fixes from PR #581. Merge
  auto-syncs the talos app and restarts the pod. Post-deploy smoke test:
  nix-build hello must succeed in a fresh pod with no manual setup.
- Pinned the talos image to `v0.2.11-8fe10b5-nix`, built from the #584 merge commit. v0.2.11 makes the lint gate hard: the pod's entrypoint installs prek pre-commit/pre-push hooks into pool clones carrying a `prek.toml`, so agent commits and pushes of blumeops run the CI hook set before leaving the pod — no agent action needed, `--no-verify` to bypass deliberately. `service-versions.yaml` already moved to v0.2.11 in #584 itself, so this pin only moves the kustomization tag; merge auto-syncs talos and restarts the pod.
- Bumped talos to v0.2.12: upstream bump to talos `9dfb7f1` (eblume/talos PR #10), which adds structured request logging to the talos server — one `[talos]` line per login, session create, prompt, tool call, assistant turn, abort, and dictation with the acting user and model, never message content or costs. Transcribe failures, previously invisible, now log the OpenRouter error plus provider detail and surface it in the 502 body. Only `src/server.ts` changed upstream, so `npmDepsHash` is unchanged.
- Pinned the talos image to `v0.2.12-9e31cce-nix`, built by warrant run #40 from the #586 merge. v0.2.12 is the structured-logging release of the talos server ([eblume/talos PR #10](https://forge.eblu.me/eblume/talos/pulls/10)): one `[talos]` log line per login, session create, prompt, tool call, assistant turn, abort, and dictation, plus real error detail from OpenRouter/provider failures in the transcribe path — the gap that made a dictation failure undiagnosable in Loki. `service-versions.yaml` already moved to v0.2.12 in #586, so this pin only moves the kustomization tag; merge auto-syncs talos and restarts the pod.
- Deploy Warrant 0.4.0 — the supersede API, so an obsoleted request stops
  looking live in the approval queue.
- Deploy agent-ws `v0.17.0-5418120-nix`, the image built from the
  `CLAUDE_CODE_OAUTH_TOKEN` revert. The cluster had stayed pinned to the broken
  `v0.16.0` image — which crash-loops, since Remote Control refuses an
  inference-only token — because the revert changed `containers/agent-ws/` without
  bumping `kustomization.yaml`.
- Upgraded heph to v1.9.0 across the fleet (hub `heph_version` + ringtail spoke `hephTag`): seq-based sync cursors with deferred out-of-order ops and chunked pushes, fixing the HLC-cursor drop and FK-wedge failure classes behind the 2026 pod spoke outages.
- horkos v0.5.1: auto-release from eblume/horkos `8b6b1b1` — image pin bumped to `v0.5.1-8b6b1b1-nix`.
- Pin talos `v0.4.6-c904e38-nix` (agents-m2m API bearer auth) in its ArgoCD
  kustomization.
- Pin warrant `v0.4.1-fbd37ad-nix` (request-run `--repo` support, pr_repo on
  requests) and talos `v0.4.5-fbd37ad-nix` (cron sessions) in their ArgoCD
  kustomizations.
- Bump the talos image to v0.4.6 (talos#22 — trusts the `agents-m2m` machine
  identity for bearer auth, so scripts/services can drive the API).
- Talos main model switched from `qwen/qwen3.8-max` to `qwen/qwen3.8-27b` (now on OpenRouter): ~4.4x cheaper input, ~2x cheaper output, addressing the ~$5-per-cycle run cost.
- talos v0.4.11: auto-release from eblume/talos `0f6388e` — image pin bumped to `v0.4.11-0f6388e-nix`.
- talos v0.4.7: auto-release from eblume/talos `ed6337f` — image pin bumped to `v0.4.7-ed6337f-nix`.
- talos v0.4.8: auto-release from eblume/talos `ea2791d` — image pin bumped to `v0.4.8-ea2791d-nix`.
- talos v0.4.9: auto-release from eblume/talos `cc88c5e` — image pin bumped to `v0.4.9-cc88c5e-nix`.
- Pin upstream talos 0a95bf1 (v0.2.5): markdown rendering in chat,
  stop/steer agent controls, dictation-review input, and the dictation
  status gutter (talos PRs #4–#5). The lockfile gained a direct `marked`
  dep, so `npmDepsHash` changes with this bump. `srcHash` computed
  in-pod via `builtins.fetchGit` (eval-only nix, [[agent-containerization]]).
- talos image v0.2.5 → v0.2.6: pin upstream talos `81011bb` (eblume/talos#6 —
  sessions now start with the `agents` repo's `AGENTS.md` preloaded into the
  system prompt via pi's `agentsFilesOverride`, restoring the base context
  agent-ws sessions got from waking up inside the `agents` checkout).
  `npmDepsHash` unchanged (lockfile untouched); `srcHash` recomputed in-pod
  with the eval-only nix (`git archive` + `nix hash path`).
- talos image v0.2.6 → v0.2.7: pin upstream talos `cde7f25` (eblume/talos#7 —
  per-session git worktree isolation: each session works in its own
  `~/sessions/<id>/` worktrees of the pool repos instead of sharing the pool
  checkouts; a startup reaper prunes stale sessions with agent-ws semantics).
  `npmDepsHash` unchanged (lockfile untouched); `srcHash` recomputed in-pod
  (`git archive` + `nix hash path`).
- talos image v0.2.7 → v0.2.8: pin upstream talos `3995a5a` (eblume/talos#9 —
  fix: sessions whose working directory is a per-session worktree vanished from
  the sidebar, because the session list filtered on the shared pool path;
  the filter now matches on the session's own worktree).
  `npmDepsHash` unchanged (lockfile untouched); `srcHash` recomputed in-pod
  (`git archive` + `nix hash path`) and verified with a real `fetchgit` eval.
- talos image v0.2.8 → v0.2.9: subagent base assets wired into the pod
  (#575 — `agents/pi` symlinked into `~/.pi/agent/`, `pi` CLI wrapper,
  `PI_BIN` exported) and the pod's nix upgraded from eval-only to real
  builds (#579 — canonical `/nix/store` chowned to the container user,
  `cache.nixos.org` substitution, `max-jobs = 2`, ephemeral-storage cap).
  Toolchain gains `diffutils`, `gawk`, `hostname`. Talos source pinned at
  `65d9727` (includes eblume/talos#8, the subagent tools allowlist);
  `npmDepsHash` unchanged, `srcHash` recomputed in-pod.
- Talos v0.3.0: settings panel for main/subagent model and reasoning-effort selection (eblume/talos#11), persisted on the PVC and applied to live sessions; reasoning effort defaults to low.
- Talos image pinned to v0.3.0-b28e7ad-nix — the settings-panel release goes live.
- Talos v0.3.1: SSE stream reliability — server heartbeat + client resync
  close the "new messages don't appear until re-entry" gap (talos PR #12),
  with the reconnect path hardened in review (tracked EventSource, resync
  on manual reconnect, backoff, stale-resync guard).
- Pin the talos image to v0.3.1-4bf1f40-nix (SSE stream reliability).
- Talos v0.3.2: curated model pickers — the settings panel's primary and
  subagent selectors are now fixed shortlists (primary: Qwen 3.8 27B / GPT-5 /
  Qwen 3.8 Max / Claude Opus 5 / Claude Fable 5; subagent: Qwen 3.8 27B / Claude
  Sonnet 5 / Claude Haiku 4.5 / GPT-5 Mini / Gemini 2.5 Flash), each option
  showing live $/M pricing (talos PR #13).
- Bump ollama to 0.32.14 — 0.31.2 returned HTTP 412 pulling qwen3.8:27b (model requires ≥0.32.12).
- Bump the talos entry in service-versions.yaml to v0.4.0 — the v0.4.0 release PR updated containers/talos/default.nix without it, so container-version-check failed every PR's lint gate.
- Deploy hephd v1.8.1 (OIDC refresh-rotation race fix, hephaestus #45) to the indri hub and both ringtail spokes.
- Scale ollama back to zero replicas — qwen3.8:27b doesn't fit the RTX 4080 (16GiB VRAM vs ~18GB model), spilling to CPU at ~3 tok/s.
- Skagit CCE ceramics watch now runs every 5 minutes (was hourly), with jitter and timer accuracy tightened to match.
- Talos deploy follow-ups: npm-deps fetcher v2 for the container build
  (v1 cache layout drops nested duplicate entries, breaking offline npm
  install in CI) and the image tag pin.
- Talos v0.4.0: dashboard-first UI. The primary view is now a session
  lifecycle dashboard (filter by running/idle/archived, workflow-kind
  registry with chat as the first kind, regex transcript search, per-session
  cost, stop/rename/archive actions, live updates over a global SSE
  channel); chat moved behind each session's row. Also picks up the v0.3.2
  curated model pickers, which were built but never pinned.

### Documentation

- Reviewed the zot container-versioning doc: corrected the sync-check exemption
  list (kubectl and agent-ws) and clarified that the version assertion guards only
  some derivations; stamped last-reviewed 2026-08-18. Closes heph 01KT5Q9H78VYR0M0M8P05YZDHB.
- Doc review: `runbook-postgres-unhealthy` rewritten against the deployed state — the alert covers two CNPG clusters, `pg_isready` pointed at the retired `pg.ops.eblu.me:5432` route, Immich was listed under the wrong cluster, and the NoData case was undocumented. `PostgresClusterUnhealthy`'s summary now names the cluster via `instance` instead of the repo-wide `cluster` label.
- Reviewed the zot harden-zot-registry doc against the role's current config
  template: added the previously omitted `defaultPolicy: ["read"]` line of the
  accessControl policy and stamped last-reviewed 2026-08-21. All other claims
  (OIDC + API-key auth, external URL, group policies, anonymous metrics
  scraping, zot-ci key) verified accurate.
- Reviewed docs/how-to/zot/register-zot-oidc-client.md: corrected the blueprint entry list (two group policy bindings, zot-ci is a member of artifact-workloads, not a binding target) and stamped last-reviewed.
- The post-upgrade `doctor check` in [[upgrade-forgejo]] now runs. It was written
  as `cd ~/forgejo && forgejo doctor …`, but Forgejo derives its work path from the
  binary's own directory rather than the shell's, so it looked for `app.ini` under
  `~/code/3rd/forgejo` and exited with "Unable to load config file for a installed
  Forgejo instance". It needs `-w` and `-c` before the subcommand, the same two
  flags the LaunchAgent passes. Found while verifying the v16.0.2 upgrade.
- Document why an agent PR's checks sit `pending` until a human clicks *Approve
  and run*, and why that click is kept. It is not only friction: it decides which
  workflow files execute — the target branch's for an untrusted author, the pull
  request's own once that author is trusted — so permanently trusting the agents
  bot would let an agent PR run its own workflow definitions on the `indri`
  runner before anyone read the diff. Records that `pull_request_target` is the
  tempting way to skip the click and should not be used here, since it is the one
  trigger that receives secrets and a write-capable token.
- docs/how-to/knowledgebase/review-documentation.md: the "From a Remote-Agent Session" section is updated — remote-agent pods now have a read-only argocd client (agents-readonly account), so the ArgoCD sync/health check can be run live; kubectl/ansible/pulumi still fall back to repo state.
- Correct the agent-ws Claude login rotation cadence from 5 days to 21. The
  refresh token's window was measured at **~29 days**, not the ~7 previously
  documented — that figure came from mistaking the PVC's creation date for the
  login date, when the credential had actually been carried onto the PVC from the
  pre-container host login 22 days earlier. The runbook now reads the real
  `refreshTokenExpiresAt` off the credential at each rotation instead of trusting
  the cadence, and records two things learned doing it live: the code paste-back
  echoes nothing over `kubectl exec`, and a login performed *after* expiry needs
  the container to cycle before Remote Control comes back.
- Sweep the last current-tense `minikube-indri` references out of the docs: troubleshooting, prowler, docs-deploy, tutorials, service reference cards, the infra-health agent brief, and the live 1password-connect bootstrap README now all point at `k3s-ringtail` (minikube was retired 2026-06; historical runbooks and provenance comments are left as history).
- Design doc for Talos, a first-party pi-based agent workflow service:
  owned session layer (browser-resumable from any tailnet device via
  Authentik), OpenRouter model freedom, agent-ws-parity access model, and a
  planned forge-driven issue→PR driver sharing the same runner. Supersedes
  the Open WebUI approach (PR #562, closed).

### Miscellaneous

- Agent lint gate: new `mise run agent-lint` runs the PR prek job's hook set
  locally (everything except prettier, which needs node) — agent PR checks sit
  pending until a human approves the run, so lint failures were discovered
  late. `actionlint` joins `mise.toml` so the actionlint-system hook runs in
  the pod. Origin: the container-version-check failure on PR #581.
- `github-mirror-pat` is now `forge-ci-github-pat`. Mirroring is one consumer of
  that credential, not the only one — it is indri's general-purpose credential for
  reading public GitHub, and CI tool resolution is the next consumer lined up, to
  stop mise 401ing when it resolves a tool from the GitHub API.

  Renaming rather than minting a second token, because the capability is already
  right: it is a fine-grained PAT with **no permissions**, granting read-only
  access to public repositories and nothing else. A second token with identical
  reach would buy only another 20-day rotation chore. The rotation runbook grows a
  note to keep it scopeless, which matters more once CI jobs can read it.

  `mise-tasks/mirror-update-pats` keeps its name. It updates the PAT on mirror
  repos, which is still exactly what it does.

  **This requires a matching 1Password field rename, and the two must be
  sequenced.** Add the new field to the Forgejo Secrets item with the same value
  first, leaving the old one in place; merge this; then delete the old field. Both
  consumers (`mirror-create`, `mirror-update-pats`) are `[human]` tasks that only
  run around a rotation, so the window is forgiving — but additive-then-remove
  leaves no window at all.
- `prek run --all-files` is clean again. Five Python files had drifted out of
  `ruff-format` shape — `containers/warrant/app/main.py`, two warrant tests and two
  `tests/` modules — so the hook rewrote them on every invocation and any run that
  touched them reported a failure. Formatting only, no behaviour change. Nothing
  caught it because blumeops CI runs Docs Checks rather than prek, so the hooks are
  enforced only by whoever happens to run them locally.
- Remove `heph-cli-gilbert` from service-versions.yaml: gilbert is a dev laptop, deliberately outside IaC and often unreachable, so it doesn't belong in the automated review queue. The 2026-08-22 spot-check that prompted this found it healthy anyway — heph 1.9.0 (61bf2eea7) matching upstream v1.9.0, spoke fully synced (heph task 01M0K0HC0CYVFRH5MVGADXBY43). Also serves as the changelog fragment for the #635 prek stamp, which shipped without one.


## [v1.19.0] - 2026-08-06

### Features

- `mise run agent-health` now names the instance behind a firing or pending
  alert, not just the rule: the distinguishing labels (`file=…`, `camera_name=…`,
  `namespace=…`) plus how long it has been in that state. Grafana was already
  returning them and the task discarded them, so a report said "TextfileStale is
  pending" when it could have said which textfile — the first question every
  runbook asks. `--json` carries the full label set per live instance.
- `mise run agent-metrics '<promql>'` — ask Prometheus a question from anywhere,
  without cluster access. Goes through Grafana's datasource proxy as the same
  `agents-m2m` Viewer identity `agent-health` uses, so an agent can now verify a
  fix with data instead of inference: the frigate liveness-probe fix turned out
  to be a measurable 26x reduction in restarts (5.72/day → 0.22/day), which
  closed a task that had been open on "verify this held" since June.
- `mise run agent-health` — fleet health via Grafana alert-rule states, run
  as the `agent-ringtail` machine identity (agents-vault creds only, Viewer
  access, SOCKS fallback for the pod). Exit 0/2/1 for inactive/pending/
  firing — the agent-usable replacement for services-check's kubectl/ssh
  legs (heph 01KZ2XGW).
- `mise run warrant-bot-drift` and a weekly **Warrant Bot Drift** workflow assert
  that warrant-bot still holds exactly write on `eblume/blumeops`, is a
  collaborator nowhere else, is not a site admin, and is not on `main`'s
  push/merge whitelist. All four live in the forge rather than in this repo, so a
  change made in the UI leaves no diff for review to catch. Read-only, and an
  unreadable check reports UNKNOWN and fails rather than passing quietly.
- Grafana gains `[auth.jwt]` for the `agents-m2m` machine identity
  (heph 01KXREAB, second half): JWKS-verified tokens as `agent-ringtail` get
  Viewer via the `agents-sa` groups claim, `X-JWT-Assertion` header,
  auto-provisioned on first call. Gives agents a post-deploy observability
  read path (agent-health follows).
- Ringtail's heph spoke is now a **desktop** spoke: `heph-tui` (agenda/triage) and
  `heph-quickadd` (quick capture) install alongside `heph`/`hephd`, and sway binds
  **Alt+'** to the quick-capture popover from anywhere. The agent's headless spoke
  still installs only the daemon and CLI. Shims in eblume's home-manager profile
  put all four on the session `PATH` — `~/.cargo/bin` is on none of it, so until
  now no heph binary (including the `heph` CLI) was reachable from a terminal
  opened under sway. Because `heph-quickadd` is a
  cargo-built GUI, `heph-common.nix` now also carries the graphics/input libraries
  it `dlopen`s at runtime, and the install unit no longer skips a rebuild just
  because `hephd` is already at the pinned tag — it also requires every requested
  binary to be present.

  Also installs `tea` on ringtail: `tea pr create` is the documented way to open
  PRs here, but it was never on this host, so sessions running on ringtail had to
  fall back to raw Forgejo API calls.
- `request-run` now mirrors every privileged-run request into the
  [[warrant]] queue (agents-m2m identity, SOCKS-aware, best-effort) — the
  broker becomes the single pane of glass while PR comment + heph task
  remain the system of record.
- Arm Warrant: `WARRANT_DISPATCH_ENABLED=1`. Approving a request in
  [[warrant]] now dispatches its workflow as `warrant-bot` — the loop from
  agent request to executed run closes with one human decision. Disarm by
  setting `"0"` and syncing.
- `mise run warrant-bot-provision` — scripted, human-run ceremony for the
  Warrant dispatch identity: creates the `warrant-bot` forge user, grants
  write on blumeops, mints a `write:repository` PAT, and stores it in
  `blumeops-ci`. Deliberately not a workflow — minting privileged
  credentials from CI would need vault-write in CI and would turn
  FORGE_ADMIN_TOKEN into an escalation path.
- warrant v0.2.3: the queue links to the code — PR, its diff, the commit, and
  the workflow definition. Tying each decision to the change it authorizes is
  the substance of the approve-fatigue answer; richer ergonomics follow later.
- warrant v0.3.2: an approved warrant records the CI run it caused —
  `run_number`/`run_url` columns, a **run** column in the warrants table, and
  the run URL in the decision API response. Closes the loop visually: approve,
  then click through to what you started.
- `argocd-deploy.yaml` — the first approval-gated privileged workflow
  ([[warrant-approval-gated-runs]] Phase 1): a human-dispatched `app set
  --revision <sha>` + sync + wait-healthy, with SHA/app validation and
  env-indirected inputs. Introduces the `priv` runner label (advertised by the
  indri runner until the dedicated Phase-2 runner exists). Makes the
  "deploy from branch/merge" step agent-requestable via
  `mise run request-run`.
- Authentik gains the agent identity tier ([[warrant-approval-gated-runs]] P3
  prereq, heph 01KXREAB): `agents-sa` group, `agent-ringtail` service account,
  and an `agents-m2m` client-credentials OAuth2 provider whose client secret is
  vault-fed (`Authentik (blumeops)` → `agents-m2m-client-secret`), so consumers
  read the same value from the agents vault.
- [[warrant]] v0.1 scaffold — the Phase-3 approval broker's request queue:
  FastAPI + SQLite at warrant.ops.eblu.me, agent API authenticated by the
  `agents-m2m` Authentik JWT, read-only queue UI. Deliberately holds no
  approval path and no privileged credentials; forge dispatch remains the
  approval mechanism until v0.2.
- `warrant-policy.yaml` — the agent-autonomy boundary as a reviewed artifact
  ([[warrant-approval-gated-runs]] Phase 4 seed): per-action classes
  (warrant/auto/deny, unknown = deny) and input schemas. `request-run`
  enforces it from main at request time — app-name typos and denied actions
  now fail before a human ever sees the request (pilot friction d).
- `mise run request-run` — agents can now formally request privileged workflow
  dispatches ([[warrant-approval-gated-runs]] Phase 1): structured PR comment +
  attention-orange heph task (the system of record), optional ntfy push, SHA and
  definitions-from-main validation. Approval remains a human forge-UI dispatch.
  See [[request-a-privileged-run]].
- `mise run verify-runs` — the Phase-2 audit sweep for
  [[warrant-approval-gated-runs]]: matches open `Approve:` heph tasks to their
  workflow runs, auto-closes succeeded ones with an audit log line, and flags
  failures while leaving them open. Closes pilot friction (b).
- Warrant v0.3.0 — approvals can execute: an approved warrant is consumed
  (single-use, TTL-checked, policy re-checked against main) and its workflow
  dispatched as `warrant-bot`. Ships **disabled**; `WARRANT_DISPATCH_ENABLED`
  arms it separately. Approving now goes through a confirm page showing the
  full input set and diff link — the list view can deny, not approve.
- Warrant v0.2a — the human door: Authentik OIDC login for the queue UI
  (admins-only, TOTP-backed per the recorded decision), signed sessions, and
  an honest decision endpoint (401/403/501 — authentication without power).
  Agent requester names become human-readable. The approval flow itself is
  v0.2b.
- Warrant v0.2b — decisions and warrants: authenticated approvers
  approve/deny from the UI (CSRF-guarded forms) or JSON API; approval mints
  a single-use, TTL'd **warrant** binding the frozen {action, sha, inputs}
  (invariants 2 & 5). Still dispatches nothing — execution stays forge-side
  until v0.2c consumes warrants.

### Bug Fixes

- Recover seven changelog fragments that towncrier would have dropped. Branch
  names containing a slash produced `docs/changelog.d/agent/*.md`, and towncrier
  skips subdirectories without a word, so entries from PRs #439, #440, #521,
  #522, #523 and #524 were headed for a release that never mentioned them.
  `mise run changelog-check` had anticipated exactly this failure since it was
  written and was wired into nothing; the new **Docs Checks** workflow now runs
  it, plus the frontmatter and wiki-link validators, on every PR.
- `warrant-bot-drift` and `agent-repo-access` read a collaborator's permission
  level from `/collaborators/{who}/permission` instead of from the collaborator
  list, whose entries are plain users and never carried a permissions field.
  Warrant Bot Drift could not pass at all — every real grant read as "not
  readable" (run 724); `agent-repo-access` saw every existing grant as `read`,
  so `--check` never reported in sync and an over-privileged grant would have
  read as under-privileged.
- `runner-logs` works from an agent pod: it now targets the public forge host
  instead of the tailnet name plain httpx cannot reach, prefers the `upstream`
  remote over a fork's `origin` when detecting the repo, and bounds its `op read`
  with `stdin=DEVNULL`, a timeout, and a clean error instead of hanging. Dropped
  the `[human]` tag it should never have carried — AGENTS.md points agents at
  this task for exactly the job it could not do.

  `container-list` no longer reports every container as untagged when the
  registry is unreachable; it says so and exits non-zero, and can be routed
  through the pod's SOCKS sidecar with `ALL_PROXY`.
- The ringtail-priv-runner now carries `flyctl` in its hostPackages, fixing the first warrant-dispatched `deploy-fly` run (run 738: `flyctl: command not found`, exit 127 before any deploy action). The deploy-fly workflow header no longer claims the indri runner advertises `priv` — that was stale; the dedicated Phase-2 runner had already landed.
- Fixed `mise run services-check`'s "Local services on indri" leg to `ssh
  erichblume@indri` instead of bare `ssh indri` — the bare form relies on a
  local-username mapping that only exists on gilbert, so it fails with
  `tailscale: failed to look up local user` when run from ringtail (indri's
  account is `erichblume`, not the caller's username).
- ringtail: `WLR_NO_HARDWARE_CURSORS=1` now actually reaches the sway session.
  It had been configured via `programs.sway.extraSessionCommands` since
  2026-02-18 and never applied — the running sway is home-manager's
  `wayland.windowManager.sway` build, which never executes the NixOS module's
  session wrapper. Moved to `environment.variables`, the mechanism the
  `MOZ_ENABLE_WAYLAND` workaround already proved reaches the session.
- `TextfileStale` no longer goes pending every hour. Its threshold was 3600s
  while `borgmatic.prom` is written by an hourly LaunchAgent — the alert's
  threshold and the file's refresh period were the same number, so ordinary
  scheduling jitter made it "stale" once per hour, every hour. Raised to 2h; the
  other five textfiles refresh every 20-50s and lose nothing. Shortening the
  exporter's interval was the other option and was rejected: it calls `borg info`
  over SSH to BorgBase, and doubling that collides with the separate
  connection-count concern.
- `verify-runs` now attributes approval tasks to runs by record instead of inference: warrant v0.3.4 serializes each request's `run_number`/`run_url` (captured at dispatch via `return_run_info`) in `GET /api/requests`, `request-run` stamps the warrant request id into the heph task, and the sweep closes tasks against exactly that run. The old matcher assumed a dispatched run's `head_sha` was the approved payload SHA — it's actually the main tip at dispatch time, so any request approved after main moved on (deploy-fly request #18, run 739) reported "not dispatched yet" forever. The forge-side heuristic remains only as a marked fallback for UI-dispatched runs.
- warrant v0.3.3: a warrant no longer names a CI run it did not cause. v0.3.2's
  `_find_run` retried only while the run list was *empty*, so for any workflow
  with history the first poll returned the newest **pre-existing** run —
  warrants #5 and #7 each asserted a run Erich never authorized. The dispatch
  now sends `return_run_info`, so the forge answers 201 naming the run it just
  created and there is nothing left to infer; a dispatch that comes back without
  one links the workflow's run list rather than guessing. Warrants also record
  `dispatched_at`, which makes a bad link detectable after the fact. First unit
  tests for the service, run with `mise run warrant-test`.
- `role:workflow-bot` can read ArgoCD projects. Without it `argocd app get` was
  denied, so the argocd-deploy workflow's closing "Report application state"
  step — the run's audit record — has been empty on every warrant-gated deploy
  (runs 713, 721, 732), hidden by the step's `|| true`.
- The agent-ws image gains `/usr/bin/env`, so `mise run <task>` works in the
  pod — the kernel resolves shebang interpreters literally, and every
  mise-task script uses `#!/usr/bin/env`. Tasks needing the blumeops vault are
  now tagged `[human]` in their descriptions, and AGENTS.md points agents at
  `agent-health` rather than the kubectl/ssh-bound `services-check`.
- The agent-repo-access CI secret is `FORGE_ADMIN_TOKEN`, not
  `FORGEJO_ADMIN_TOKEN`. Forgejo reserves the `FORGEJO_` prefix for the Actions
  tokens it injects itself and rejects creating a secret that uses it, so
  `provision-indri --tags forgejo_actions_secrets` failed with HTTP 400 on that one
  entry while the other five synced fine. The `cv` repo's `FORGE_TOKEN` was already
  the same workaround; the reason is now recorded in the role defaults so the name
  doesn't get "corrected" back.
- Fix navidrome 0.63.2 crash-loop: the Nix image ships no `/tmp`, so SQLite's
  large `bpm`/`bit_depth` migration failed with `disk I/O error: permission
  denied` (no writable temp dir for the statement journal). Mount an emptyDir at
  `/tmp` (paperless precedent) and switch the deployment to `Recreate` so the old
  pod never holds the SQLite DB while a new pod runs startup migrations.
- `mise run request-run` rejected every one of its own flags, so the invocation
  printed in `AGENTS.md` could not work.

  Its `#USAGE` block declared the two positional args and no flags. mise validates
  argv against that spec *before* the script runs, so `--pr`, `-i`, and `--why`
  died at `unexpected word: --pr` — and `--` does not bypass it. The flags existed
  in the typer signature below, and `./mise-tasks/request-run …` run directly
  worked fine, which is presumably why it went unnoticed: the documented path was
  the broken one. Found while filing the build request for agent-ws v0.14.0, which
  is the first requestable action an agent has had reason to file from the pod.

  Declaring the four flags fixes it. Two traps surfaced while doing so, both now
  written down in the script's docstring because neither is discoverable:

  - **The `#USAGE` block must be contiguous.** An ordinary comment line between
    two `#USAGE` lines truncates the spec — every later line is silently dropped,
    with no warning and no error. The first attempt at this fix put an
    explanatory comment above the new flags and reproduced the original bug
    exactly.
  - **Booleans are KDL v2**, so a repeatable flag needs `var=#true`. `var=true`
    fails to parse, and mise's fallback for an unparseable spec is to forward argv
    *unvalidated* — so the broken spelling appears to work, right up until the
    spec parses again and starts enforcing.

  Verified by running the documented invocation against a deliberately bogus
  workflow name: it now reaches `enforce_policy` and is refused there
  (`.forgejo/workflows/zz-not-a-workflow.yaml does not exist on main`) rather than
  dying in the argument parser, and nothing is filed. A scan of the rest of
  `mise-tasks/` found no other task with either defect.
- argocd-deploy maiden-run fixes: unset Forgejo's injected `GITHUB_TOKEN`
  before `mise x` (it 401s against api.github.com), pre-install `argocd@3.3.12`
  as a runner host tool, and list declared Applications when the `app` input
  doesn't match (most carry a `-ringtail` suffix).
- `warrant-bot-provision`: user creation needs `write:admin`, which the stored
  forge token deliberately lacks. Adds `--token` for an ephemeral admin token
  (never stored), mints the bot's PAT **as the bot** over basic auth (no admin
  scope for that step), and prints the exact remediation on 403.
- `warrant-bot-provision`: generate the bot's login password in-process and
  store it beside the PAT in one `blumeops-ci` item (the two-item dance had a
  read-after-create failure mode), and surface `op`'s own error text instead of
  a bare CalledProcessError.
- The dispatch token belongs in the `blumeops` vault: 1Password Connect (and
  so external-secrets) is scoped to that vault alone, while `blumeops-ci` is
  for CI job-time `op read`. Also: `/healthz` now reports
  `armed | armed-no-token | disarmed`, so a missing token is visible instead
  of masquerading as "disabled".
- warrant v0.2.2: decision forms gain the note field the API always accepted,
  notes surface in the warrants table, and deny sits left of approve so the
  destructive-by-default ordering matches the design. Module docstring
  refreshed to describe v0.2.
- ArgoCD `workflow-bot` RBAC gains `applications update` so the argocd-deploy
  workflow can `app set --revision`. Pairs with re-minting its stale token —
  the provisioned `ARGOCD_AUTH_TOKEN` was signed by the retired minikube-era
  ArgoCD and fails on the ringtail instance (`token signature is invalid`).
- Fix the silently-skipped `agents-m2m` blueprint entry: the OAuth2 provider
  needs `redirect_uris` even for a pure client_credentials flow (discovery
  404'd; every working provider in the file has one). Placeholder points at
  Warrant's future callback. Also aligns the service account with the zot-ci
  shape (`is_active` instead of `path`).
- authentik m2m round 2: the client_credentials flow authenticates a specific
  service account via username + **app password** (issuing the token as
  `agent-ringtail`, groups claim included); the bare client_secret-only
  variant hits the app's `agents-sa` policy binding as a foreign auto-SA →
  `invalid_grant`. Adds a vault-fed app-password token to the blueprint.
- warrant v0.2.1: `/auth/callback` 500'd — `httpx` was lazily imported and
  missing from the image (smoke tests masked it). Now a top-level import
  (missing deps fail at boot, not first login) and in the nix package set.

### Infrastructure

- ArgoCD workload applications now sync automatically on merge to `main`
  (`prune` and `selfHeal` both off). A merge reaches the cluster without a
  separate sync step; `git revert` becomes a real rollback. The `apps`
  app-of-apps, ArgoCD's self-management app, and the two apps tracking mutable
  mirror tags stay manual.
- Begin migrating the ringtail-agent workspace from a shared-host OS user to a k3s pod with its own Tailscale identity (`tag:agent`), closing the device-trust hole that let the agent user `ssh erichblume@indri`. This PR lands the identity foundation — `tag:agent` tagOwner, a fenced egress grant (forge + heph only, no OS SSH), and ACL tests — plus the [[agent-containerization]] design doc. No behavior change until the pod ships.
- Bump mealie v3.16.0 -> v3.20.1 (bump-with-review to what nixos-unstable
  currently carries; no DB/schema breaking changes, SQLite continues to
  auto-migrate forward via init_db) and miniflux 2.3.1 -> 2.3.2 (converted to
  the same nixos-unstable self-pin as mealie/navidrome, since stable
  nixos-25.11 is EOL; 2.3.2 is a security patch preventing username
  enumeration via login timing).
- agent-ws 0.15.0: `nix` in the pod, deliberately eval-only. Its store, state and log dirs are relocated onto the PVC (`~/.local/state/nix`), which needs no root, daemon, namespace or capability — enough for `nix-instantiate`/`nix eval` and the evaluator-side fetchers (`nix-prefetch-url`), and structurally incapable of a useful build, since a relocated `store-dir` can never hit `cache.nixos.org` (`max-jobs = 0` makes that a clean error). Restores what containerization silently dropped: Nix changes to `nixos/ringtail/` and `containers/*/default.nix` no longer reach a human with their syntax unchecked. The store is pure cache — nothing in the pod creates a GC root — so `agent-ws-workspace gc` sweeps it on size (above 6 GiB it collects and clears `~/.cache/nix`, which the collector does not touch). The agent container's memory limit goes 4Gi → 6Gi to fit a full NixOS evaluation alongside claude.
- Retire the host-level agent workspace now that the agent runs as a k3s pod ([[agent-containerization]]): `nixos/ringtail/agent-workspaces.nix` → `agent-heph-spoke.nix`, slimmed to just the `agent` user + its heph spoke (the workspace/remote-control/repo machinery and the unused Forgejo bot SSH key are gone; the heph spoke stays as the shared daemon the pod mounts). Also add a PVC-chown initContainer to the agent-ws Deployment so HOME ownership holds on a fresh volume without a manual chown, and bake a default `PATH` into the image (image v0.9.0).
- Remove the Mikado apparatus: the `mikado-branch-invariant-check` commit-msg
  hook, the `docs-mikado` viewer, the `mikado-navigator` subagent, and the
  `C2(<chain>):` commit convention. No chain was using it — canonical carried no
  `mikado/*` branch and no card with Mikado frontmatter. Multi-phase work is now
  just a branch and a PR.
- Renamed the `k8s` compat label on the indri Forgejo runner to the honest
  `indri` label across all 6 workflows that used it (`runs-on: k8s` →
  `runs-on: indri`), removed `k8s` from `forgejo_runner_labels` in the
  `forgejo_runner` ansible role, and updated the docs that described the old
  label as current state. The `nix-container-builder` runner is untouched.
- `deploy-fly.yaml` is now a warrant-requestable privileged workflow: `workflow_dispatch`-only with a SHA-bound `revision` input, `runs-on: priv`, and a `warrant-policy.yaml` entry. The push-to-main auto-deploy trigger on `fly/**` is removed — merging no longer deploys the proxy; a human dispatch, gilbert's `mise run fly-deploy`, or an approved `mise run request-run deploy-fly.yaml …` does.
- agent-ws: cut zombie-detection latency from ~10min to ~3min by moving boot
  grace into a `startupProbe` (up to 20min for cold-PVC boots) and tightening
  the `agent-ws-health` livenessProbe to 30s × 6 failures. The 2026-08-06
  incident confirmed the detector fires correctly, but the old window was long
  enough that the workspace read as "offline" in the Claude app before kubelet
  recycled it.
- `gamedev` joins the agent workspace pool, with the native libraries it actually
  needs to build.

  The repo was already granted (`access: write`) but held at `pool: none`, so it
  had no checkout in the pod. Flipping it to `canonical` is the one-line half.
  The other half is that containerization silently dropped Bevy's Linux native
  deps: the retired host launcher exported `PKG_CONFIG_PATH` and `LD_LIBRARY_PATH`
  over them, and `containers/agent-ws/` was never given the equivalent. So
  `gamedev` would have arrived as a checkout that could not be compiled.

  Verified from inside the pod rather than reasoned about, which is what caught
  the interesting part. A mise-provided `rust@stable` builds and links an ordinary
  crate fine; `mise run check` on gamedev fails in a `-sys` build script. But it
  fails on **`wayland-sys`**, not only `alsa-sys` — and the host file's comment
  asserted that every windowing library was `dlopen`'d at run time and therefore
  needed nothing at build time. That was wrong for this dependency set. Porting
  the host's `gameBuildDeps`/`gameLibs` split verbatim would have shipped a fix
  that still did not build.

  So `PKG_CONFIG_PATH` now carries the dev output of the *whole* `gameLibs` set
  rather than a hand-picked subset, with the runtime libs on `LD_LIBRARY_PATH` as
  before. A `.pc` file no build script asks for costs nothing; a missing one is a
  hard failure, and which crates probe at build time is a property of Bevy's
  feature flags that will drift.

  Rust itself stays out of the image, and that is now confirmed rather than
  assumed: `mise install rust@stable` works in the pod (the `ldLibs` loader shim
  was already sized for it), installs to `~/.cargo/bin` on the PVC so it survives
  restarts, and `gamedev`'s own `mise.toml` pins `rust = "stable"` — so
  `mise run check` provisions its own toolchain.

  This lets an agent `cargo check`/`build` the Bevy workspace to verify its work.
  It does **not** make the pod able to *run* a windowed Bevy app — no GPU, no
  display — so playtesting stays a human job, consistent with the
  timberborn-parsimony rule.

  Image toolchain version 0.11.0 → 0.12.0.
- Add `containers/agent-ws/default.nix` — the dockerTools image for the containerized agent workspace (step 2 of [[agent-containerization]]). Carries the curated toolchain (op, git, tea, mise/uv/pandoc/typst/weasyprint, the CLI + build tools); `claude` self-installs at pod-start onto the PVC rather than being baked in. Symlinks the glibc loader so prebuilt ELF binaries run in the non-FHS image. No deployment yet — manifests follow once pod egress identity is proven on-box.
- agent-ws 0.11.0: liveness watchdog for Remote Control zombies — an exec probe
  (`agent-ws-health`) restarts the agent container when no claude process holds
  an established TCP connection, catching the survived-a-WAN-blip-but-never-
  reconnected failure mode from the 2026-08-01 outage.
- Deploy the containerized agent workspace (step 3 of [[agent-containerization]]): a `tag:agent` Tailscale auth key (Pulumi), and the `agent-ws` k8s manifests — Deployment with a userspace Tailscale sidecar for own-identity egress, restricted ServiceAccount, PVC, Secrets, and a NetworkPolicy that forces forge/heph traffic through the sidecar (closing the node-NAT egress trap). Also gives the image an internal schema version so the Build Container workflow can tag it.
- Which repos the `agents` bot may touch is now **declared, not clicked**.
  `containers/agent-ws/repos.json` is one file driving both halves of "share a
  repo with the agent": the forge collaborator grant (reconciled by
  `mise run agent-repo-access`, wired to the new **Agent Repo Access** workflow)
  and the pod's clone loop (`default.nix` reads the same file via
  `builtins.fromJSON`). `myeve` and `timberborn-parsimony` join the pool.

  Those were previously two independent manual steps, and skipping the grant fails
  invisibly: Forgejo answers **404, not 403**, for a private repo the caller cannot
  see, and the clone loop is deliberately non-fatal (one unreachable repo must not
  crashloop the workspace) — so a missing grant is indistinguishable from a typo,
  and the only symptom is a directory that never appears. `timberborn-parsimony`
  was documented as a sibling checkout for three weeks while being absent for
  exactly this reason.

  Reconcile is authoritative: a repo absent from the file has its collaboration
  removed, and the workflow's PR job runs `--check` so revocations are visible in
  review before the merge that applies them. `blumeops` and `agents` are pinned
  read-only by an invariant in the reconciler that the data file cannot override —
  their read-only-on-canonical status is what keeps blumeops CI and its
  deploy-credentialed Actions secrets out of agent reach, and a fence like that
  should not be flippable by a one-line edit to a config file.

  The reconciler's admin credential reaches CI the established way — declared in
  the `forgejo_actions_secrets` ansible role and pushed by a human with
  `mise run provision-indri -- --tags forgejo_actions_secrets`, reusing the
  `eblume` PAT that role already authenticates with. That human step is the point:
  the `agents` vault is the agent's, the blumeops vault is privileged, and Forgejo
  Actions secrets are the curated subset a human deliberately moves across.

  Image toolchain version 0.9.0 → 0.10.0.
- Wire the `blumeops-ci` vault tier into CI: the read-only
  `blumeops-ci-reader` service-account token provisions into Forgejo Actions
  as `BLUMEOPS_CI_OP_TOKEN` ([[warrant-approval-gated-runs]] Phase 2).
  The vault starts empty; items migrate via per-workflow audit.
- EVE Online game state now publishes itself into heph. An hourly systemd **user**
  timer on ringtail (`nixos/ringtail/myeve-heph-sync.nix`) runs the MyEVE sync,
  filing PI extractor expiry, undelivered industry jobs, skill-queue exhaustion and
  undercut market orders as tasks under the MyEVE project — and closing them again
  when the game state resolves. The motivating case: a manufacturing job finished
  2026-07-18 and sat undelivered for 12 days because nothing surfaced it.

  User scope is load-bearing, the same constraint as the eblume heph spoke — the
  sync shells out to `heph`, which needs `XDG_RUNTIME_DIR` to find `hephd.sock`. A
  system service would bind the `~/.local/share` fallback and never meet the spoke.
  The unit skips cleanly when the CLI, the myeve checkout, the ESI token or the
  socket is missing, and fails loudly only when the ESI refresh token is revoked.

  The sync logic lives in the myeve repo and gained matching fixes: reconciliation
  is now keyed purely on the `myeve-key:` line in each task's context doc, with the
  heph store as the only state. The local cache file it used to depend on could be
  lost, and when it was, every live chore looked new — duplicates filed, originals
  stranded beyond the reach of the closer. Two further bugs fell out: a collector
  that raised had its live chores closed as if resolved (one flaky ESI call could
  close "deliver your finished job"), and `--only pi` closed every non-PI chore.
  Both now scope closing to the collectors that actually ran.
- Each Remote Control session now gets its own worktree of every pooled repo,
  and the pool itself is kept pinned to canonical `main`.

  Only the `agents` repo had per-session isolation, because that is all
  `claude remote-control --spawn worktree` does — it operates on its own cwd repo
  and nothing else. The other seven pooled repos were one shared checkout each, so
  two concurrent sessions editing blumeops contended for one HEAD and one index.
  The only thing preventing that was a paragraph in the agents repo's `AGENTS.md`
  telling sessions to branch first, and the evidence that it is load-bearing is
  already on the PVC: two prior sessions had hand-rolled their own blumeops
  worktrees, by two different methods, one detached and one on a branch.

  `agent-ws-workspace` (new, generated from `repos.json` like the clone loop) has
  three verbs. `init` is a `SessionStart` hook and gives the session a detached
  worktree of each repo at `~/code/sessions/<session-id>/<repo>`. `sync` fetches
  and fast-forwards each pool checkout onto canonical `main`. `gc` reaps the
  worktrees of sessions that have ended. `sync` and `gc` also run once at pod boot.

  Worktrees rather than clones: they share the object store, and they enforce
  one-branch-one-checkout *in git* rather than by convention. Measured cost is
  14 MB for all seven — the whole pool is 43 MB.

  Three things fell out of building it that were not the original goal:

  **Sessions were waking up stale.** The clone loop only fetches at pod boot, so
  `--spawn worktree` branches off whatever `main` was when the pod started. On a
  pod up for days that is visibly wrong in the one repo where it matters most:
  this change was authored from a session whose `agents` worktree — and therefore
  whose own base instructions — was two commits behind canonical. `init` now
  fast-forwards the session's `agents` worktree too, when it is clean.

  **A fork's `main` lies.** `origin` on `agents` and `blumeops` is the bot's fork,
  so `git status` says "up to date with origin/main" while canonical is 110 commits
  ahead. `sync` pushes canonical `main` onto the fork so that sentence means what
  it appears to mean and cross-repo PR diffs stay honest. Fast-forward only; a
  diverged fork is left alone and reported.

  **Nothing ever reaped worktrees.** Fourteen had accumulated since 2026-07-31.
  `gc` uses Remote Control's own worktree lock as the liveness signal, waits
  `AGENT_WS_GC_AGE_DAYS` (7) after the session goes quiet, and — the part worth
  reviewing — refuses to remove anything with a dirty tree or a commit canonical
  `main` does not already contain, reporting it instead. Losing an agent's
  unpushed work is worse than the disk. A crashed session would hold its lock
  forever, so a lock older than `AGENT_WS_GC_LOCK_MAX_DAYS` (30) is treated as
  dead.

  The hook is seeded into **user** settings (`~/.claude/settings.json`, jq-merged,
  re-written every boot) rather than committed to the agents repo as project
  settings, because project-scoped hooks prompt for trust on first use and there is
  nobody at a terminal in this pod. The image stays the source of truth for it,
  which is also what the agents repo's own "changing your own environment is a
  blumeops PR" rule asks for.

  `CARGO_TARGET_DIR` is now shared across every checkout. Without it, per-session
  worktrees each build Rust from cold — minutes for Bevy — and a `target/` per
  worktree per session fills a 20Gi PVC quickly. Cargo locks the directory, so
  concurrent builds serialize rather than corrupt each other.

  Verified in the pod rather than reasoned about: the script was extracted from the
  derivation and run against the real pool. `sync` is clean across all eight repos;
  `init` produces seven detached worktrees at canonical `main` and is idempotent;
  `gc` reaps a clean aged session and refuses an aged one carrying an unpushed
  commit.

  This is working-tree isolation, not a security boundary and not repository-level
  isolation — refs, remotes, config, and the object store all stay shared, and all
  sessions remain one process, one uid, one PVC. True per-session isolation means a
  pod per session, which the RWO PVC and single rooted Remote Control server rule
  out today.

  Image toolchain version 0.13.0 → 0.14.0.
- Point the warrant manifest at the first built image
  (`v0.1.0-68f84a3-nix`, run 708) — replaces the UNBUILT placeholder.
- Fly proxy: Grafana Alloy v1.17.1 → v1.18.0. The v1.18.0 breaking changes are
  confined to `otelcol.*` components and `fly/alloy.river` uses none of them —
  only `local.file_match`, `loki.*`, and `prometheus.*` — so the upgrade is a
  no-op for our config. Deferred at the 2026-07-20 service review purely because
  the release was hours old and this is the public-facing edge; v1.18.0 has since
  stood 17 days as the head of the train with no patch behind it.
- Deploy warrant v0.3.3 — the dispatch asks the forge which run it created
  (`return_run_info`) instead of inferring it from the run list.
- Warrant image bumped to v0.3.4-8a18aed-nix (run-attribution serializer in GET /api/requests, PR #523; built by approved run 741).
- Deploy agent-ws 0.10.0 (`v0.10.0-55e2996-nix`) to the ringtail cluster.
- Deploy agent-ws 0.12.0 (`v0.12.0-47e7efd-nix`) to the ringtail cluster — the
  image carrying `gamedev` in the repo pool and Bevy's native build/run
  libraries.
- agent-ws 0.13.0 — the image version catches up with the `/usr/bin/env` fix
  that shipped in 0.12.0's source without a bump.
  The image also gains a `service-versions.yaml` entry, so `service-review`
  tracks it like every other first-party container.
- Deploy agent-ws v0.13.0 — `mise run <task>` works in the pod.
- Deploy agent-ws v0.14.0 — each Remote Control session gets its own worktree of
  every pooled repo, and the pool tracks canonical `main`.

  Built from f6b3274 (the merge of #499) as request #12, run 720. Tag confirmed
  present in the registry rather than derived from the naming convention —
  `container-list` reports no tags from inside the pod, since it has no route to
  `registry.ops.eblu.me`.

  First boot on this image does three things the previous one did not: seeds the
  `SessionStart` hook into `~/.claude/settings.json`, fast-forwards each pool
  checkout onto canonical `main` (including pushing the bot's fork `main` up to
  match), and reaps the fourteen session worktrees that have accumulated on the
  PVC since 2026-07-31 — skipping any that are dirty or hold a commit canonical
  `main` lacks.
- Pilot follow-up to #440: point mealie/miniflux manifests at the images
  actually built post-merge (`-892eeac-nix`) — the pre-bumped `-483b3d6-nix`
  tags referenced a branch SHA orphaned by the squash-merge (the last one:
  squash-merge is now disabled, so future approved SHAs survive merge).
- Service review: upgraded navidrome v0.61.1 → v0.63.2 by self-pinning the
  container's nixpkgs to nixos-unstable (mealie precedent — ringtail's stable
  25.11 nixpkgs lags at 0.61.1). Picks up the v0.62.0 security fixes
  (cross-account share disclosure, authorization checks, transcode-DoS cap)
  and the v0.63.x scanner/search overhaul. Sharing stays off
  (`ND_ENABLE_SHARING=false` pinned — v0.63.0 flips the default to enabled).
  The Build Container workflow now fails fast with a clear error when
  dispatched with a short commit SHA (actions/checkout treats those as
  branch names; see run #665).
- Warrant P0 chores: `agent-repo-access.yaml` moves off the retired `k8s`
  runner label (the one straggler added after #439 branched), and
  `policy.hujson` gains `sshTests` pinning two invariants — `tag:agent` has no
  Tailscale SSH anywhere, and the load-bearing homelab→homelab SSH (borgmatic's
  `ssh:eblume@ringtail` dumps, the rule PR #441 nearly removed) can't be
  dropped silently.
- Dedicated privileged runner ([[warrant-approval-gated-runs]] Phase 2):
  `ringtail-priv-runner`, a sandboxed NixOS DynamicUser instance carrying the
  `priv` label — privileged dispatch-only jobs move off host-mode
  `erichblume@indri`. The indri runner drops `priv`; argocd-deploy prefers the
  runner's nixpkgs `argocd` with a mise-x fallback.
- Deploy warrant v0.2.0 (`v0.2.0-9060183-nix`, run 709) — the human door +
  decisions/warrants go live.
- Deploy warrant v0.2.1 (`v0.2.1-14970b4-nix`) — the login-flow fix.
- Deploy warrant v0.3.0 (`v0.3.0-b87e4a2-nix`) — dispatch machinery present,
  still disabled.
- Deploy warrant v0.3.1 — dispatch reads the blumeops vault, and `/healthz`
  reports the arming state.
- Deploy warrant v0.3.2 — warrants link to the run they caused.

### Documentation

- Deployment docs describe the sync policy the fleet actually has. AGENTS.md
  called ArgoCD "manual sync" and prescribed `app set --revision main && app
  sync` after every merge; 31 of 35 applications sync themselves, so that step
  raced the auto-sync the merge had already started. `deploy-k8s-service`'s
  Application template also omitted `automated`, quietly making each new service
  a manual-sync exception.
- The observability replication tutorial had the three pillars wrong: it listed
  metrics, logs and **dashboards**, omitting traces entirely — despite Tempo,
  Beyla eBPF auto-instrumentation and full trace↔log↔metric correlation all being
  deployed. Corrected to metrics/logs/traces with collection and presentation as
  supporting layers, and added the two steps that were missing: deploying Tempo,
  and the privileged `alloy-tracing` DaemonSet that produces spans without
  instrumenting any application.
- Retire the post-merge container rebuild. Since canonical stopped squash-merging,
  a build from the PR branch head stays reachable from `main` after the merge, so
  its tag becomes `[main]` on its own. Build once from the final branch head and
  put the manifest tag bump in the same PR — no rebuild, no follow-up commit.
- The PodNotReady runbook told you to run `kubectl top` — which cannot work on
  ringtail, whose k3s runs `--disable=metrics-server`. Step 4 was a guaranteed
  dead end, reached exactly when someone is mid-incident chasing a Pending pod.
  Replaced with Prometheus queries (every metric verified to exist first), and
  noted why they are the better tool anyway: `Pending` is a question about
  requests versus allocatable, which utilisation numbers do not answer.
- Correct the Warrant doc's claim that Forgejo login is local and unprotected by
  Authentik MFA. The forge has been behind Authentik SSO with TOTP enforced since
  2026-02-20 (PR #228), so Phase 0's "enable WebAuthn on the forge account" item
  was satisfied before it was written, and dispatch-as-approval met invariant 4
  from the start.
- The blumeops-ci item-migration audit ([[blumeops-ci-item-migration]]):
  which Actions secrets migrate to job-time `op read` (argocd pilot first),
  the FORGE_ADMIN_TOKEN flag, and the verdict that wholesale `provision-*`
  never migrates — decomposition into narrow per-role actions is the path.
- Track the two user-facing heph installs in `service-versions.yaml`:
  `heph-cli-ringtail` (Erich's desktop spoke, pinned by `hephTag`) and
  `heph-cli-gilbert` (installed by hand, the only heph install not under IaC).
  Previously only the indri hub and the ringtail agent spoke were tracked, so a
  version review could never surface the CLIs Erich actually types at.

  `heph-cli-gilbert` starts with null `last-reviewed`/`current-version` — nothing
  asserts gilbert's version and the host was unreachable — which floats it to the
  top of the review queue, where an untracked install belongs. Documents the
  `type` values actually in use (the reference card listed neither `container` nor
  `manual`) and when null fields are the right answer.
- Rename the planned CI vault tier `ops-ci` → `blumeops-ci` before anything
  functional references it (docs, policy notes, and the future
  `BLUMEOPS_CI_OP_TOKEN` secret name).
- Proposal doc: [[warrant-approval-gated-runs]] — a phased design for
  agent-requested, human-approved privileged runs (request loop over
  dispatch-as-approval, `ops-ci` vault tier, dedicated privileged runner, and
  the Warrant broker), consolidating the agent-boundary program and disposing
  of open PRs #439/#440/#441.
- Documentation catches up with reality: the program doc reports built state
  with a per-phase table, the [[warrant]] service card describes v0.3.2 (flow,
  API, operating it, known gaps), [[request-a-privileged-run]] points approvals
  at Warrant rather than the forge UI, and `AGENTS.md` tells agents to file
  requests instead of asking in prose.
- Record the approval-factor decision: no hardware key on hand, so Warrant
  v0.2 ships with Authentik session + 1Password-managed TOTP as the step-up.
  Invariant 4 amended accordingly; the WebAuthn/hardware upgrade path is
  preserved structurally (decisions gate on an authentik flow slug, so
  hardware later = authentik config, not Warrant code).
- Retire the C0/C1/C2 change classification from the docs, matching AGENTS.md,
  which replaced it with a two-route split: direct to main for small interactive
  fixes, feature branch + PR for everything else and all remote-agent work.
  The `change-classifier` subagent, whose only job was the retired triage, is
  removed.
- Doc review: reviewed `reference/services/paperless.md` (never reviewed) —
  verified against the live manifests, added the missing ArgoCD app / sync
  policy / tracked-version rows, clarified that the "Redis" sidecar is the
  nix-built valkey image, and stamped `last-reviewed`. Also refreshed the
  stale Quick Reference in `reference/services/navidrome.md` (post-minikube
  app/manifest names) alongside the navidrome upgrade.
- Document UX7 diagnostic API read access (X-API-KEY endpoints), current Internal-zone firewall posture, and IoT SSID compatibility notes (Owlet base station onboarding) in the UniFi reference card.


## [v1.18.3] - 2026-07-21

### Features

- The ringtail agent workspaces now run a **heph spoke** synced to the indri hub, so agent sessions can use `heph` for task/context — heph is a deliberate in-boundary agentic-workflow substrate (distinct from the 1Password blumeops vault, which stays isolated). heph/hephd are cargo-installed at a pinned tag via a mise-resolved Rust toolchain (nixpkgs rustc lags heph's floor) by a `agent-heph-install` systemd oneshot; a `agent-heph-spoke` service runs `hephd` authenticating as a dedicated, independently-revocable `heph-agents` Authentik identity, with its OIDC token stored in the `agents` vault via hephd's command token store (no plaintext at rest). The indri hub authorizes that identity as a co-owner via `hephd --authorized-sub` (sourced from the vault). Requires heph ≥ v1.7.0.
- Stood up an "under construction" landing page at the apex `eblu.me` (and `www.eblu.me`) — a hi-I'm-Erich splash with the obligatory old-school hazard-barricade GIF and links to docs.eblu.me / forge.eblu.me. Unlike the other public sites, it's served straight from nginx on the Fly proxy (files baked into the image) rather than tunneled back to Caddy on indri, so the front door stays up even when indri or the tunnel is down. The apex uses `A`/`AAAA` records to Fly's ingress IPs (a `CNAME` is illegal at the zone apex); `www` is a normal `CNAME` like the rest.
- Stood up a private Factorio dedicated server on ringtail (`services.factorio`, UDP 34197), reachable at `factorio.ops.eblu.me`. It is BlumeOps' first externally-shared service: guests are *shared* onto ringtail (`autogroup:shared`) rather than invited as members, and the Tailscale ACL hands them exactly the one game port — they inherit none of the member-facing services.

### Bug Fixes

- Fixed flake input discovery in the dagger `flake-update` pipeline: nix cannot
  `readFile /dev/stdin` (it canonicalizes to a `/proc/.../pipe:[...]` path), so
  discovery had been silently empty since the pipeline was written, degenerating
  every run into a bare `nix flake update` of all inputs — the `nixpkgs-services`
  pin survived only because its URL is rev-pinned. Metadata now lands in a real
  file, stderr is no longer suppressed, and run 658's "refusing bare flake
  update" guard failure becomes a green no-op again.
- Fixed the Ringtail Flake Update workflow hanging in its summary step (`git
  log` spawned a pager on the runner; now `--no-pager`), and two latent bugs in
  the dagger `flake-update` pipeline: `skip_inputs` was never applied
  (single-quoted `$SKIP_INPUTS` never expanded, so a real update would have
  bumped the pinned `nixpkgs-services` input), and an empty discovered-input
  list now fails loudly instead of falling back to a bare `nix flake update`
  of everything.
- Changed `factorio.ops.eblu.me` from a pinned A record to a CNAME → `ringtail.tail8d86e.ts.net`. Tailscale remaps a shared node's `100.x` address inside each guest's tailnet, so the hardcoded owner-tailnet IP was unroutable for guests and the name timed out for them; the CNAME lets each client's own MagicDNS resolve ringtail to the address correct for its view.
- Firefox on ringtail now runs under XWayland (`MOZ_ENABLE_WAYLAND=0`), working
  around a hard deadlock that froze the whole browser. NVIDIA's Wayland EGL
  explicit-sync path can leave a DRM timeline fence unsignaled inside
  `eglSwapBuffers`, so the Renderer thread blocks forever in
  `drmSyncobjTimelineWait`; the Compositor thread then blocks in
  `WaitUntilPresentationFlushed`, and the main thread blocks behind a synchronous
  `SendFlushRendering` IPC issued while painting a popup. Painting any doorhanger,
  menu, or dropdown could trigger it, leaving Firefox wedged at 0% CPU until
  killed — the trigger that surfaced it was clicking "enable notifications", which
  is a repaint, not a network call. No Firefox pref or wlroots/sway toggle governs
  this path, and nixpkgs production/latest/beta were all pinned to the affected
  580.142 driver, so XWayland is the only lever until a newer driver ships.
- Pinned ringtail's Factorio headless server to 2.0.77 via a temporary `versionsJson` overlay so it matches the auto-updated Steam client (nixos-25.11 still ships 2.0.76). Remove the overlay once nixpkgs catches up.
- Restored the nightly indri borgmatic run, which had aborted since 2026-07-10.
  The multi-user hardening that locked `/etc/rancher/k3s/k3s.yaml` to `0600 root`
  on ringtail also locked out `eblume`, the user borgmatic's `before: configuration`
  k8s-dump hooks SSH in as to snapshot mealie/shower/navidrome — a non-zero hook
  exit aborts the whole run, so nothing landed. The hooks now reach the cluster
  via `sudo k3s kubectl`, keeping the kubeconfig locked away from the restricted
  web-agent user.
- `container-build-and-release` no longer fails spuriously: the Forgejo dispatch endpoint routinely holds the connection open past the read timeout even though the dispatch lands, which surfaced as an unhandled `ReadTimeout`. The POST timeout is now non-fatal — the task falls through to run verification (polling for the dispatched run) as the real source of truth, and only errors if no matching run appears.
- `eblume-heph-spoke` moved from a system unit to a systemd **user** service
  (with linger): as a system service hephd bound the `~/.local/share` fallback
  socket while interactive shells looked in `/run/user/1000`, so the `heph` CLI
  could never reach the daemon. Shared install machinery split into
  `mkInstallUnits` (heph-common.nix).
- `mise run services-check`: the `k3s` node-readiness probe now reads the cluster via `sudo k3s kubectl` instead of `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`. That kubeconfig went 0600 root-only when ringtail became a multi-user host, so the probe had been failing on permission (the cluster was healthy — `k3s-apiserver (remote)` and every pod/HTTP check passed). Same `sudo`-not-locked-kubeconfig pattern as the borgmatic dump hooks. Also tightened `grep -q Ready` → `grep -qw Ready` so a `NotReady` node can't false-pass on the substring.

### Infrastructure

- Agent workspaces: add a native build toolchain (`gcc`, `binutils`, `pkg-config`, `gnumake` + `CC=gcc`) to the session PATH so `cargo build` no longer dies with ``linker `cc` not found``, letting agents compile and verify Rust they author. Also expose the `gamedev` Bevy project's Linux native deps — `alsa`/`udev` on `PKG_CONFIG_PATH`, and the `dlopen`'d windowing/graphics libs (vulkan-loader, libxkbcommon, wayland, libGL, xorg) on `LD_LIBRARY_PATH`. Building/verifying works headlessly; running a windowed Bevy app still needs a GPU/display, so playtesting stays a human job.
- Ringtail now hosts **agent workspaces** — per-repo Claude Code Remote Control servers (hephaestus, blumeops, research, playground) run under an unprivileged `agent` user, steerable on demand from the Claude mobile app. Agents authenticate to 1Password only as a vault-scoped service account and push to Forgejo as a dedicated bot (never `main`). See `agent-workspaces` and the `bootstrap-agent-workspaces` runbook.
- Agent workspaces can now author blumeops: a read-write, agent-owned clone lands at `~agent/code/personal/blumeops` (pool-only, no dedicated server) so sessions can edit it and open PRs as the bot. Deploys stay gated — and to make that real, the k3s admin kubeconfig is locked from world-readable `0644` to `0600` (it previously handed the unprivileged `agent` user cluster-admin and an ArgoCD-admin deploy path).
- Agent workspaces collapsed from per-repo Remote Control servers
  (`ringtail-{hephaestus,research,playground,parsimony}`) to a single home-base
  session, `ringtail-agent`, rooted in the new [`agents`
  repo](https://forge.eblu.me/eblume/agents) whose `AGENTS.md` carries the base
  instructions (repo map, toolbox, execution environments). All other repos are
  sibling checkouts the session `cd`s into; the `playground` workspace is dropped
  (a home-base worktree is already a scratch space).

  Also: `heph` for Erich on ringtail — a second hephd spoke (`eblume-heph-spoke`,
  token-file store, logging in as Erich himself) alongside the agent's, with the
  shared version pin and install machinery extracted to
  `nixos/ringtail/heph-common.nix`.
- New `parsimony` agent workspace on ringtail for `timberborn-parsimony`, a
  Timberborn "Least Actions Challenge" mod. The remote agent builds the mod
  against the local game install's DLLs; playtesting (launching the game)
  remains a human-session step via the repo's `mise run playtest`.
- Agent workspaces: put the research report toolchain (mise, uv, pandoc, typst, weasyprint) on the session PATH, and expose WeasyPrint's native libraries via `LD_LIBRARY_PATH` so `mise run compile-report` renders a PDF on ringtail. Repo mise configs are pre-trusted to avoid interactive prompts.
- The `agents` bot now authors blumeops via a **fork** (`agents/blumeops`) with only **read** on the canonical repo, instead of pushing branches to `eblume/blumeops` with write. This closes a privilege-escalation path: `workflow_dispatch` is write-gated, so a write-access bot could have dispatched a branch workflow that reads blumeops' deploy-credentialed Actions secrets (`ARGOCD_AUTH_TOKEN`, `FLY_DEPLOY_TOKEN`, `ZOT_CI_API_KEY`, `MAIN_PUSH_TOKEN`) — Forgejo has no per-run approval gate for write users, so read-only + fork is the enforceable boundary. The ringtail agent-workspaces clone is repointed automatically (`origin` = fork, `upstream` = canonical); agents branch off `upstream/main` and open cross-repo PRs.
- Closed a [[borgmatic]] monitoring blind spot: the metrics collector never
  scraped the main BorgBase offsite repo (only `sifaka-local` and the immich
  photos repo were configured), so a failed offsite run produced no metric and no
  alert — BorgBase's own email was the only signal. Added the offsite repo to the
  collector and a `BorgmaticStale` Grafana alert (fires when any repo's newest
  archive is older than 30h, ~7h after a missed nightly run). The hourly per-repo
  poll stays metadata-only (`borg info`/`list`); the heavy per-source manifest
  listing is now skipped for remote repos to avoid pulling a 100k-entry file
  manifest over the internet every hour. Also corrected the metrics script's
  stale `/opt/homebrew/var/forgejo` source-path mapping to `~/forgejo`.
- Added `retries: 3` / `retry_wait: 300` to the [[borgmatic]] config so a transient
  failure on a single repository — e.g. a broken SSH pipe partway through a large
  offsite upload to BorgBase — is retried (resuming from borg's checkpoint) instead
  of losing that night's backup. Surfaced when PR #407 repointed the forgejo source
  from the empty `/opt/homebrew/var/forgejo` husk to the real ~8.8 GB tree: the
  first offsite run under the new config had ~6.7 GB of new deduplicated data to
  push, the pipe broke mid-transfer (borg exit 87), and the night's offsite backup
  failed with no retry. The dump hooks (`before: configuration`) are not re-run on
  retry.
- Agent workspaces can now open PRs and commit. Wired `tea` (with a login seeded from the agents vault), a `FORGEJO_TOKEN` for the pr/branch/runner mise tasks, and a git author/committer identity into the workspace launcher. The token is an **agents-owned** Forgejo PAT (scopes `write:repository` + `write:issue` — PRs are issues in Forgejo, so tea needs the issue scope — stored concealed as `agents-forgejo-token` in the agents vault) — structurally bounded to the repos agents collaborates on, with no blumeops-vault dependency. Also revoked the bot's leftover write on blumeops/project-template/adelaide-baby-shower-app.
- Disabled hephd's `--self-update` on the indri **heph hub** and put its version fully under IaC: `ansible/roles/heph` now converges the installed `hephd` to the pinned `heph_version` (`v1.7.0`) on every provision — installing, upgrading, or downgrading as the pin changes — instead of bootstrapping once and letting the daemon self-update. The `--self-update`/`--self-update-interval-secs` flags are gone from the launchagent, so no release lands on the hub until a human bumps the pin and re-provisions. The ringtail agent spoke was already pin-only (no self-update); gilbert's manual spoke gets documented steps to strip its self-update flags and pin its binary. See `hephaestus` (reference/services) for the release → deploy flow.
- blumeops `main` is branch-protected — a push + merge whitelist limited to `eblume` — so no write collaborator can merge a PR or push to `main`; human review/merge is the gate (the `agents` bot is separately read-only + fork, see the fork-model change). The release workflows (`build-blumeops`, `cv-deploy`) commit a version bump back to `main`, and because the automatic Forgejo Actions token can't be push-whitelisted (Forgejo [#11159](https://codeberg.org/forgejo/forgejo/issues/11159)) they now push with `MAIN_PUSH_TOKEN` — an `eblume`-owned PAT (`write:repository`) provisioned as an Actions secret via the `forgejo_actions_secrets` role. This supersedes the earlier "`main` is intentionally left unprotected against the bot" stance.
- Ringtail: the stray fish `ip` function (which curled ipinfo.io / checkip.amazonaws.com) was shadowing iproute2's real `ip`, so `ip addr`, `ip route`, etc. silently hit the network instead of running the command. Renamed it to `myip` and brought it under home-manager (`xdg.configFile`) so it can't drift back, and removed the shadowing `ip.fish` plus a broken (prettyping-less) `ping.fish` from the host.
- Dropped the **blumeops agent workspace** — remote workers are now hephaestus, research, and playground only. Real blumeops work needs the whole blumeops 1Password vault (its ansible `pre_tasks` and mise tasks `op read` broadly), and that vault is deliberately the operational-secret blast-radius boundary with no least-privilege subset to grant a service account — so blumeops stays a local-on-gilbert, biometric-`op` job. Also documented the deployment's **terms-of-use** footing (ordinary, individual usage; native-app OAuth). See `agent-workspaces` §"Why blumeops is not a workspace".
- Service review: reviewed the ringtail snowflake-proxy. Upstream is at 2.14.1 (2.12/2.13/2.14 released since), but nixos-25.11 is frozen at 2.11.0 and the `nixpkgs-services` pin is shared with k3s and forgejo-runner. As a minor anti-censorship service, it stays on the in-channel 2.11.0 build rather than mixing in an unstable channel; the version tracking now records the upstream gap.
- Service review: upgraded the ringtail forgejo-runner (`nix-container-builder`) from 12.7.2 to 12.11.1 via the `nixpkgs-services` pin, picking up the Go toolchain, `golang.org/x/sys`, and `go-git` security fixes released since 12.7.2. k3s and snowflake (sharing the pin) are unchanged.
- Service review: reviewed k3s on ringtail (most stale, 94d). nixos-25.11 is frozen at the deployed 1.34.5+k3s1 (no `k3s_1_35`/`k3s_1_36` attrs; unstable has 1.35.6, upstream latest 1.36.2), so it stays on the in-channel build rather than channel-mixing; the upstream 1.34.9 patch gap (klipper-helm CVE bump, containerd fixes) is recorded in version tracking. Cluster verified healthy. Also ran the weekly ringtail flake.lock update: nixpkgs `3cac626` → `b6018f8` (nixos-25.11); disko/home-manager already current, `nixpkgs-services` pin held.
- Service review: reviewed tempo (most stale, 96d). Upgraded the home-built container 2.10.3 → 2.10.7 — the 2.10.x patch line brings `golang.org/x/net` and `golang.org/x/crypto` security fixes; its one breaking change (OpenCensus receiver removal in 2.10.6) doesn't apply since the distributor only uses the OTLP receiver. The v2.10.6 Go-1.26 floor required overriding `buildGoModule`'s Go to `go_1_26`. Upstream 3.0.x is a major with breaking write-path/config changes and was deferred to a separate task. Also reviewed the weekly Prowler K8s CIS report (2026-07-05): all clear, 0 unmuted FAILs, net-zero week-over-week (1127 PASS / 53 muted).
- Service review (2026-07-13): reviewed the seven stalest ArgoCD services against upstream and actioned the three low-risk, self-contained bumps: **grafana** 12.4.2 → 12.4.5 (in-minor security CVEs — CVE-2026-9029/-33382/-42127; home-built `fetchurl` container rebuilt via CI), **argo-cd** v3.3.6 → v3.3.12 (in-minor, CVE-2026-41240 dompurify), and **ollama** 0.20.4 → 0.31.2 (upstream image tag). Deferred with heph follow-up tasks rather than stamping them reviewed: **miniflux** 2.3.2 and **navidrome** 0.63.2 (both bare-nixpkgs packages pinned to the deployed version — need a package override with recomputed hashes; navidrome also needs `EnableSharing=false`), **authentik** 2026.2.5 (from-source Nix build — sources + Go/Py/web vendorHashes; SSO blast radius), and **immich** v3.0.x (breaking major — pgvecto.rs dropped, DB migration). Their `last-reviewed` dates were intentionally left un-stamped so they resurface in the stale queue until actually upgraded.
- agent-workspaces: add a general CLI toolbox (`cliTools`: gawk, jq, curl, python3) to the ringtail agent-session PATH alongside the report toolchain. Plain shell agents constantly reach for `awk`/`jq`/`curl` and quick `python3` one-liners; without them sessions hit `command not found` or fall back to slower workarounds. All nixpkgs builds — declarative, no new `/run/current-system/sw/bin` exposure. `python3` is a bare interpreter (uv is already on PATH for `uv run --script`). Applied on the next `provision-ringtail`.
- Upgraded Immich v2.6.3 → v3.0.2 (server + machine-learning CUDA). The v3 breaking change (pgvecto.rs dropped for VectorChord) was already satisfied — ringtail's `immich-pg` runs `cloudnative-vectorchord:17-0.5.0` (vchord 0.5.0, pgvector 0.8.0), both inside v3.0.2's accepted ranges — so this was a clean tag bump plus immich's own startup migrations. Closes the v2.6.3 High-severity panorama-OCR stored XSS and the 2026-07-06 advisory cluster. A pre-upgrade `pg_dump` was taken as a rollback artifact, and post-upgrade a one-time Metadata Extraction re-run is pending (tracked in heph).
- Service review 2026-07-17 (remote-agent): **authentik 2026.2.2 → 2026.2.6**
  (most-stale service; latest patch on the current train — the 2026.5.x train
  jump is a separate follow-up). Source bump of the nix-built container via the
  Build Container CI dispatch with TOFU hash discovery; go vendorHash and the
  client-go pin carry over (go.mod/go.sum unchanged upstream). Also added a
  manual-dispatch **Ringtail Flake Update** workflow so remote-agent sessions
  can land `flake.lock` bumps via CI on a PR branch.
  Added a **Service Health** Grafana dashboard (`uid: service-health`, folder
  "Service Health"): degraded deployments/statefulsets, containers stuck
  waiting, restart counts, and scrape-target status — the read surface for
  agent post-deploy health checks (credential design for agent API access
  under discussion).
  Reworked `mise run runner-logs` to fetch job logs over the Forgejo web log
  route (`…/jobs/N/attempt/M/logs`) with the existing API token — no ssh to
  indri needed, so it now works from remote-agent sessions and while logs are
  still in dbfs. Also taught the Build Container workflow to post nix build
  failures (including TOFU hash mismatches) as PR comments.
- Service review (flyio-tailscale): reconciled tracking (the Fly proxy binary was bumped to v1.94.2 during the 2026-06-22 review but `service-versions.yaml` still read v1.94.1) and attempted the long-held jump to the 1.98 train. Deployed v1.98.8 to `blumeops-proxy` and tested MagicDNS inside the Firecracker container — it still `SERVFAIL`s tailnet names (`nslookup indri.tail8d86e.ts.net 100.100.100.100`) and blacked out all public routing (eblu.me/forge/cv → HTTP 000), the same failure mode as the original v1.96.5 regression. Rolled back to v1.94.2 in a few minutes; routing and MagicDNS verified restored. Notable: the 1.98 train is clean in k3s pods (PR #390) but NOT in the Fly no-DNS-manager container, so the pin stays on 1.94. Root cause (Fly container has no DNS manager, so tailscaled's split resolver isn't consulted) and the unblock path are tracked as a heph task.
- Fly proxy nginx base image bumped 1.30.3-alpine → 1.30.4-alpine (security
  release: CVE-2026-42533, CVE-2026-60005, CVE-2026-56434). Service review
  stamp for flyio-nginx; tracking entry corrected from stale 1.29.6.
- Service review: upgraded the Fly proxy's Grafana Alloy sidecar binary from
  v1.17.0 to v1.17.1 (digest-pinned), and corrected the stale `flyio-alloy`
  tracking entry in `service-versions.yaml`, which claimed v1.14.1 while the
  Dockerfile had been on v1.17.0.
- Agent workspace repos on ringtail now clone to `~/code/personal/<repo>` (was `~/workspaces/<name>/<repo>`), so the paths agents read in every `AGENTS.md`/`CLAUDE.md` resolve on the agent box. Remote Control session names (`ringtail-<name>`) are unchanged.
- Fly proxy deploys now work from any host: flyctl 0.4.71 pinned in mise.toml (was gilbert-only via brew).

### Documentation

- Doc review: verified the "Manage Ringtail Lockfile" how-to — dagger `flake-lock`/`flake-update` pipelines, the `prune-ringtail-generations` task, and its wiki-links all resolve against the current tooling. Stamped last-reviewed.
- Doc review: corrected the NVIDIA device plugin reference card — time-slicing is 4 replicas per GPU (not 2) and the deployed image tag (v0.19.2) is now recorded.
- Doc review: verified the QArt Tuner reference card against `utils/qart/` — CLI flags, web-UI parameter ranges, keyboard shortcuts, mise `serve` task, and the `rsc.io/qr` dependency all match the code; wiki-links resolve. Stamped last-reviewed.
- Doc review: verified the No Helm Policy explanation card against the live manifests — no Helm chart references remain anywhere under `argocd/`, 1Password Connect is plain rendered manifests, and ArgoCD and the Tailscale operator both pull pinned upstream manifests via `resources:` (forge mirror / raw GitHub) rather than charts. The migration-history table and "all services use kustomize" claim hold. No content changes; stamped last-reviewed.
- Doc review (2026-07-14): reviewed the never-reviewed Caddy reference card and corrected several stale entries — `cv`/`docs` are now served as static files from disk (not proxied to Tailscale endpoints), the retired minikube `5432 → pg.tail8d86e.ts.net` L4 route was replaced with the live `5433`/`5434` Postgres routes, and the proxied-service table was refreshed against `ansible/roles/caddy/defaults/main.yml`.
- Doc review: corrected the mealie reference card for the ringtail k3s migration — manifests path (`mealie/` → `mealie-ringtail/`) and storage class (`minikube-hostpath` → `local-path`). Service review: 1password-connect confirmed at upstream-latest 1.8.2 (Synced/Healthy), stamped reviewed.
- Doc review 2026-07-17: rewrote the stale ArgoCD `apps.md` registry card
  (post-minikube `-ringtail` app names, six missing apps, cv/forgejo-runner
  departures, manual-sync-everywhere policy). Documented the remote-agent
  variant of the service-review, doc-review, and flake-update runbooks, and
  retired C0/C1/C2 references from `review-documentation.md` to match the new
  AGENTS.md process.
- Doc review: verified the Zot service reference card. Fixed the stale pull-through-cache description — it referred to `[[cluster|minikube]]`, but the cluster has been k3s on ringtail since the 2026-06 migration. Confirmed the registry is healthy (registry.ops.eblu.me/v2/ → 200) and the namespace convention, security model, and API-key-rotation steps still match the deployment. Stamped last-reviewed.
- Doc review: tutorials/ai-assistance-guide.md — replaced the retired
  `minikube-indri` kubectl context guidance with `k3s-ringtail`, corrected the
  indri native-service list, and noted Jellyfin's LaunchAgent management.
- Doc review: reviewed `tutorials/exploring-the-docs.md` — replaced the stale
  reference to AGENTS.md's retired kubectl-context requirement with its current
  critical rule (public repo, no secrets), and stamped `last-reviewed`.
- Added the ringtail Factorio headless server to `service-versions.yaml` (nixos type, 2.0.77), documenting the temporary `versionsJson` overlay that pins it ahead of nixpkgs to match the Steam client — including how to bump the pin and the note to remove it once nixpkgs catches up.
- Forgejo reference: documented the consumers of the `api-token` PAT (ansible role, runner-logs, and — new — the tea CLI, which keeps a copy in its own config) so a future rotation updates all three. Context: tea 0.14.2's httpsign deadlock forced tea off SSH-signature auth and onto this shared PAT.
- run-1password-backup: note that the account-wide export now also covers the new `agents` vault (and that any newly-added vault is swept in automatically — the export has no per-vault selection). The `op-backup` script is vault-agnostic, so no code change was needed.


## [v1.18.1] - 2026-06-29

### Bug Fixes

- Restored the `argocd/manifests/1password-connect` and `argocd/manifests/external-secrets` base manifests that the minikube decommission (`a520f023`) deleted while leaving the `1password-connect-ringtail` and `external-secrets-ringtail` Applications still pointing at them. Both apps had been stuck in `ComparisonError` (ArgoCD could not generate their target state) ever since — the running pods stayed Healthy under Manual sync, so the breakage went unnoticed. The restored bases render images identical to what is live (`1password/connect-*:1.8.2`; `external-secrets:v2.2.0-13895bb-nix` via the ringtail overlay), so syncing is a no-op.
- Fixed all paperless-ngx document ingestion (API upload, consume folder, mail), broken since the Nix-image migration: the image ships no `/tmp`, so `SCRATCH_DIR` resolved to a nonexistent `/paperless`, and in the multi-container pod the scratch dir was not shared between the web container (which writes API uploads there) and the worker (which reads them). `PAPERLESS_SCRATCH_DIR` now points at a shared emptyDir, and a `/tmp` emptyDir keeps general temp usage off the container overlay.
- Fixed a silent backup gap: borgmatic was backing up the dead Homebrew-era forgejo path (`/opt/homebrew/var/forgejo`, frozen at 2026-04-06) while the live forge data at `/Users/erichblume/forgejo` — the 272MB DB and 8.8GB of git repositories — went uncaptured since the brew→source migration. Backups kept succeeding (the husk still existed), so no alarm fired. Now the live repos are in `source_directories` and `forgejo.db` is dumped WAL-safe via the online `.backup` API (it is WAL-mode); the raw db files are excluded to avoid torn copies. Verified a fresh archive captures the live 272MB DB + current repos.
- Added a `person` object-filter mask to the `gablecam` Frigate camera to stop a
  newly-planted Japanese maple (in the bottom-right planter) from being detected as
  a person and spamming alerts. The false detections scored 0.57–0.84 — overlapping
  real-person scores — so `min_score` couldn't filter them; the mask covers only the
  front-deck-stairs corner by the building. Trade-off: a person actually on the
  stairs no longer alerts, but should trip an alert as soon as they step off into
  the driveway. Mask region derived from the actual false-positive bounding boxes
  via the Frigate events API.
- Fixed duplicate homepage entries (DJ/Navidrome, Kiwix, Miniflux, ArgoCD,
  Grafana, Prometheus, Transmission) after [[retire-minikube]] — the static
  `services.yaml` entries that covered the formerly-invisible minikube services
  now collided with k8s Ingress annotation auto-discovery on ringtail. The
  annotations are the source of truth; the static duplicates are removed.
- Paperless-ngx: raised the Celery `worker` memory limit from 1Gi to 3Gi. The 1Gi cap introduced in the indri→ringtail migration OOMKilled OCR (`consume_file`) mid-import, stranding scanned uploads and freezing the auto-incrementing ASN at 46.
- Refreshed all stale ZIM torrent URLs in `kiwix-ringtail/torrents.txt`. kiwix only
  keeps the `.torrent` for the latest build of each ZIM, so the whole `_2026-01`
  devdocs section plus the `wikipedia_en_top1m_maxi_2025-09` entry had silently
  404'd — the kiwix sidecar could no longer add them to transmission. Bumped
  wikipedia to `2026-04` and every devdocs package to its current build (mostly
  `2026-04`, some `2026-05`); all 43 URLs now resolve 200. Added a note documenting
  the latest-only behavior so future 404s are an obvious date bump.
- Relaxed the `frigate` liveness probe (`timeoutSeconds: 10`, `failureThreshold: 5`;
  readiness `timeoutSeconds: 5`). The default 1s timeout / 3 failures was killing the
  pod with SIGTERM on transient API stalls — 206 graceful-shutdown restarts over 36d,
  never an OOM — whenever frigate's API thread blocked under detector/GPU load or NFS
  recording I/O. The pod now tolerates ~2.5min of unresponsiveness before a restart.

### Infrastructure

- Re-broadened the ringtail Alloy blackbox exporter from a single probe (`immich`) to
  all 18 in-cluster HTTP services (argocd, authentik, frigate, grafana, homepage,
  immich, kiwix, loki, mealie, miniflux, navidrome, ntfy, paperless, prometheus,
  shower, teslamate, tempo, transmission). Coverage had collapsed to immich-only
  during the minikube retirement, leaving the other services silently unmonitored —
  and `mise run services-check` was reporting a green "OK" for 10 of them because its
  `ServiceProbeFailure` check passes when no firing instance exists. Each health path
  was verified to return 2xx unauthenticated from inside the cluster; `shower` is
  probed with its `Host: shower.ops.eblu.me` header and `ollama` is intentionally
  excluded (scaled to zero on demand). The single `ServiceProbeFailure` alert covers
  every new target automatically via `label_replace` on the `integrations/blackbox/*`
  job label, so no new alert rules were needed. `services-check` was updated to mirror
  the probe list (no more false OKs) and to check indri/public services (forgejo, zot,
  devpi, cv) directly. Also swept stale post-minikube monitoring-host claims from the
  docs ([[runbook-service-probe-failure]], [[port-services-check-alerts]],
  [[federated-login]], the `tag:loki`/`tag:k8s-api` rows in [[tailscale]], and the
  prometheus textfile list).
- Migrated the [[borgmatic]] role's pre-backup database snapshot hooks from the
  deprecated `before_backup:` key to borgmatic 2.x's `commands:` syntax, clearing
  the `before_backup is deprecated` warning logged since borgmatic 2.1.4. Using
  `before: configuration` also stages the heph/mealie/shower/navidrome dumps
  **once per run** instead of once per repository — previously the two repos
  (sifaka + BorgBase) each re-ran every dump, harmless but redundant. The
  abort-on-failure guarantee (a non-zero hook aborts the whole backup, so a failed
  snapshot is never silent) is preserved.
- [[retire-minikube]] tail cleanup (follow-up): simplified the container build
  tooling to nix-only. `container-version-check` now validates each container's
  `default.nix` against `service-versions.yaml` (dropped the dead container.py
  `VERSION` / Dockerfile `ARG` rules), and `container-build-and-release` no longer
  carries dead container.py/Dockerfile classification. Stale build-model
  references purged from docs (forgejo, forgejo-runner, dagger tooling,
  grafana-image how-to, review-services, zot CI-auth) and the
  `build-container.yaml` workflow comment.
- Pruned the remaining dead `container.py`/`Dockerfile` build-model references
  left after [[retire-minikube]]. `container-list` and `service-review` mise tasks
  dropped their `has_container_py`/`has_dockerfile` classification branches (every
  container is now `containers/<name>/default.nix`), and the `upgrade-grafana` and
  `deploy-prowler` how-tos now point at the nix builds instead of the retired
  Dockerfiles.

  Also reconciled the CI runner/dagger docs with the phase-6 host-mode reality
  (jobs run directly on [[indri]] with the mise toolchain — no job container, no
  `runner-job-image`): rewrote [[upgrade-dagger]] around the mise-pinned host CLI,
  fixed the runner-environment section of the update-documentation how-to and the
  job model in [[configure-launchd-runner]], and deleted the obsolete
  configure-k8s-runner how-to (superseded by [[configure-launchd-runner]]),
  repointing its inbound links.
- [[retire-minikube]] tail cleanup: pruned the dead container-build framework.
  Removed the `build`, `publish`, and `container_version` Dagger functions (and
  the now-orphaned `containers.py` `container.py`-discovery module) — the
  Dockerfile/`docker_build()` and native-`container.py` build paths were retired
  when the minikube/arm64 runner went away, leaving nix as the only container
  build path. Updated [[dagger]] and [[build-container-image]] to document the
  nix-only reality.
- deploy-fly CI: provision `flyctl` on the host-mode runner via mise (`forgejo_runner_host_tools`) and drop the in-job `curl | sh` install, which hung indefinitely on an interactive PATH prompt on the macOS host runner (the install assumed an ephemeral minikube container). Workflow now calls `flyctl` directly, matching how every other host-mode job finds its tools.
- Declared AI crawlers (ClaudeBot, GPTBot, meta-externalagent, Amazonbot, …) now get a bare nginx 403 at the Fly edge before the Anubis proxy hop. Outcome of the 2026-06-11 scraper-surge review: these bots were ~88% of all forge.eblu.me traffic and their Anubis/naughty rejection pages were >99% of remaining proxy egress, enough to saturate the proxy VM under storms. Anubis is unchanged and still walls off UA-spoofing crawlers.
- Closed two backup gaps in the [[borgmatic]] role on [[indri]]. The
  [[hephaestus|heph]] hub DB (`heph.db`, the only copy of all task/context data)
  is now snapshotted by a before-backup `sqlite3 .backup` hook — WAL-safe and
  fails loud, unlike borgmatic's native `sqlite_databases` hook whose `.dump` can
  fail silently on a live WAL database. [[navidrome]]'s database (users, play
  counts, playlists) — a gap predating the ringtail migration — is now captured by
  enabling navidrome's own `ND_BACKUP_*` snapshots (`/data/backup`, daily 01:00,
  keep 7) and ferrying the newest snapshot off the PVC via a new
  `borgmatic_k8s_file_dumps` hook (`ls`/`cat` over `kubectl exec`); this added
  `coreutils` to the navidrome nix image for the in-pod tooling.
- Upgraded `authentik-redis` (Authentik's cache/broker) from Redis 8.2.3 to 8.6.3, rebuilt from nixpkgs on the nix-container-builder. The deployment has no persistence (ephemeral cache/broker), so the jump carries no data-migration risk. Also reviewed the `refactor-services-check-to-query-alerts` doc card and the most-stale service (`authentik-redis`) as part of the recurring maintenance sweep.
- ringtail: add zram swap (zstd, swappiness=10) as an OOM pressure valve and
  set k3s `--kubelet-arg=fail-swap-on=false`. Scale ollama to 0 replicas
  (on-demand) to drop its GPU contention and large memory tail. Relieves
  host-level OOM kills of k3s pods when gaming pushes memory over the top.
- Downgraded the security posture: kept the weekly Prowler K8s CIS hygiene scan
  but retired the kingfisher secret scanner entirely (ArgoCD app, manifests,
  custom container, prek hook, and the forge spork). TruffleHog remains the prek
  secret scanner. Also remediated the outstanding app-pod seccomp Prowler findings
  by adding `seccompProfile: RuntimeDefault` to the authentik (server/worker/redis)
  and frigate-notify pods rather than muting them.
- Tailscale operator stack: upgraded v1.94.2 → v1.98.5 (operator, proxy, and the
  new local k8s-nameserver), rebuilt from the forge mirror with the `go_1_26`
  buildGoModule override (v1.98.5 go.mod floor is >= 1.26.3). The in-cluster
  MagicDNS nameserver is now a local nix-built image
  (`containers/tailscale-k8s-nameserver/`), replacing the floating
  `docker.io/tailscale/k8s-nameserver:stable` tag — that mutable tag was the
  vector behind the v1.96.5 MagicDNS-in-containers regression.
- Upgraded kube-state-metrics v2.18.0 → v2.19.1 (service review) — nix container
  rebuild from the forge mirror, picking up Go-toolchain and golang.org/x CVE
  fixes plus the pprof auth-filter hardening from v2.19.0. Added a
  `RuntimeDefault` seccomp profile to its deployment, remediating one of the
  Prowler K8s CIS findings. Compliance triage of the weekly Prowler report (18
  unmuted, net-zero week-over-week) reworked the mutelist for the k3s finding
  profile: alloy node agents, the nvidia device plugin, local-path-provisioner,
  the k3s cloud-controller, and kube-apiserver node-proxy access are now muted as
  upstream-managed system/node-agent privileges. Remaining app-pod seccomp
  findings (authentik, frigate-notify) are tracked for RuntimeDefault remediation.
- Upgraded the [[homepage]] dashboard `v1.11.0` → `v1.13.2` (service review). Rebuilt the custom nix image from the forge mirror (src + pnpm-deps hashes re-resolved, full build verified on ringtail). The range adds the ntfy widget, UniFi Drive widget, qBittorrent v5.2.0 / dispatcharr v24 API compatibility, and the `GHSA-rg3r-jprv-xq38` security fix — no breaking config changes for our widget set.
- Service review: upgraded the CloudNativePG operator on ringtail from v1.27.1 to v1.29.1. The 1.27 series reached end-of-life upstream ("no longer supported"); 1.29.1 is the latest stable and carries a metrics-exporter privilege-escalation fix plus Go runtime CVE patches. Operand PostgreSQL stays at 18.3. Also corrected a stale `service-versions.yaml` entry (tracked 1.28.1 while the app deployed 1.27.1) and removed a dead minikube-sibling comment from the Application manifest.
- Upgraded Forgejo from v14.0.3 to v15.0.3 (major version) and made the forgejo Ansible role version-driven: `forgejo_version` (+ `forgejo_go_version`/`forgejo_node_version`/`forgejo_build_tags`) in the role defaults now pins the deployed tag, and the role fetches from the mirror, checks out, rebuilds when the running binary differs, and restarts. Bumping `forgejo_version` in a PR is now the whole upgrade — reproducible and DR-safe, closing the gap where the forge version lived only on indri's filesystem. Added an [[upgrade-forgejo]] runbook (build-from-mirror flow, go-toolchain pin requirement, v15 breaking changes, SQLite DB backup, rollback).
- Upgraded Loki 3.6.7 → 3.7.2 (service review). Breaking changes in 3.7 are
  confined to the experimental v2 engine/scheduler, which blumeops' single-binary
  deployment does not use.
- Monthly tooling dependency refresh: prek hooks (trufflehog v3.95.6, ruff v0.15.18, prettier v3.8.4, taplo SHA correction, ansible-core 2.21.1), Fly proxy images (nginx 1.30.3-alpine, alloy v1.17.0), mise-task `typer` pin 0.26.7, and `actions/checkout` v6.0.3 in Forgejo workflows.
- Daily recurring review pass (2026-06-18):
  - Service review of `frigate` (stalest, 86d): already at the latest upstream
    stable (0.17.1 — v0.17.1 is the newest GitHub release), pod healthy and
    serving the API. No upgrade needed; `last-reviewed` bumped in
    `service-versions.yaml`. Noted a high lifetime restart count (206 over 36d,
    last a graceful SIGTERM 3d ago, not an active crash loop) — filed a heph task
    to investigate.
  - Doc review of [[port-services-check-alerts]] (never reviewed): corrected the
    stale "blackbox exporter already covers 5 services" claim — the ringtail
    blackbox probe set is currently only `immich`
    (`argocd/manifests/alloy-ringtail/config.alloy`), so re-broadening it is now
    the most impactful next step. All wiki-links verified; set `last-reviewed`.
- Service review: bumped `blumeops-pg` PostgreSQL operand 18.3 → 18.4
  (ghcr.io/cloudnative-pg/postgresql), picking up the May 2026 security release
  (11 CVEs incl. CVE-2026-6473 buffer overruns and several SQL-injection fixes);
  18.x→18.x needs no dump/restore. Updated ringtail flake.lock (nixpkgs
  `d6df3513` → `3cac626e`, nixos-25.11; `nixpkgs-services` pin held) via
  `dagger call flake-update`.
- Daily recurring review pass (2026-06-17):
  - ntfy upgraded v2.19.2 → v2.24.0 (service review). Custom nix image rebuilt
    from the forge mirror; no breaking config changes across v2.20–v2.24 (S3
    attachment store, verified-email recipients, ACL access cache, SQLite
    case-sensitive ACL fix, PWA token auto-extend). Image tag bumped in
    `argocd/manifests/ntfy/kustomization.yaml`.
  - Doc review of [[first-alert-and-runbook]]: marked the alerting POC as
    complete/deployed and corrected the stale "5 probed services" claim —
    blackbox coverage is currently only `immich` (see [[port-services-check-alerts]]
    to re-expand).
- [[retire-minikube]] phase 6: the indri forgejo-runner flips to
  host-mode jobs (no more `runner-job-image`; jobs run as `erichblume`
  with the mise toolchain, which gains pinned `dagger` and `prek`).
  Scope revision: Docker Desktop stays as the dagger engine host
  (hephaestus/cv CI also use dagger), right-sized from 6cpu/8GiB to
  2cpu/4GiB. All stale arm64 build files deleted and
  `build-container.yaml` is nix-only.
- Added `uv` to ringtail's `systemPackages` for fast Python package and project management alongside the existing `mise` tooling.
- Enabled `systemd-oomd` swap-kill on ringtail (`ManagedOOMSwap=kill` on the root
  slice, `SwapUsedLimit=80%`). A Crusader Kings 3 spike filled zram swap to ~95% and
  froze the whole host in a multi-minute memory-pressure stall (PSI memory `full
  avg300≈30%`) — sshd and the k3s API included. oomd was running but monitored zero
  cgroups, so nothing got killed. Now oomd kills the heaviest-swap cgroup when swap
  crosses 80%; because k3s pods are pinned to no-swap (so kubepods hold ~0 swap vs
  the gaming session's ~15G), the victim is always a non-k3s process. Pod OOM
  remains the job of each pod's memory limit plus the kernel cgroup OOM-killer.
  Pressure-based root killing (`enableRootSlice`) was deliberately avoided — it
  selects by memory footprint and could reap a pod before the game.
- Pinned `sifaka` to its LAN IP (`192.168.1.203`) in ringtail's `/etc/hosts` via
  `networking.hosts`, so NFS mounts resolve over the LAN instead of tailscale
  MagicDNS. On 2026-06-26 sifaka's tailscale node key expired; MagicDNS kept
  resolving `sifaka` to the now-dead node and every NFS mount on ringtail hung
  (kiwix, transmission, immich, paperless, etc.). The LAN path is authoritative
  (`/etc/hosts` beats MagicDNS), keeps NFS traffic off the tailnet, and is immune
  to tailscale node-key churn — implementing the design the immich `pv-nfs.yaml`
  comment always described. sifaka's NFS export already permits `192.168.1.0/24`.
  Also disabled key expiry on sifaka's tailscale node so it stops expiring.
- Removed `librewolf` from ringtail's `systemPackages`. After the nixpkgs flake bump, nixpkgs marks `librewolf-151.0.2` insecure (unmaintained in nixpkgs, not a specific CVE), which blocked `nixos-rebuild`. Firefox remains the configured default browser; librewolf was a standalone extra.
- Removed the retired `minikube` entry from `service-versions.yaml` — minikube on
  indri was retired 2026-06 (see [[retire-minikube]]); the service-review staleness
  queue no longer lists a non-existent service.

### Documentation

- Corrected the `ServiceProbeFailure` runbook's Affected Services table: verified
  against live Prometheus that the Alloy blackbox exporter now probes only immich
  (`job=integrations/blackbox/immich`), so the table no longer lists the retired
  indri-era services (miniflux/kiwix/transmission/devpi/argocd). Added superseded
  notes to the historical zot version-sync/tagging design cards
  (pin-container-versions, add-container-version-sync-check,
  adopt-commit-based-container-tags) pointing at the nix-only reality.
- Condensed the `docs/how-to/zot/` cards, which were verbose mikado-chain
  leftovers. Merged the four overlapping container-versioning cards
  (pin-container-versions, add-container-version-sync-check,
  adopt-commit-based-container-tags, add-dagger-nix-build) into a single
  [[container-versioning]] card documenting the current nix-only model, and
  trimmed the zot-hardening cards ([[harden-zot-registry]],
  [[wire-ci-registry-auth]], [[register-zot-oidc-client]]) down to tight
  present-tense how-tos — dropping the `What Was Done` / `Verification` checklists
  and file-listing tables that read as project records rather than documentation.
- Doc review: purged retired-minikube references from the four alerting runbooks
  (service-probe-failure, postgres-unhealthy, pod-not-ready, textfile-stale) —
  `--context=minikube-indri` → `--context=k3s-ringtail`, "indri's minikube
  cluster" → "ringtail's k3s cluster", and minikube health checks → k3s-on-ringtail
  equivalents. Also corrected the textfile-stale collector table (dropped the dead
  `minikube.prom`, added the live `forgejo.prom` and `macos_power.prom`).
- Reframed the security docs away from compliance-program emulation: the
  `security` reference card was retitled "Security & Compliance" → "Security",
  dropped the PCI DSS / SOC 2 / ISO 27001 framework table, and now frames the
  Prowler scan as a hygiene check. Stale `minikube-indri` and
  `argocd/manifests/prowler/` paths corrected to ringtail /
  `prowler-ringtail/`. Spork docs note that kingfisher (the worked example) has
  been retired while the spork machinery stays for future sporks.
- Doc review: `deploy-infra-alerting` runbook updated — the services-check
  coverage table no longer references the retired minikube cluster (k3s on
  ringtail is the only cluster post-[[retire-minikube]]).
- Doc review: [[configure-grafana-alerting-pipeline]] accuracy pass — corrected
  the stale "Grafana and ntfy are on different clusters" rationale. Both now run
  on ringtail's k3s since the minikube retirement, so the cross-cluster Caddy
  workaround is no longer load-bearing (cluster-internal ntfy DNS is now a viable
  future simplification).
- Reviewed `runbook-argocd-out-of-sync.md` (never reviewed). Corrected the stale "30+ minutes" claim — the `ArgoCDAppOutOfSync` alert actually fires after a 5m `for:` window. Verified both wiki-links resolve and the alert is defined in `grafana-ringtail/alerting.yaml`. Set `last-reviewed: 2026-06-21`.
- Docs review: verified the [[snowflake-proxy]] reference card against the running service (`snowflake-proxy.service` active on ringtail, Prometheus metrics on :9999, v2.11.0 matching nixpkgs) and stamped it `last-reviewed: 2026-06-23`.
- Recurring reviews (2026-06-29): doc review of the Frigate service card (corrected stale image tag rc2 → 0.17.1-tensorrt, stamped reviewed); service review surfaced Forgejo (see infra entry); weekly Prowler K8s CIS compliance scan all-clear (0 unmuted FAILs, net-zero week-over-week).
- Doc review: stamped [[observability]] reference card as reviewed — all five
  component and seven alerting/runbook wiki-links resolve, and the Pyroscope
  (blocked on ringtail kernel sysctls) and Faro RUM (not deployed) future
  sections remain accurate.
- Doc review: automounter card updated for post-[[retire-minikube]] reality —
  consumers table now reflects NFS-direct ringtail workloads, adds the shower
  share, and flags vestigial mounts (music, torrents, frigate).
- Documented the [[flyio-proxy]] Tailscale node name drift (`flyio-proxy` →
  `flyio-proxy-1` → `-2`): caused by ephemeral microVM state with no persisted
  `/var/lib/tailscale`, benign because routing/ACLs are tag-based and offline
  nodes auto-GC. Recorded the Fly-volume fix and the decision not to apply it
  (volume anchors the otherwise stateless proxy to one host).
- [[manage-forgejo-mirrors]]: document that the old GitHub fine-grained PAT
  shows "Last used: never" even after weeks of active syncing (last-used
  tracking is unreliable for git-over-HTTPS), and add a `rate_limit` auth check
  as the reliable way to verify a rotated mirror PAT.

### AI Assistance

- Retired the "migrate every container to a locally built image" campaign. The reachable wins are done — all remaining upstream images (frigate's TensorRT build, immich's CUDA ML stack, the CloudNativePG PostgreSQL operands) are impractical to rebuild in Nix and stay on their upstream registries. AGENTS.md now frames local container builds as guidance for *new* services rather than a goal of universal localization, and the recurring "pick one non-local container and make it local" task has been dropped.

### Miscellaneous

- Pruned dead minikube-era entries from the Prowler mutelist (removed `apiserver.yaml`, `control-plane.yaml`, `manual-node-checks.yaml`; trimmed `core-pod-security.yaml`), leaving only entries that match live k3s resources. No change to scan output (0 unmuted FAILs).


## [v1.18.0] - 2026-06-11

### Bug Fixes

- Granted the `offline_access` scope on the Authentik `heph` OAuth2 provider so hephaestus spokes receive a durable 30-day refresh token. Previously the refresh token was session-bound, so spoke sync would silently fail with a `400 Bad Request` on the `refresh_token` grant once the Authentik session lapsed.
- Fixed the `tailscale-operator` and `tailscale-operator-ringtail` ArgoCD apps showing `Unknown` sync status. Their shared base kustomization fetched the upstream operator manifest from the public `forge.eblu.me/mirrors/...`, which the AI-scraper mitigation now black-holes (403). Pointed the remote resource at the tailnet host `forge.ops.eblu.me` instead, which the in-cluster repo-server can reach.
- Upgraded Jellyfin on indri from 10.11.6 to 10.11.11, picking up the security fixes in 10.11.7 (disclosed CVEs/GHSAs, flagged "upgrade immediately") and 10.11.10 (three further GHSAs). Noted the recurring gotcha in the service-versions tracking: after a `brew upgrade --cask jellyfin`, the re-quarantined `.app` makes the launchd-spawned process hang silently until the Gatekeeper first-launch dialog is approved on indri's GUI console — removing the quarantine xattr over SSH is blocked by macOS TCC.

### Infrastructure

- Deployed Anubis v1.25.0 (proof-of-work anti-scraper gateway) on the Fly.io
  proxy in front of forge.eblu.me, after an AWS-hosted crawler with no declared
  bot UA DoS'd Forgejo by walking the `/eblume/*` commit-history surface at
  ~5.7 req/s. Browsers clear one JS challenge per week; git and API clients
  pass through untouched; declared AI crawlers are denied. The tailnet path
  (forge.ops.eblu.me) is unaffected. Tier 2b of the AI scraper mitigation plan.
- Completed the external-secrets localization for the ringtail (amd64) cluster. The indri Dagger build (`container.py`) only produces an arm64 image; added `containers/external-secrets/default.nix` to build the amd64 variant on ringtail's nix-container-builder, and gave `external-secrets-ringtail` a thin kustomize overlay that reuses the shared manifest and points at the `-nix` image. Both clusters now run the locally-built external-secrets binary on their native architecture.
- Added the [[hephaestus]] (`heph`) sync hub to indri as a self-updating LaunchAgent managed by Ansible (`ansible/roles/heph`, tag `heph`). The hub runs `hephd --mode server` behind `heph.ops.eblu.me` (Caddy TLS), with self-update on a 10-minute interval and the heph-pwa mobile shell served from `--web-root`. Access is gated by a new Authentik device-code (RFC 8628) OIDC application. Indri is now the canonical hub; other devices (e.g. gilbert) attach as offline-capable spokes. The hub's store was seeded from gilbert via the data-safe Path A bring-up (copy store, reset `meta.origin`).
- Registered the heph-pwa redirect URIs (`https://heph.ops.eblu.me/`, plus `http://localhost:8787/` for dev) on the Authentik `heph` OAuth2 provider, enabling the PWA's new Authorization Code + PKCE "Login with Authentik" flow (and the token-endpoint CORS it needs). Pairs with hephaestus PR #9.
- Localized the external-secrets controller image. It now builds from the forge mirror via a native Dagger `container.py` (single `all_providers` static Go binary, faithful to upstream's `make build`) and is served from `registry.ops.eblu.me/blumeops/external-secrets` instead of `ghcr.io`, bringing another platform component under local supply-chain control.
- Localized the Tailscale operator stack: the k8s-operator image (both clusters) and the ProxyClass proxy image (indri, completing parity with ringtail) are now built from the forge mirror instead of pulled from Docker Hub.
- Phase 0 of [[retire-minikube]]: the forgejo-runner becomes a native macOS LaunchAgent on indri (new `forgejo_runner` ansible role), running jobs against Docker Desktop instead of a DinD sidecar in minikube. New runner identity `indri-runner` advertising both `k8s` (compat) and `indri` labels; zot registry mirror moves into Docker Desktop's daemon.json; runner logs ship to Loki via alloy.
- [[retire-minikube]] phase 1 complete: prowler migrated to ringtail k3s (Nix-built from nixpkgs at 5.12.3 — a step back from 5.23.0 until nixpkgs catches up; same cis_1.11_kubernetes framework). Weekly CIS scans now target ringtail, k3s-appropriate node mounts, trivy + the image/IaC Dockerfile retired.
- Retired the Prowler container-image CVE scan and IaC scan, keeping only the K8s CIS benchmark scan. The two retired scans generated tens of thousands of un-actioned, un-muted findings every week (~20,000 image findings and growing, mostly unpatchable upstream-image CVEs; ~650 systemic Trivy KSV pod-security warnings) — the weekly `mise run review-compliance-reports` re-surfaced them all as "action needed" though none were ever triaged. The K8s CIS scan is fully mutelisted and runs clean, so it stays. Removed the two CronJobs, the now-unused `trivyignore.yaml` mutelist, and the grouped-findings rendering in the review tool that existed solely for the high-volume scans.
- Upgraded Prometheus v3.10.0 → v3.12.0. Picks up fixes for stored XSS
  (CVE-2026-40179, GHSA-fw8g-cg8f-9j28) and remote-write/remote-read snappy
  decompression DoS (CVE-2026-42154), plus TSDB performance improvements. No
  breaking changes affect our deployment.
- [[retire-minikube]] phase 1 continued: navidrome migrated from minikube to ringtail k3s (Nix-built 0.61.1, exact version lift-and-shift; data PVC copied, music NFS remounted from sifaka).
- [[retire-minikube]] phase 4: ArgoCD self-migrated to ringtail k3s — the
  last workload off minikube. All 32 ringtail app destinations rewritten
  to in-cluster, the 13 minikube-only Application definitions deleted
  (their live workloads run unmanaged until phase 5), the argocd metrics
  job back in-cluster, and the admin password rotated on the fresh
  install. Minikube's ArgoCD is scaled to 0 as rollback.
- [[retire-minikube]] phase 2 groundwork: ringtail `blumeops-pg` gains a
  managed `authentik` role (password sourced from the same 1Password item
  the authentik app reads, so the cutover is only a `postgresql-host`
  flip), and borgmatic's authentik entry moves from port 5432 (minikube)
  to 5434 (ringtail). The authentik database itself is dump/restored at
  the cutover window per the plan card.
- [[retire-minikube]] phase 1 closed out: the seven parked minikube workloads (miniflux, navidrome, torrent, kiwix, unpoller, prowler, the k8s forgejo-runner) are decommissioned — ArgoCD apps cascade-deleted and manifests removed. All seven now serve from ringtail (or, for the runner, as a launchd service on indri). The miniflux database remains on minikube blumeops-pg untouched until the cluster itself retires in phase 2. Also restores the kiwix zim-hash `ignoreDifferences` that the ringtail app definition dropped in the port (the zim-watcher CronJob patches that annotation at runtime, so without it the app reads permanently OutOfSync).
- [[retire-minikube]] phase 5: minikube fully decommissioned. The 12
  remaining minikube manifest dirs deleted, ansible `minikube`/
  `minikube_metrics` roles removed, the Caddy L4 `:5432` route and its
  `.pgpass` line retired, `services-check` rewritten for the
  single-cluster world (ArgoCD app table now reads ringtail),
  `ensure-minikube-indri-kubectl-config` deleted, the compliance report
  tooling's minikube node-verification removed (k3s equivalent tracked in
  heph), tailnet tags `tag:k8s-api`/`tag:loki`/`tag:pg` swept from
  pulumi, and the docs sweep (AGENTS.md rule 2 inverted to k3s-ringtail,
  restart-indri/architecture/cluster/tailscale-operator/indri/
  disaster-recovery cards revised, rebuild-minikube-cluster deleted).
- [[retire-minikube]] phase 3 groundwork: Nix `default.nix` ports for the
  five LGTM-stack containers (prometheus v3.12.0 with the embedded mantine
  UI built from source, grafana 12.4.2 from the official release tarball,
  loki v3.6.7, tempo v2.10.3, grafana-sidecar 2.6.0), all build-verified
  on ringtail. Their Dockerfile/dagger build paths are retired. The
  `*-ringtail` manifests stage the move: prometheus-ringtail gains
  in-cluster CNPG metrics scrapes for both ringtail pg clusters
  (previously dark), alloy-k8s repoints to the external LGTM names and
  absorbs the argocd/kube-state-metrics scrapes, and the PVC data copies
  + cutover follow on this branch.
- Upgraded the nvidia-device-plugin on ringtail from v0.19.0 to v0.19.2 (upstream patch release: CDI/Tegra fixes and dependency bumps, no breaking changes for our manifest-based CDI + RuntimeClass setup).
- Bumped the indri heph hub to v1.2.1, which adds the hub `GET /config` endpoint and ships the heph-pwa **Login with Authentik** flow (Authorization Code + PKCE). Pairs with the Authentik `heph` provider redirect URIs registered earlier.
- Rebuilt all six migrated phase-1 service images from main (`-f386e2e-nix` tags) and repointed the ringtail deployments at them, closing out the branch-built artifacts.
- Rebuilt the external-secrets images off `main` and repointed both clusters to the stable main-sha tags (`v2.2.0-13895bb` arm64 / `v2.2.0-13895bb-nix` amd64), so the deployed images on indri and ringtail trace to the same `main` commit rather than earlier feature-branch builds.
- Rebuilt the locally-built external-secrets image from the `main` branch so the deployed tag (`v2.2.0-0e70a1b`) traces to a `main` commit rather than the now-merged feature branch, giving a stable provenance reference.
- Updated ringtail NixOS flake inputs (nixpkgs `nixos-25.11`, disko) to latest via `dagger call flake-update`.
- [[retire-minikube]] phase 3 close-out: the five LGTM images rebuilt
  from main (`-8b1f89e-nix`) and the ringtail apps repointed to them.

### Documentation

- Reviewed the five stalest documentation cards (argocd, authentik, grafana, unifi, plan-a-meal): brought ArgoCD's SSO/dual-cluster/sync-policy story up to date, expanded Authentik's blueprint and OIDC client inventory to all eight clients, fixed Grafana's TeslaMate datasource target and dashboard list, and noted UnPoller's locally-built image.
- Kick off the minikube retirement: umbrella migration plan ([[retire-minikube]]) to move all remaining k8s workloads (miniflux, navidrome, torrent, kiwix, unpoller, prowler, the LGTM observability stack, authentik's database, and ArgoCD itself) from indri/minikube to ringtail/k3s, convert the forgejo-runner to a native launchd service on indri, and decommission minikube.
- Reviewed four never-reviewed reference cards (`cluster`, `ntfy`, `tempo`, `alloy`) and corrected drift: minikube is now Kubernetes v1.35.0; ntfy, tempo, and alloy-k8s images are now locally-built `registry.ops.eblu.me/blumeops/*` nix containers (v2.19.2, v2.10.3, v1.16.0) rather than upstream Docker Hub; the Fly.io alloy binary is v1.16.1; and the ringtail workload list reflects the in-progress minikube→k3s migration.
- Corrected the 1Password backup how-to: the desktop app's export menu item is named after the account ("File > Export > Blume/Davis"), not "All Vaults". Verified an account export contains all four vaults (Private, blumeops, Payrix, Shared).
- Reviewed the tailscale-operator reference card: documented the dual indri/ringtail deployment, corrected the ArgoCD apps list, pinned the upstream version, and added the ProxyGroup Ingress `host:` caveat.
- [[retire-minikube]] phase 2 cutover complete: authentik now reads its
  database from ringtail `blumeops-pg` in-cluster (row-exact restore, SSO
  verified). Minikube `blumeops-pg` soaks idle until ~2026-06-18, then
  retires with cnpg, the Caddy L4 `:5432` route, and its `.pgpass` line.

### AI Assistance

- Retired the `ai-docs` mise task and its mandatory session-start rule: the concatenated docs corpus had grown to ~130K tokens, too large to ingest wholesale. Agents now start tasks by finding and reading the relevant docs (grep + wiki-links); `ai-sources` remains for opt-in deep codebase context. Also documented the full `heph` CLI task workflow (read, log, complete, create) in AGENTS.md.

### Miscellaneous

- Service review: AutoMounter on indri is current at 1.13.0 (App Store auto-updated from the tracked 1.11.0); all sifaka SMB mounts verified healthy. Fixed the stale tracking-file path shown by `mise run service-review`.


## [v1.17.0] - 2026-06-03

### Features

- Deploy the Adelaide / Heidi / Addie baby shower app — guest splash, raffle
  picker, and prize assignment console — on ringtail k3s with `shower.eblu.me`
  as the public entry and `shower.ops.eblu.me` as the tailnet admin host. App
  source: [`adelaide-baby-shower-app`](https://forge.eblu.me/eblume/adelaide-baby-shower-app).
- Deploy adelaide-baby-shower-app v1.1.0 to ringtail k3s. Replaces the
  boolean lock with a four-phase `ShowerState` (`pre_event` → `party` →
  `prizes_locked` → `event_locked`), adds an append-only "guest memories"
  panel where guests can leave photos and comments for the baby, and
  polishes the admin and QR views. Three Django migrations
  (`0009_shower_phase`, `0010_guest_memories`, `0011_book_description`)
  run automatically in the entrypoint against the SQLite PV. No config
  or env-var changes.

  Container build also gains a Forgejo-PyPI workaround: Forgejo's simple
  index returns absolute file URLs hardcoded to the public ROOT_URL
  (`forge.eblu.me`), which the Fly edge 403s on `/api/packages/*`. The
  wheel and sdist are now both pulled via direct `fetchurl` against
  `forge.ops.eblu.me` (tailnet-only) and the wheel is handed to pip as
  a local path.
- `review-compliance-reports` now also fetches and summarizes the weekly Prowler container-image and IaC scans (previously only the K8s CIS in-cluster scan was processed). For each scan it shows status counts, severity breakdown, week-over-week delta, and — for the high-volume image/IaC scans — top-N tables grouped by check ID and resource instead of per-finding listings.
- runner-logs now authenticates with Forgejo API token and auto-detects the repo from git remote. Job logs are fetched via SSH to indri (reading Forgejo's on-disk zstd log files) instead of the web endpoint, which doesn't support token auth for private repos.

### Bug Fixes

- Fix nightly borgmatic backups failing for 2 days. The shower SQLite
  dump hook referenced `kubectl --context=k3s-ringtail`, but indri's
  kubeconfig deliberately doesn't carry the ringtail credentials. The
  `before_backup` hook's failure aborted the entire run, taking out
  *both* the local sifaka repo and the BorgBase offsite. Replaced
  the inline-shell dump with a `~/bin/borgmatic-k8s-sqlite-dump`
  helper deployed by the ansible role. Each dump entry now declares a
  `target` of either `local:<context>` (mealie — kubectl uses indri's
  kubeconfig) or `ssh:<user@host>` (shower — ssh into ringtail and
  run `k3s kubectl` there, no indri-side kubeconfig needed; k3s.yaml
  on ringtail is mode 644 so no sudo required). Bytes stream back via
  `kubectl exec ... -- cat` rather than `kubectl cp`, since `kubectl
  cp` requires `tar` inside the pod and nix-built images like shower
  don't bundle it.
- Shower app container now bakes the wheel + Python deps into the image
  at build time via `buildPythonPackage` instead of pip-installing on
  first boot. Boots are deterministic and don't depend on forge PyPI
  being reachable from the pod. The `wheelHash` in
  `containers/shower/default.nix` is the sha256 sourced from the
  [forge PyPI simple index](https://forge.eblu.me/api/packages/eblume/pypi/simple/adelaide-baby-shower-app/);
  bumping the version means bumping that hash too.

  Borgmatic now covers the shower app: SQLite is dumped from the live
  pod via `kubectl exec` (mirroring the existing mealie entry, with
  `context: k3s-ringtail`), and the prize-photo media share is picked up
  through `/Volumes/shower` (sifaka SMB mount on indri, same pattern as
  `/Volumes/photos`).
- Disabled adaptive sync (VRR) on ringtail's DP-1 output. The OMEN 27i IPS panel pumps brightness when its refresh rate swings into the low VRR range during low-framerate content (e.g. game cutscenes), producing a flicker that worsened over a session until a reboot. Pinning the panel to a fixed 165Hz eliminates it.
- Fixed forge.eblu.me static assets (CSS, JS, images, fonts) not loading — the proxy's static asset cache block was missing the `Host` header, so Caddy couldn't route the requests.
- Fixed homepage container EACCES on cold start: the nix-built image now chowns
  `/app/config` to uid 1000 at build time via `fakeRootCommands`, matching the
  behavior of the old Dockerfile. Without this, homepage couldn't seed missing
  skeleton configs (proxmox.yaml etc.) or create `/app/config/logs`, crashing on
  its first uncached request. Caught during the ringtail cutover.
- Fixed sway keybindings on ringtail — the home-manager `keybindings` block was replacing the module's defaults entirely, leaving only explicit overrides (no workspace switching, focus, move, splits, resize mode, etc). Switched to `lib.mkOptionDefault` with `lib.mkForce` on the conflicting custom binds (`Mod+Return`, `Mod+d`, `Mod+space`, `Mod+l`) so defaults merge back in. Also added `Mod+F1` to show a filterable fuzzel list of current keybindings.

  Fixed fuzzel config errors on launch — `border-radius` and `border-width` were under `[main]`, but fuzzel expects them as `radius`/`width` under a `[border]` section.
- Pin the Quartz docs build to v4.5.2. The Dagger `build_docs` pipeline cloned Quartz from the default branch unpinned; Quartz v5.0.0 restructured its config layout (`.quartz/plugins`, `../quartz` imports) and broke the docs build against our existing `quartz.config.ts`/`quartz.layout.ts`.

### Infrastructure

- Wire the ringtail `blumeops-pg` cluster (which holds the wave-1-migrated
  paperless + teslamate databases) into backups and Grafana. Adds a Tailscale
  LoadBalancer Service (`blumeops-pg-ringtail.tail8d86e.ts.net`) and a Caddy L4
  route (`pg.ops.eblu.me:5434`), then repoints borgmatic's `teslamate` +
  `paperless` postgres dumps and the `mealie` SQLite dump at ringtail, and the
  Grafana TeslaMate datasource at the ringtail DB. Closes the backup gap that
  opened at cutover (the migrated live data was still being backed up from the
  now-frozen minikube copies) and unblocks the wave-1 decommission.
- Migrated homepage dashboard from minikube (indri/arm64) to k3s (ringtail/amd64).
  The container is now built via nix (`containers/homepage/default.nix`), adapted
  from nixpkgs `homepage-dashboard` with the upstream Next.js cache patches and
  wrapped with `dockerTools.buildLayeredImage`. Autodiscovery shifts: services on
  minikube (ArgoCD, Immich, Kiwix, Mealie, Miniflux, Grafana, Prometheus,
  Navidrome, Paperless, TeslaMate, Transmission) become explicit static entries
  in `services.yaml`; ringtail services (Authentik, Frigate/NVR, Ntfy, Ollama)
  auto-populate via Ingress annotations.
- Migrated CV (`cv.eblu.me`) and Docs (`docs.eblu.me`) from minikube Deployments to indri-native ansible roles. Caddy now serves the extracted release tarballs directly via a new `kind: static` service-block in the Caddy template — no daemon, no container — replacing the prior nginx-in-a-pod layer. Removes a network hop on every request and shrinks minikube's footprint. See [[cv-on-indri]] and [[docs-on-indri]]. Part of the broader minikube wind-down.
- Migrated devpi (PyPI mirror at `pypi.ops.eblu.me`) from a minikube StatefulSet to a launchd-managed service on indri. devpi-server now runs in a uv-managed venv with pinned `devpi-server` and `devpi-web` versions, listens on `127.0.0.1:3141`, and is fronted by Caddy. The minikube StatefulSet was crash-looping under memory pressure (and breaking the Python toolchain everywhere); the new layout removes a layer of dependency on cluster health for critical-path tooling. See [[devpi-on-indri]].
- Move the entire Immich stack — server, machine-learning, valkey,
  and the PostgreSQL+VectorChord cluster — off `minikube-indri` and
  onto `k3s-ringtail`. Postgres data migrated zero-loss via CNPG
  `pg_basebackup` (replica catch-up then promote); row counts on
  `asset`, `user`, `album`, `smart_search`, `activity`, `asset_face`
  verified equal between source and replica before cutover. The ML
  pod now uses ringtail's RTX 4080 via the nvidia-device-plugin
  (time-slicing bumped 2 → 4 to share with frigate + ollama). Caddy
  routing at `photos.ops.eblu.me` is unchanged (still
  `photos.tail8d86e.ts.net`, the device just lives on ringtail now).
  Borgmatic backups continue against the same `immich-pg` tailnet
  hostname. First concrete chain in the broader indri-k8s
  decommission effort.
- Add local nix container build for `tailscale` (`containers/tailscale/default.nix`) so ringtail's tailscale-operator ProxyClass proxy pods pull from the forge mirror instead of `docker.io/tailscale/tailscale`. Pinned at v1.94.2 to match `service-versions.yaml`. Indri's tailscale-operator continues to use upstream during the k8s-to-ringtail migration.
- Address the 6 critical Prowler IaC findings against `argocd/manifests/`. Prowler's IaC provider hardcodes `self._mutelist = None` and delegates filtering to Trivy, but doesn't plumb `--ignorefile` through — so the documented "use Trivy filtering" path is actually broken. Added a shim around `trivy` in the Prowler image that injects `--ignorefile $TRIVY_IGNOREFILE` for `trivy fs` invocations when the env var points at a real file. The IaC cronjob now mounts `mutelist/trivyignore.yaml` (Trivy's per-path schema) and sets the env var, muting the `external-secrets` and `kube-state-metrics` Secret-access findings (KSV-0041, KSV-0114). Separately, `grafana-clusterrole` is tightened to remove `secrets` access entirely: the dashboard sidecar already only consumes ConfigMap-labeled dashboards, so its `RESOURCE` env var is now `configmap` instead of `both`.
- Pin ringtail's wired IP to `192.168.1.21` via NixOS scripted networking; NetworkManager no longer manages `enp5s0`. Removes DHCP lease renewal as a failure mode after a silent lease teardown took ringtail offline. Also explicitly enables `net.ipv4.ip_forward` (previously set implicitly by scripted-DHCP) so k3s pod networking and Tailscale routing continue to work with static networking.
- Ripped out the compensating-controls (CC) framework: deleted `compensating-controls.yaml`, the `review-compensating-controls` mise task, and the associated how-to / explanation docs. Prowler and Kingfisher continue to run weekly and produce reports; the Prowler mutelist YAML files remain in place but no longer carry `CC: <id>` prefixes — each entry just keeps a free-form `Description` of why the finding is muted. The CC review cadence proved to be more overhead than this single-operator homelab needed.
- Wire shower app for public exposure: fly nginx `shower.eblu.me` server
  block as a guest-only surface — splash page, `/prizes/<token>/`, static
  assets, media. Everything authenticated (`/admin/`, `/host/`,
  `/accounts/`) returns 403 with a "tailnet only" pointer. Staff hit
  `shower.ops.eblu.me` for the operator console + admin; the app's
  v1.0.1 `DJANGO_PUBLIC_URL_BASE` setting makes QR codes generated on
  the tailnet point back at the WAN host for guests. Plus a Caddy route
  on indri, Pulumi Gandi CNAME, and a Grafana APM dashboard tracking
  request rate, error rate, latency, bandwidth, and access logs.
- Mirror Valkey 8.1 locally as `registry.ops.eblu.me/blumeops/valkey`. Replaces direct pulls of `docker.io/valkey/valkey:8.1-alpine` for paperless and immich sidecars. Built via native Dagger pipeline on Alpine 3.22. Stateless swap — no data migration. Authentik's nix-built Redis remains separate.
- Add nix-built amd64 valkey for ringtail (`containers/valkey/default.nix`) so immich-ringtail can stop pulling the upstream multi-arch `docker.io/valkey/valkey` image. Existing `container.py` continues to build Alpine arm64 for paperless on indri. Both bump to valkey 8.1.7 (Alpine 3.22 8.1.7-r0 / nixpkgs 8.1.7).
- Upgrade Grafana Alloy v1.14.0 → v1.16.0 across all four service deployments
  (alloy-k8s, alloy-ringtail, alloy-tracing-ringtail on k8s; alloy native on
  indri). Pulls in stable database observability (v1.15) and the OTel Collector
  v0.147.0 bump. Container build also migrated from Dockerfile to native Dagger
  `container.py` per the build-container-image migration playbook.
- Upgraded Dagger from v0.20.1 to v0.20.6 (engine, CLI pin, and SDK regen) and migrated `runner-job-image` from a Debian-based Dockerfile to a native Dagger `container.py` on Alpine 3.23, reusing the shared `alpine_runtime` helper.
- Decommission the wave-1 services on minikube-indri now that paperless,
  teslamate, and mealie run on ringtail with their data backed up. Removes the
  minikube `paperless`/`teslamate`/`mealie` manifest dirs + ArgoCD app
  definitions (pruning the parked Deployments, Services, and the redundant
  minikube mealie/paperless PVCs), and drops the `paperless`/`teslamate` roles
  from the minikube `blumeops-pg` cluster. The `paperless` and `teslamate`
  databases are dropped from indri's blumeops-pg as the finalization step.
  miniflux + authentik remain on the minikube cluster (later waves).
- Upgraded the k8s Forgejo runner to the v12.8 line, switched it from first-boot registration to declarative `server.connections` credentials from 1Password, and consolidated the supporting runner how-to documentation.
- Move paperless, teslamate, and mealie off `minikube-indri` onto
  `k3s-ringtail`, shedding ~1.1 GiB of resident load from the
  OOM-thrashing 8 GiB minikube node (the kernel OOM killer had been
  killing `kube-apiserver`/`dockerd`/argocd, flapping every
  minikube-hosted service at once). paperless + teslamate databases
  move into a fresh CNPG `blumeops-pg` cluster on ringtail via a cold
  `pg_dump`/`pg_restore` from the quiesced source — row counts verified
  equal before any routing flip; source DBs dropped only after the
  ringtail side serves traffic. mealie's SQLite PVC is copied as-is.
  paperless media stays on sifaka NFS. Downtime-tolerant cold cutover
  (no streaming replication); rollback is repoint-and-scale-up with the
  source untouched. Second chain in the indri-k8s decommission after
  [[migrate-immich-to-ringtail]].
- Recurring maintenance batch:

  - Ringtail flake inputs refreshed (`disko`, `home-manager`, `nixpkgs`).
  - Tooling deps bumped: prek hooks (trufflehog v3.95.3, kingfisher v1.101.0, ruff v0.15.14, `ansible-core` 2.21.0); fly proxy base images (nginx 1.30.1-alpine, alloy v1.16.1); `typer==0.26.2` in mise tasks.
- Updated `nixos/ringtail/flake.lock` (weekly cadence): `disko`, `home-manager`, and `nixpkgs` inputs refreshed. `nixpkgs-services` skipped per overlay convention.
- Reviewed `mealie` service version freshness; upstream is 5 minor versions ahead (v3.17.0 vs deployed v3.12.0). Marked reviewed; upgrade deferred.
- Deploy shower v1.1.2 — bump container build to new app release.
- Upgrade unpoller v2.34.0 → v3.2.0 and migrate container build from Dockerfile to native Dagger (container.py). v3.0.0 carries breaking UniFi API changes; v3.2.0 introduces a 60s background poll (cached scrapes) by default — set `interval = 0` in `up.conf` to restore on-demand polling.
- Monthly tooling dependency refresh: prek hooks (trufflehog, kingfisher, ruff, shfmt, prettier, actionlint, ansible-lint), fly proxy base images (nginx 1.30.0, tailscale v1.94.2, alloy v1.16.0), normalize pyyaml lower bound in mise-tasks.
- Add GE-Proton (`pkgs.proton-ge-bin`) to `programs.steam.extraCompatPackages`
  on ringtail. Subnautica 2 hangs at Mercuna plugin init under Proton
  Experimental + DXVK D3D12; GE-Proton is available as a Steam per-game
  compatibility option to work around it.
- Add `sn2-prelaunch` Steam launch wrapper on ringtail that removes
  Subnautica 2's stale `Saved/running.dat` and `Saved/beforelobby.dat`
  lockfiles before each launch. SN2 pops up an invisible (0×0-sized)
  Error dialog when it detects an unclean exit, blocking GameThread
  forever; this is observable only as a black screen with a spinning
  loader. Use via Steam launch option: `sn2-prelaunch %command%`.
- Add local nix container build for `frigate-notify` (`containers/frigate-notify/default.nix`) so the Frigate→ntfy bridge is rebuilt on ringtail from the forge mirror instead of pulled from `ghcr.io/0x2142/frigate-notify`.
- Add resource limits to all ArgoCD pods to prevent unbounded resource consumption during node-wide pressure events.
- Black-hole the `/mirrors/*` repositories at the Fly proxy edge (`return 403` → `forge.ops.eblu.me`). A surprise $29.60 Fly bill traced to ~1.24 TB/30d of egress on `forge.eblu.me`, 99.95% of all proxy egress — of which ~71% was AI scrapers (Meta `meta-externalagent`, OpenAI `GPTBot`, Amazonbot) crawling the near-infinite git-history URL space of the public mirror repos and timing out Forgejo in the process. Mirrors exist for supply-chain control and are consumed over the tailnet, so their public web UI had no legitimate audience. `robots.txt` already disallowed `/mirrors/`, but the offending agents ignore it. Tier-2 mitigations (user-agent denylist, Anubis proof-of-work gateway) are documented in `docs/explanation/ai-scraper-mitigation.md`.
- Bump paperless and immich kustomizations to the main-SHA-built valkey tag (`v8.1.6-r0-fabca04`). Routine post-merge follow-up to keep production manifests pointing at images built from a commit on main.
- Bump shower container to v1.1.1 (probe FOD hash).
- Bumped shower app to v1.1.3 (wheel/sdist + FOD hashes probed on ringtail).
- Cap systemd-coredump on ringtail (ProcessSizeMax/ExternalSizeMax 1G, MaxUse 2G) so multi-GB Wine/Proton game crash dumps no longer thrash the disk and lock up the desktop.
- Deploy shower v1.1.1 to ringtail (kustomize newTag bump).
- Deployed shower v1.1.3 to ringtail (image built and pushed from ringtail; runner bypassed due to indri overload).
- Fix three follow-ups from the wave-1 decommission: grant the local
  break-glass `admin` account ArgoCD admin rights (`g, admin, role:admin` —
  previously only the Authentik `admins` group had access, so admin was
  locked out whenever its token expired), and repoint the alloy blackbox
  probe for teslamate from the deleted minikube service to
  `https://tesla.ops.eblu.me/` (through Caddy over Tailscale). The orphaned
  paperless/teslamate roles + ExternalSecrets left on the minikube
  blumeops-pg are also cleaned up.
- Moved the Immich blackbox health probe from indri's alloy to ringtail's alloy. After the immich migration to ringtail, the probe still targeted `immich-server.immich.svc.cluster.local` on indri's cluster where the service no longer exists, causing a persistent `ServiceProbeFailure` alert.
- Pin shower v1.1.1 FOD outputHash (probed locally on ringtail).
- Rebuild Prowler container against main HEAD (v5.23.0-495e45d) after merging the IaC mutelist Dockerfile changes.
- Rebuild and retag alloy v1.16.0 container images from the main-branch SHA
  following the squash-merge of #345, per the build-container-image
  squash-merge convention. Both images (`registry.ops.eblu.me/blumeops/alloy`)
  now reference `9564435` rather than the branch SHA `26a3ab5`, restoring
  source traceability after branch cleanup.
- Rebuild shower from the post-merge commit on main so the container's
  SHA tag points at a commit that will still exist after the 30-day
  branch-cleanup window. Functionally identical to the branch-tag image
  already deployed, just preserves source traceability per
  [[build-container-image#Squash-merge and container tags]].
- Rebuild unpoller container from squashed main commit so the image SHA tag matches a commit in main's history (was tagged with the pre-squash branch SHA).
- Rebuild valkey container from squashed main commit (both arm64 dagger and amd64 nix variants), and update paperless + immich-ringtail kustomizations to the main-SHA tags `v8.1.7-ecded30` and `v8.1.7-ecded30-nix`.
- Retired the `blumeops-tasks` mise task (Todoist API) in favor of `heph list --project Blumeops --json` from the self-hosted [hephaestus](https://github.com/eblume/hephaestus) system. Updated docs to point task discovery and rotation reminders at heph, and noted that the `~/code/personal/zk` zettelkasten is migrating into heph docs.
- Switch the Fly proxy deploy strategy from `bluegreen` to `immediate` in `fly/fly.toml`. With a single proxy machine, bluegreen offers little benefit — the green machine routinely failed to reach "started" inside Fly's default 5-minute deploy timeout (the cold-start sequence of `tailscaled` → `tailscale up` → wait-for-MagicDNS → nginx startup eats most of the budget), and the failed deploys would roll back. `immediate` replaces the machine in place with a brief downtime (~5–10s) but actually completes.
- Switch the ringtail provisioning playbook's blumeops clone URL from `forge.eblu.me` (public, via Fly proxy) to `forge.ops.eblu.me` (tailnet, direct via Caddy on indri). Ringtail is always on the tailnet, so the WAN round-trip is pure overhead — it also made `provision-ringtail` brittle whenever the Fly proxy was slow or down.
- Switched Grafana's deployment strategy from `RollingUpdate` to `Recreate`. With an RWO PVC holding the SQLite database and Bleve search index, `RollingUpdate` reliably crashloops the new pod on the index lock until rollout timeout. `Recreate` terminates the old pod first so the new one acquires the lock cleanly.
- Update `tailscale-operator-ringtail` ProxyClass to reference the `0108b68` main-SHA build of the tailscale container. Routine post-merge cleanup so the deployed image traces to a commit that survives PR branch cleanup.
- Update the ringtail NixOS flake lockfile (`nixos/ringtail/flake.lock`): bump
  `nixpkgs` (b77b3de → 25f5383) and `disko` (5ba0c95 → 115e521) to latest.
  `nixpkgs-services` was intentionally left pinned (skipped by the
  `flake-update` pipeline). Routine recurring maintenance per [[manage-lockfile]].
- Upgrade native macOS Alloy on indri to v1.16.0. Built on gilbert with Go
  1.26.2 + CGO (required for the macOS native DNS resolver, which Tailscale
  MagicDNS depends on), scp'd to `~/.local/bin/alloy` on indri, codesigned,
  and the LaunchAgent reloaded. Completes the v1.16.0 fleet upgrade started
  in #345 — all four Alloy services (alloy-k8s, alloy-ringtail,
  alloy-tracing-ringtail, alloy ansible) now run v1.16.0.
- Upgraded zot on indri from v2.1.15 to v2.1.16 (security fixes: TLS verification on metrics client, CORS Allow-Credentials suppression on wildcard origins, manifest/API-key body size limits).

### Documentation

- Reviewed `replicating-blumeops` tutorial: fixed "BluemeOps" typos (also in `contributing.md`) and added `last-reviewed` frontmatter.
- Reviewed [[indri]] reference card: added `devpi`, `cv`, and `docs` to the native-services list; widened the k8s note to reflect the growing set of apps now on ringtail and the planned indri-minikube decommission; added CPU/RAM specs.
- New how-to: rotate-fly-deploy-token. Documents the 75-day rotation cadence, why we use `org`-scoped tokens (silences the cosmetic metrics-token warning on `fly status` with marginal blast-radius cost given the single-app personal org), and the procedure for rotation + Forgejo Actions secret sync.
- Add `docs/explanation/ai-scraper-mitigation.md` — the egress-cost / AI-crawler threat model for the public Fly proxy, the tiered mitigation plan (Tier 1: mirror black-hole, shipped; Tier 2: user-agent denylist + Anubis; Tier 3: Cloudflare, rejected on principle), and the data behind it.
- Fix manage-forgejo-mirrors verify step — sync button is on the repo settings page ("Synchronize now"), not the main repo page.
- Fixed the `op item edit` invocation in the [[zot]] API-key rotation procedure: the previous `pbpaste | op item edit ... "field[password]=-"` stdin syntax is rejected by op 2.34 as "invalid JSON" (recent op versions treat piped input as a full JSON template, not a single field value). Procedure now reads the clipboard into a local fish variable and passes it as an inline assignment.
- Fixed the export-filename step in [[run-1password-backup]]: 1Password's desktop app names the export `1PasswordExport-<account-uuid>-<timestamp>.1pux` automatically rather than letting you save to a fixed name, so the procedure now points the task at that glob instead of pretending the default name is `1Password-export.1pux`.
- Refresh the contributing tutorial: add `last-reviewed`, include the `.ai.md` changelog fragment type, and clarify that `prek` is pinned via `mise`.
- Review and refresh the Navidrome reference card: add `last-reviewed`, correct the scanner env var name, document the current image/version, and record routing and runtime details from the manifests.
- Review and refresh the Ollama reference card: add `last-reviewed`, bump the documented image tag to 0.20.4, and add the two `qwen3.5` models now declared in `models.txt`.
- Reviewed [[1password]] reference card: added the `blumeops` vs `Personal` vault split, noted that `onepassword-connect` runs on both indri and ringtail (not just one cluster), and pulled the `op read` vs `op item get --fields` guidance up from agent memory into the card.
- Reviewed `index.md`; added ringtail to the infrastructure overview and stamped `last-reviewed`.
- Reviewed transmission card: corrected storage layout (`/config/` is emptyDir, watch dir disabled) and noted the Prometheus exporter sidecar.
- rotate-fly-deploy-token: combine mint+store into one command with both fish and bash forms; document the `op item edit` "Password item requires ps value" validator gotcha and the placeholder-password workaround.

### AI Assistance

- Adopt `AGENTS.md` as the canonical agent instruction file, keep `CLAUDE.md` as a compatibility shim, and update docs to reference the neutral file and the correct agent-change-process path.
- CLAUDE.md now imports AGENTS.md via `@AGENTS.md` instead of telling agents to go read it. Claude Code only auto-loads CLAUDE.md, so the prose shim was easy to skip; the import inlines AGENTS.md into the session prompt unconditionally.

### Miscellaneous

- Removed the dead minikube manifests, container builds, and tooling shims left behind after the cv + docs migration to indri-native (#342). Deletes `argocd/{apps,manifests}/{cv,docs}/`, `containers/{cv,quartz}/`, and the `quartz`→`docs` mapping in `mise-tasks/container-version-check`. Bumps `docs.current-version` to `v1.16.0` (the blumeops release tag) now that the legacy nginx-base version pin is gone.
- Rebuild shower v1.1.0 container from main HEAD (`3c7967e`) and bump the
  kustomization tag to `v1.1.0-3c7967e-nix`. The PR was squash-merged, so
  the branch commit `444ff91` baked into the prior tag isn't reachable
  from main's history. The new tag points at a commit that exists on
  main; image content is byte-identical because the FOD output is content
  addressed and the inputs didn't change.
- Rebuild shower v1.1.2 from main HEAD (a33fa47) and retag — PR #358 was squash-merged so the branch SHA baked into the prior image tag isn't reachable from main. FOD is content-addressed, so image bytes are identical; only provenance changes.
- Remove the duplicate Homepage tiles for Mealie, Paperless, Immich, and
  TeslaMate. Homepage runs on ringtail and autodiscovers ringtail Ingresses via
  `gethomepage.dev/*` annotations; once these services migrated to ringtail they
  were discovered automatically, making their leftover static `services.yaml`
  entries (needed only while they lived on minikube) redundant.
- Removed the now-unused `containers/devpi/` Dagger build artifact. Devpi runs natively on indri via uv venv; the container image is no longer referenced anywhere. Doc examples in `docs/reference/tools/dagger.md` updated to use `miniflux` as the example container name.
- `container-build-and-release` now prints the specific `mise run runner-logs <N>` command after dispatching, polling the Forgejo API to resolve the run number for the commit it just triggered.
- `mise run runner-logs <run> -j <n>` now reports a clear error when the log file doesn't exist on indri (e.g. a runner crash that left `action_task.log_in_storage = 0`). Previously it printed only the header and exited 0, because `zstdcat` exits 0 with a "can't stat … -- ignored" stderr message and ssh+fish on indri swallows the remote exit code.


## [v1.16.0] - 2026-04-18

### Infrastructure

- Route Fly.io proxy through Caddy on indri with direct WireGuard peering, reducing public-facing latency from 20+ seconds (DERP relay) to sub-second. Fixed Beyla eBPF tracing on ringtail (memlock rlimit + BPF permissions). Restored trace collection to Tempo.


## [v1.15.7] - 2026-04-18

### Bug Fixes

- Fix borgmatic LaunchAgent failing silently due to macOS TCC permission dialogs. LaunchAgents now call borgmatic directly instead of routing through `mise x`, which triggered "wants to access Documents" dialogs that hung headless sessions. The ansible role now also manages borgmatic installation via `mise install`.

### Infrastructure

- Automate verification of Prowler MANUAL findings (kubelet file perms, kubelet config, etcd CA, RBAC cluster-admin) in `review-compliance-reports` and mute them with `node-config-automated-verification` compensating control.
- Migrate transmission and transmission-exporter containers from Dockerfile to native Dagger builds (`container.py`). Updates base images to Alpine 3.23 and Python 3.14, pins uv to 0.11.6.
- Switched Fly proxy to upstream keepalive pools, reducing forge.eblu.me latency from 35s+ p50 to sub-second. Added `mise run fly-reload` for DNS re-resolution without redeploy.
- Upgrade Prowler from 5.22.0 to 5.23.0; remove init container workaround for broken `--registry` flag (upstream fix in PR #10470).
- Added `robots.txt` to `forge.eblu.me` blocking crawlers from `/mirrors/` to reduce load from Facebook scraping.
- Container builds are now manual-only via `mise run container-build-and-release`. Removed auto-trigger on push to main — shared Dagger helpers made path-based detection unreliable.
- Migrate devpi container from Dockerfile to native Dagger build; bump devpi-server 6.19.1→6.19.3 and devpi-web 5.0.1→5.0.2.
- Migrated kiwix-serve container from Dockerfile to native Dagger build, bumping Alpine base from 3.22 to 3.23.
- Mitigated Forgejo archive endpoint DoS: redirect public archive requests to tailnet, expanded robots.txt, enabled archive cleanup cron, cached release downloads at proxy.
- Refactored Dagger container pipelines: extended `go_build()` helper with `buildmode` and `extra_env` params, migrated miniflux and forgejo-runner to use it, and standardized all Alpine bases from 3.22 to 3.23.

### Miscellaneous

- Review compensating control `sso-gated-admin-tools`: tightened scope to ArgoCD only, removed Grafana reference.
- container-build-and-release now verifies the commit exists on the remote before dispatching a build.


## [v1.15.6] - 2026-04-14

### Bug Fixes

- Rotate ArgoCD workflow-bot token and admin password after DR rebuild invalidated signing keys, fixing build-blumeops workflow failures.


## [v1.15.5] - 2026-04-14

### Features

- Deploy Paperless-ngx document management system at paperless.ops.eblu.me with OCR, Authentik SSO, and NFS storage on sifaka.
- Add `ty` (Astral) Python typechecker to prek hooks, configured for Dagger SDK and container.py modules. Add `type: mise` to service-versions.yaml for tracking development tool versions (dagger, ansible-core, prek, pulumi, ty) through the standard service review process.
- Upgrade grafana-sidecar from 1.28.0 to 2.6.0, adding health probes and porting build to native Dagger container.py.
- Upgrade Navidrome to v0.61.1 — major artwork overhaul with per-disc cover art, rebuilt search engine (SQLite FTS5), server-managed transcoding, and WebP performance fix.
- Add `mise run review-compliance-reports` task for weekly compliance report review with muted/unmuted distinction and week-over-week delta

### Bug Fixes

- Add paperless database to borgmatic backup configuration. Previously the only service DB not included in nightly pg_dump backups.
- Fix Fly.io proxy rate limiting to key on real client IP instead of Fly's internal proxy IP, so crawlers no longer consume the shared rate limit bucket for all clients.
- Fix UnPoller (UniFi) Grafana dashboards failing to load due to UID exceeding Grafana 12's 40-character limit.
- Fix blumeops-tasks swallowing wiki-link brackets in task descriptions (rich markup escaping)
- Fix dagger flake-update pipeline: replace nonexistent `--exclude` flag with dynamic input discovery
- Fix services-check to display all firing alerts for a given alert name, not just the first one.
- Pin Fly.io proxy Tailscale to v1.94.1 — the `:stable` tag pulled v1.96.5 which has a MagicDNS regression (SERVFAIL on tailnet names), breaking all public routing through forge.eblu.me, docs.eblu.me, and cv.eblu.me.
- Rewrite `mise run runner-logs` CLI: list runs by run number (not task ID), drill into jobs per run, fetch logs via Forgejo web API instead of SSH+filesystem. Fixes broken log retrieval caused by incorrect hex path calculation and stale data directory. Added `--repo` to query any forge repo (e.g. sporks) and `--limit`/`-n` to control listing size (0 for all).
- Route Dagger build telemetry to Tempo, fixing OTEL metrics exporter warnings.
- Switch paperless redis sidecar from amd64-only nix-built `authentik-redis` image to upstream `valkey:8.1-alpine` (multi-arch). The nix image was previously running under QEMU emulation on arm64 minikube.

### Infrastructure

- Build forgejo-runner container locally via native Dagger pipeline instead of pulling from upstream.
- Build kube-state-metrics container locally (Dockerfile + nix) from forge mirror, replacing upstream registry.k8s.io image on both indri and ringtail.
- Upgrade miniflux from 2.2.17 to 2.2.19 and migrate from Dockerfile to native Dagger container.py build (second container after navidrome). Refactor `alpine_runtime()` with `create_user` parameter to support Alpine's built-in nobody user. Pin all mise.toml tool versions to explicit versions instead of "latest".
- Migrate Dagger module from .dagger/ to repo root (src/blumeops/) and replace docker_build() with native Dagger pipelines for container builds. Navidrome is the first container migrated, with full build error visibility.
- Migrate teslamate container build from legacy Dockerfile to native Dagger container.py.
- Add seccomp RuntimeDefault profiles to alloy-k8s and immich pods, resolving 4 unmuted Prowler findings
- Full DR recovery from power loss and minikube cluster rebuild. Validated bootstrap procedure, identified circular dependencies (forge.eblu.me, Zot/Authentik OIDC), Tailscale device name collision issues, and documented recovery steps for restart-indri.
- Set Frigate preview quality to CRF 8 (from default 1) to reduce preview file sizes and improve review timeline loading over NFS.
- Track Fly.io proxy component versions (Tailscale, nginx, Alloy) in service-versions.yaml with new `fly` service type.
- Upgrade ArgoCD from v3.3.2 to v3.3.6 (bug-fix patches), SHA-pin install manifest
- Upgrade authentik 2026.2.0 → 2026.2.2 (bug-fix patch release)
- Upgrade ollama from 0.17.5 to 0.20.4 (adds Gemma 4 support, benchmark tooling, Apple Silicon perf improvements)

### Documentation

- Delete outdated install-dagger-on-nix-runner card; add service-versions reference card; clean up zot.md and review-services.md links.
- Enhanced the adding-a-service tutorial with kustomization setup, corrected Tailscale ingress format, updated ArgoCD repoURL, and added a step for creating service reference cards.
- Review gandi.md: add missing forge.eblu.me CNAME, fix program description, stamp review date.


## [v1.15.4] - 2026-04-06

### Infrastructure

- Migrate 1Password Connect from Helm to kustomize (1.8.1 → 1.8.2), completing the no-helm-policy migration.

### Documentation

- Rewrite observability stack tutorial: replace Helm instructions with actual kustomize/ArgoCD patterns, fix typos, document Alloy as core component


## [v1.15.3] - 2026-04-05

### Infrastructure

- Build Tempo container from source via forge mirror; bump 2.10.1 → 2.10.3
- Pin NixOS service versions (forgejo-runner, snowflake, k3s) via `nixpkgs-services` overlay in ringtail flake, preventing silent upgrades from `nix flake update`. Add k3s and minikube to service-versions.yaml tracking. Fix stale nix-container-builder version (was 12.6.4, actually running 12.7.2).
- Migrate Immich from Helm chart to kustomize manifests and upgrade from v2.5.6 to v2.6.3
- Upgrade Grafana from 12.3.3 to 12.4.2 — patches 7 CVEs including an unauthenticated DoS (CVE-2026-27880).

### Documentation

- First compensating control review: verified `single-user-cluster` still in effect. Added aspirational how-to card for PCI DSS evidence collection.
- Prowler `--registry` fix merged upstream (PR #10470); initContainer workaround documented as pending release.


## [v1.15.2] - 2026-03-30

### Features

- Build custom Kingfisher container from sporked deploy branch, replacing upstream image with locally-built version including --clone-url-base patch.
- Add Kingfisher secret scanner as a weekly CronJob scanning all Forgejo repos, with HTML and JSON reports written to sifaka NFS.
- Add MongoDB Kingfisher secret scanner as a prek hook alongside TruffleHog for comparative coverage evaluation.
- Add spork strategy: floating-branch soft-fork tooling (`mise run spork-create`) and documentation for maintaining local patches against upstream projects.

### Infrastructure

- Add compensating controls framework: tracking file, review mise task, and how-to doc. Map all Prowler mutelist entries to named controls with CC: prefixes.
- Add Prowler mutelist to suppress expected findings from system components, operator-managed pods, and accepted operational needs. Fix missing seccomp profile on kube-state-metrics.
- Borgmatic photos backup: restrict to library/ and upload/ (skip regenerable dirs), add SSH keepalives and checkpoint interval to prevent broken pipe failures on large initial syncs.
- Upgrade forgejo-runner from 12.7.0 to 12.7.3 (bug fixes, security dep update). Add service reference card.

### Documentation

- Add service reference documentation for Kingfisher secret scanner.
- Review and update Ansible reference doc: add missing roles, sibling playbooks, and clarify Ansible's role in the IaC stack.


## [v1.15.1] - 2026-03-28

### Features

- Add Tor Snowflake proxy on ringtail as a systemd service to support anti-censorship efforts.
- Add offsite backup for immich photo library to BorgBase, running daily at 4 AM from indri via sifaka SMB mount.
- Add QArt Tuner — a Go tool that generates QR codes whose data modules form a recognizable image, with an interactive web UI for parameter tuning. Based on the [QArt technique](https://research.swtch.com/qart) by Russ Cox. Lives in `utils/qart/`.

### Infrastructure

- Migrate Forgejo from Homebrew to source build with mcquack LaunchAgent, matching the pattern used by zot, caddy, and alloy. Upgrades to v14.0.3 (7 security fixes including PKCE bypass and OAuth scope bypass).
- Add borgmatic pg_dump backups for authentik and immich databases. Authentik uses the existing blumeops-pg cluster on port 5432. Immich requires a new borgmatic role on the immich-pg cluster, a Tailscale service, and Caddy L4 proxy on port 5433.
- Upgrade External Secrets Operator from v1.3.2 to v2.2.0 and migrate from Helm chart to static kustomize manifests.
- Add post-deploy maintenance docs and generation pruning task for ringtail.
- Fix Immich Helm values: resource limits and probe timeouts were silently ignored due to wrong value keys. Resources now actually apply to pods, and liveness/readiness probe timeouts increased from 1s to 5s to prevent kubelet from killing pods during ML inference.
- Reduce PodNotReady alert lookback window from 5m to 60s to clear faster after rollouts.
- Tighten ArgoCDAppOutOfSync alert: reduce pending duration from 30m to 5m and lookback window from 5m to 1m so alerts clear faster after sync.
- Update ringtail flake inputs (nixpkgs, home-manager).
- Upgrade Homepage dashboard from v1.10.1 to v1.11.0
- Upgrade nvidia-device-plugin from v0.18.2 to v0.19.0

### Documentation

- Review and fix CV service doc (correct URL, forge domain, container tag link) and add private forge repo review guidance to review-services process.
- Review tailscale-setup tutorial: fix macOS install steps, add `--accept-routes` tip, correct tag name, add ACL apply instructions, add `[[tailscale-operator]]` cross-reference.

### Miscellaneous

- Add `preserve/*` branch prefix exclusion to `branch-cleanup` task; document Pyroscope profiling work and blockers in observability reference.


## [v1.15.0] - 2026-03-24

### Features

- Deploy Prowler CIS scanner as a weekly CronJob on minikube-indri, with reports written to sifaka NFS share.
- Add Grafana "Alerts" dashboard showing currently firing alerts and recent state changes.
- Add IaC scanning via Prowler IaC provider (Saturday 2am, Dockerfiles and K8s manifests).
- Add container image vulnerability scanning via Prowler image provider (Saturday 3am, all blumeops/* images).

### Bug Fixes

- Fix authentik worker OOMKill by setting AUTHENTIK_WORKER_CONCURRENCY=2 (was defaulting to 16 based on CPU count).
- Remove `group: ""` from tailscale-operator ignoreDifferences — ArgoCD normalizes away the empty string, causing permanent OutOfSync on the apps app.

### Infrastructure

- Decommission JobSync service — removed ArgoCD app, k8s manifests, container build, Caddy proxy, Homepage entry, docs, and forge mirror. Replaced by datasette-based job tracking (coming soon).
- Localize authentik-redis container: replace upstream `redis:7-alpine` with nix-built image from nixpkgs (Redis 8.2.3). Introduces attached service pattern with `parent` field in service-versions.yaml and version assertion in default.nix to prevent silent version drift.
- Unified Dockerfile and Nix container build workflows into a single workflow that auto-classifies containers by build type and routes to the correct runner (k8s for Dockerfile, nix-container-builder for Nix). Removed nettest container (outgrown). Nix builds now require an explicit `version = "..."` declaration — no implicit nixpkgs fallback.
- Monthly tooling dependency update: bump prek hooks (trufflehog 3.94.0, ruff 0.15.7, shfmt 3.13.0), Fly.io images (nginx 1.29.6, Alloy 1.14.1), actions/checkout v4.3.1→v6.0.2, tighten mise task Python lower bounds (rich 14, typer 0.24, httpx 0.28.1, pyyaml 6.0.2), and bump ansible-lint/ansible-core floors.
- Upgrade ntfy v2.17.0 → v2.19.2 (adds experimental PostgreSQL support, read replicas, web push fixes)
- Revert Tailscale operator to v1.94.2 (v1.96.3 images not yet published); keep Fly proxy `tailscale wait` improvement
- Add RuntimeDefault seccomp profiles to all managed deployments, statefulsets, and cronjobs.
- Upgrade Frigate from 0.17.0-rc2 to 0.17.1 (security fixes, bugfixes). Add motion retention tier (365 days), reduce continuous retention from 180 to 30 days.

### Documentation

- Review and fix ArgoCD config tutorial: correct sync policy example, fix typo, add missing cross-references and frontmatter.
- Review and update 12 reference docs: fix stale image references to point at kustomization manifests instead of hardcoded tags, correct Prometheus scrape target, expand external-secrets stub, add cross-references between backup/disaster-recovery docs, and remove misleading `.ts.net` URLs from Quick Reference tables.


## [v1.14.3] - 2026-03-22

### Features

- Deploy infrastructure alerting pipeline using Grafana Unified Alerting with ntfy push notifications. 7 alert rules with runbooks covering service health, pod readiness, PostgreSQL, textfile freshness, Frigate cameras, and ArgoCD sync status. services-check now queries the alerting API for covered checks.

### Bug Fixes

- Fix Frigate NVR crash by re-adding required `mqtt` config section (disabled) after Mosquitto removal.
- Fix borgmatic backup failure: use correct kubectl context (`minikube`) on indri for Mealie SQLite dump hook

### Infrastructure

- Localize Grafana Alloy container image with dual Dockerfile + Nix builds from forge mirror
- Upgrade Prometheus from v3.9.1 to v3.10.0 (distroless variants, PromQL fill operators, performance improvements)
- Bump Frigate recording retention (180d continuous, 30d detections, 730d alerts) and add camera-fps health check to services-check.
- Improve Frigate health checks in services-check: per-camera FPS validation and NFS storage accessibility check.
- Increase data retention: Prometheus 15d → 10y, Loki 31d → 365d (PVC sizes unchanged; minikube hostpath doesn't enforce limits)
- Standardize OCI labels across all container Dockerfiles with consistent title, description, version, source, and vendor metadata.

### Documentation

- Review and correct Tailscale reference doc: fix ACL path, add missing device tags (ringtail, per-service tags, ci-gateway, flyio-proxy), correct access matrix (PyPI→DevPI, homelab grants), add SSH homelab→homelab rule, document auto approvers, add last-reviewed frontmatter.

### AI Assistance

- Add four Claude Code subagents: infra-health (background health monitor), doc-reviewer (persistent-memory doc review), change-classifier (C0/C1/C2 triage), and mikado-navigator (C2 chain state advisor).

### Miscellaneous

- Standardized USAGE pragmas and typer CLI parsing across all mise tasks: added missing `#USAGE` directive to `mikado-branch-invariant-check`, converted `pr-comments` and `op-backup` from raw `sys.argv` to typer for consistency with all other uv python scripts.


## [v1.14.2] - 2026-03-17

### Features

- Deploy Mealie recipe manager on minikube-indri for meal planning and prep automation.
- Add UnPoller deployment to monitor UniFi network metrics via Prometheus

### Bug Fixes

- Fix Caddy v2.11 breaking change: preserve original Host header for HTTPS upstreams.
- Fix plan-a-meal random recipe queries — add required `paginationSeed` parameter

### Infrastructure

- Externalize Tailscale operator manifest to forge mirror, removing 495 KB vendored file from the repo.
- Externalize TeslaMate Grafana dashboards to forge mirror, removing 713 KB of ConfigMaps from the repo.
- Upgrade Caddy from v2.10.2 to v2.11.2 (7 CVE fixes), create caddy-l4 forge mirror, migrate all ~/code/3rd clones on indri to HTTPS forge.ops.eblu.me remotes.
- Upgrade borgmatic from 2.0.13 to 2.1.3 on indri (improved borg warning handling, memory/performance improvements)

### Documentation

- Add git last-modified subsort to docs-review script, so ties in review date are broken by least recently updated first.
- Review jellyfin (10.11.6, current) and automounter (1.11.0) services; add missing frigate share to automounter docs.


## [v1.14.1] - 2026-03-14

### Features

- Add `docs-preview` mise task: builds docs with Dagger and serves them locally in the production quartz container, opening the browser directly to the specified card. Also adds visual preview hints to the `docs-review` checklist and the review-documentation how-to.

### Infrastructure

- Add jobsync to services-check and homepage dashboard; mark as reviewed at v1.1.4
- Bump Grafana Alloy to v1.14.0 across all deployments (indri, alloy-k8s, alloy-ringtail, alloy-tracing-ringtail)
- Upgrade zot container registry from v2.1.13 to v2.1.15 (CVE-2025-30204, open redirect fix). Fix trivy CVE DB downloads by adding /usr/local/bin to LaunchAgent PATH.
- Remove Mosquitto (MQTT broker) — unused since frigate-notify switched to webapi polling. Deleted ArgoCD app, k8s manifests, namespace, and updated all docs.

### Documentation

- Add how-to card for running the 1Password backup (`mise run op-backup`), with bidirectional links to restore procedure and service reference.


## [v1.14.0] - 2026-03-09

### Features

- Deploy JobSync to ringtail k3s — nix-built container, Tailscale Ingress, Caddy route at `jobsync.ops.eblu.me`, Ollama integration for AI features.

### Bug Fixes

- Fix 1Password Connect logs showing as errors in Grafana by normalizing numeric log levels (1-5) to standard strings (error/warn/info/debug/trace) in the Alloy log processing pipeline.
- Fix mikado-branch-invariant-check false positive: close commits without preceding impl commits are valid (e.g., operational tasks with no code changes).

### Infrastructure

- Disable Quartz SPA mode and remove robots.txt crawler exclusions to fix the Facebook crawler spider trap. Remove hand-curated category index files in favor of Quartz auto-generated folder pages.

### Documentation

- Add JobSync reference card, update ringtail workloads table, document observability via Loki, and wire RAPIDAPI_KEY through ExternalSecret for job search automation.
- Relax wiki-link constraints: allow path-based links for disambiguation, drop global filename uniqueness requirement, remove docs-check-filenames and docs-check-index hooks.


## [v1.13.3] - 2026-03-06

### Infrastructure

- Upgrade Dagger engine and CLI from v0.20.0 to v0.20.1.

### Documentation

- Add how-to guide for upgrading Dagger, documenting the correct phase ordering to avoid chicken-and-egg CI failures.


## [v1.13.2] - 2026-03-06

### Infrastructure

- Replace nginx spider-trap 404 guards with robots.txt disallowing /explorer/ to prevent crawler-induced infinite URL trees.


## [v1.13.1] - 2026-03-06

### Infrastructure

- Add `:kustomized` sentinel tag to all manifest image references overridden by kustomize, making it clear the real tag lives in kustomization.yaml.
- Add nginx spider-trap guards to docs.eblu.me Quartz container — blocks recursive crawler paths at /tags/ depth >1 and global depth ≥5.


## [v1.13.0] - 2026-03-05

### Features

- Add Authentik OIDC login for ArgoCD — `eblume` (admins group) gets admin access via SSO while local admin password remains as break-glass.
- Expose Forgejo publicly at forge.eblu.me via Fly.io reverse proxy with rate limiting, fail2ban, and security hardening.
- Deploy Ollama LLM server on ringtail with GPU acceleration and declarative model management
- Add distributed tracing via Grafana Tempo and Beyla eBPF auto-instrumentation. Tempo runs on minikube-indri for trace storage, while a privileged Alloy DaemonSet on ringtail uses Beyla to instrument HTTP services (Frigate, ntfy, Ollama, Immich) without code changes. Grafana gets trace-to-log and trace-to-metrics correlation.
- Add fly.io nginx proxy observability and application logs to Forgejo dashboard; rename from "Forgejo Repository Health" to "Forgejo".

### Bug Fixes

- Add per-torrent rate metrics using Transmission's native rate_download/rate_upload fields. Dashboard panels were querying cumulative byte gauges (torrent size) instead of actual transfer rates.
- Fix Frigate database loss on pod restart by pointing database path to persistent /db volume
- Fix runner-job-image Dagger version mismatch: bump from 0.19.11 to 0.20.0 to match upgraded Dagger module.

### Infrastructure

- Home-build grafana-sidecar container image, replacing upstream `quay.io/kiwigrid/k8s-sidecar` for supply chain control.
- Add HA (2 replicas + PDB) for CV and Docs services for zero-downtime deploys.
- Build Loki container image locally instead of pulling from upstream
- Replace unmaintained `metalmatze/transmission-exporter` sidecar with homegrown Python exporter using `prometheus_client` and `transmission-rpc`. Same metric names, so Grafana dashboards work unchanged.
- Upgrade Transmission from 4.0.6-r4 to 4.1.1-r1 (Alpine edge community repo)
- Bump Frigate memory limit from 2Gi to 3Gi to prevent OOMKills under steady-state ONNX + CUDA workload.
- Add Gandi bookmark to homepage dashboard
- Allow implicit octals in yamllint and use `0755` directly in k8s manifests instead of decimal or disable-line comments.
- Upgrade Dagger engine and CLI from v0.19.11 to v0.20.0
- Upgrade TeslaMate from v2.2.0 to v3.0.0 (dark mode, BRIN index optimization, Elixir 1.19.5, trixie-slim runtime)
- Add OOMKilled Containers stat panel and Container Restarts timeseries to the Kubernetes Clusters dashboard for persistent OOMKill visibility.
- Add pre-commit hook to prevent changelog fragments from being placed in subdirectories.
- Bump kiwix-serve from 3.8.1 to 3.8.2

### Documentation

- Clarify that changelog fragments apply to all change levels (C0, C1, C2), not just C2.
- Add reference card for the Ollama LLM inference service.
- Clarify that all mikado frontmatter is removed during chain finalization; clean up stale frontmatter from closed chains; fix ai-docs exit code after plans directory retirement.
- Retire docs plans directory: deleted completed/abandoned plans, converted migrate-forgejo-from-brew to a mikado chain root card, removed plans references from tutorials and how-to index.
- Review and fix upgrade-grafana doc: correct image tag reference to kustomization.yaml, add sidecar cross-reference, update stale service-versions notes.
- Use towncrier orphan fragment naming (`+slug.<type>.md`) for C0 changes to avoid `main.*` collisions.


## [v1.12.1] - 2026-03-02

### Features

- Mikado branch invariant hook now rejects `impl` commits that modify Mikado card files (docs with `requires:`, `status:`, or `branch: mikado/` frontmatter).

### Infrastructure

- Switch git hooks from pre-commit to [prek](https://github.com/j178/prek), a faster Rust-native drop-in replacement. Adds built-in checks for case conflicts, private key detection, and executable shebangs. Configuration migrated from `.pre-commit-config.yaml` to `prek.toml`.

### Documentation

- Review build-authentik-from-source Mikado chain: fix go-server-derivation path errors, remove stale DRF fork content from mirror doc, add last-reviewed to all cards.


## [v1.12.0] - 2026-03-01

### Bug Fixes

- Fix authentik 2026.2.0 startup crash caused by Django migration ordering bug (`FieldError: Cannot resolve keyword 'group_id'`). Patch ensures `authentik_core/0056` runs before `authentik_rbac/0010`.

### Infrastructure

- Upgrade authentik from 2025.10.1 to 2026.2.0, building core services from source via custom Nix derivations rather than using nixpkgs directly (nixpkgs still provides satellite dependencies like Python, Go, and system libraries). Four components (API client generation, Python backend, web UI, Go server) assembled into a single container image with full supply chain control via forge mirrors.
- Sync Frigate zone coordinates from live API to manifest (driveway_entrance, driveway)
- Pin blumeops-pg to PostgreSQL 18.3 (from floating `:18` tag at 18.1)

### Documentation

- Review and update authentik-api-client-generation doc: remove stale patch note, fix test-build.nix section, add last-reviewed date.
- Review all three forgejo-runner Mikado chain docs: stamp `last-reviewed`, add cross-links, fix `configmap.yaml` → `config.yaml` reference.
- Review build-grafana-container docs; fix stale grafana.md reference card (Helm → Kustomize).


## [v1.11.5] - 2026-02-26

### Features

- Add authenticated GitHub mirror sync with PAT rotation tooling (`mirror-update-pats`, `mirror-create` auth support, how-to doc).
- Add Transmission Grafana dashboard with metrics exporter sidecar for monitoring upload/download speeds, transfer volumes, and per-torrent breakdowns.

### Bug Fixes

- Fix Frigate dashboard "Detection Events Rate" panel showing no data — corrected metric name to `frigate_camera_events_total` and label to `camera`.
- Filter car and bird detections from Frigate driveway zone to stop repeated alerts on parked cars at night

### Infrastructure

- Port CloudNative-PG operator from Helm chart to direct upstream release manifest via forge mirror.
- Add multi-cluster Kubernetes observability: deploy kube-state-metrics and Alloy on ringtail (k3s), add `cluster` label to all metrics/logs, replace single-cluster dashboards with multi-cluster Kubernetes dashboard and dedicated Ringtail dashboard with GPU monitoring.
- Add explicit ExternalSecret defaults for SSA sync parity with ArgoCD v3.3
- Upgrade ArgoCD from v3.2.6 to v3.3.2 with Server-Side Apply enabled

### AI Assistance

- Bake default bat options into `ai-docs` mise task so agents no longer need verbose flags at session start.
- docs-review task now prints the file path instead of the file content, so the LLM reads it directly.


## [v1.11.4] - 2026-02-25

### Features

- Add `mirror-create` mise task for creating upstream mirrors in the `mirrors/` Forgejo org

### Bug Fixes

- Fix Grafana OAuth role mapping: INI parser was stripping quotes from `role_attribute_path = 'Admin'`, causing all Authentik users to get Viewer role instead of Admin. Now uses group-based mapping from the `admins` Authentik group.
- Fix TeslaMate dashboards showing "No Data": Grafana 12.x's `grafana-postgresql-datasource` plugin requires the database name in `jsonData`, not just the top-level `database` field.

### Infrastructure

- Move image tags to kustomize `images:` transformer across 22 services and replace hand-written ConfigMaps with `configMapGenerator:` in 12 services, enabling content-hash-based automatic rollouts on config changes.
- Migrate upstream mirror repos from `eblume/` to `mirrors/` Forgejo organization
- Port Prometheus to local container build (3-stage: Node UI, Go binaries, Alpine runtime) for supply chain control via Zot registry.
- Fix ArgoCD app definitions and credential template to use `mirrors/` org after forge mirror migration; bump immich v2.5.2 → v2.5.6.
- Document AirPlay cross-VLAN firewall rules for Samsung Frame TV (established/related, AirPlay ports, dynamic reverse) and fix rule ordering in segment-home-network plan.
- Update image tags for all 6 mirror-migrated containers (homepage, navidrome, ntfy, miniflux, prometheus, teslamate)
- Switch prometheus, teslamate, and miniflux container builds to forge mirrors; create miniflux mirror

### Documentation

- Document squash-merge container tag provenance issue and post-merge workflow for updating manifests to main-SHA tags.
- Add mise-tasks reference card with categorized task inventory; include in ai-docs context
- Review 3 how-to docs: stamp provision-authentik-database and use-pypi-proxy, fix wrong policy path and misleading --yes in update-tailscale-acls


## [v1.11.3] - 2026-02-23

### Features

- Upgrade Grafana from 11.4.0 to 12.3.3 with home-built container image and Kustomize manifests, replacing the Helm chart deployment.

### Bug Fixes

- Fix Dagger pipelines hanging when called from mise tasks in interactive terminals. Added `--progress=plain` to all `dagger call` invocations to prevent SIGTTOU from stopping the process when mise's child process group is not the terminal foreground group.
- Fix Grafana TeslaMate dashboards not appearing in a folder — enabled `foldersFromFilesStructure` so the sidecar's `grafana_folder` annotation is respected.
- Container build workflows now checkout the dispatch ref when building from feature branches, fixing "No Dockerfile — skipping" errors for containers not yet on main.

### Infrastructure

- Fix Frigate Prometheus scrape target to route via Caddy (nvr.ops.eblu.me) after migration to ringtail, and rebuild Grafana dashboard with updated Frigate 0.17 metrics (GPU usage, temperature, skipped FPS, detection events).
- Update tooling dependencies: pre-commit hooks (trufflehog, ruff, shellcheck, prettier, actionlint), Fly.io Dockerfile (pin nginx 1.28.2-alpine, alloy v1.13.1), and normalize mise task Python lower bounds.
- Rename `containers/forgejo-runner` to `containers/runner-job-image` to distinguish the CI job execution image from the Forgejo runner daemon, fixing a version-check false positive.

### Documentation

- Review deploy-authentik card: rewrite as reproducible process guide, remove stale version info and future work section, mark plan as completed.
- Formalize C0/C1/C2 change classification: C0 allows direct-to-main commits, C1 adds docs-first workflow with branch deployment, C2 introduces the Mikado Branch Invariant for strict commit ordering on multi-phase changes. Add C2 conventions: `C2(<chain>): plan/impl/close/finalize` commit messages, `mikado/<chain-stem>` branch naming, and `branch:` frontmatter on goal cards. New tooling: `docs-mikado --resume` for cold-start session pickup and `mikado-branch-invariant-check` pre-commit hook.
- Replace Grafana Helm upgrade plan with C2 Mikado chain for upgrading to 12.x with kustomize and home-built containers.

### AI Assistance

- Improved Mikado C2 process: end-of-cycle session prompts, rigorous reset discipline with documented git patterns, and `--resume` now shows PR number and stash hints.


## [v1.11.2] - 2026-02-22

### Features

- Add `branch-cleanup` mise task and scheduled Forgejo workflow to delete merged branches locally and on the Forgejo remote. Detects squash-merged PRs via the Forgejo API. The workflow runs approximately every 10 days with a configurable age cutoff (default 30 days).
- Add Forgejo repository health metrics collector and Grafana dashboard with CI/CD, release, and language tracking across all repos.
- Switch Frigate object detection from YOLO-NAS-S (320x320) to YOLOv9-c (640x640) with CUDA Graphs support, and add `frigate-export-model` Dagger pipeline + mise task for reproducible model exports.

### Infrastructure

- Simplify service-versions.yaml type taxonomy to `argocd | ansible | nixos`; add nix-container-builder entry; backfill forgejo and forgejo-runner versions
- Prepare forgejo-runner v12 upgrade: review config compatibility, add workflow schema validation via Dagger, wire pre-commit hook
- Upgrade k8s forgejo-runner daemon from v6.3.1 to v12.7.0

### Documentation

- Add Mikado chain for upgrading k8s forgejo-runner from v6.3.1 to v12.x


## [v1.11.1] - 2026-02-22

### Infrastructure

- Use Zot registry logo instead of Docker logo on homepage dashboard


## [v1.11.0] - 2026-02-22

### Features

- Add agent change process (C0/C1/C2) documentation and `docs-mikado` tool for Mikado method dependency chain resolution. Rename `zk-docs` task to `ai-docs`.
- Deploy Authentik identity provider on ringtail k3s cluster, replacing Dex as the SSO provider. Includes Nix-built container, CNPG database, Redis, and Caddy routing at `authentik.ops.eblu.me`.
- Integrate Forgejo with Authentik OIDC for single sign-on with group-based admin propagation. Enforce TOTP MFA on Authentik authentication flow.
- Add Authentik SSO to Jellyfin with admin group mapping
- Container builds now trigger automatically on merge to main (path-based) and use commit-SHA-based image tags (`vX.Y.Z-<sha>`) for full traceability. The `container-tag-and-release` task is replaced by `container-build-and-release` which dispatches workflows via the Forgejo API. Added pre-commit hook to keep container versions in sync with `service-versions.yaml`.
- Register Zot as an OIDC client in Authentik via blueprint, with artifact-workloads group, zot-ci service account, and OIDC credentials template for Ansible deployment.
- Enable OIDC + API key authentication on zot registry with three-tier access control (anonymous read, CI create, admin full). Wire both CI push paths (Dagger and Nix/skopeo) with registry credentials via Forgejo Actions secrets. Allow anonymous Prometheus metrics scraping via `accessControl.metrics.users`.

### Bug Fixes

- Fix frigate-notify notification pipeline: switch to webapi polling, enable dedup, drop events without snapshots, use hi-res snapshots

### Infrastructure

- Add Mikado prereq for commit-based container tagging scheme to harden-zot-registry chain
- Convert deploy-authentik plan to C2 Mikado chain entry point.
- Add `flake-update` Dagger pipeline for updating ringtail NixOS flake inputs.
- Upgrade frigate-notify from v0.3.5 to v0.5.4

### Documentation

- Add deployment plan for Authentik identity provider to replace Dex


## [v1.10.0] - 2026-02-19

### Features

- Deploy Dex OIDC identity provider on ringtail with Grafana as first SSO client.
- Added Nix container build for nettest, validating the full nix-container-builder pipeline on ringtail. One git tag now triggers both Dockerfile and Nix workflows — each skips if its build file is absent. Rewrote container-tag-and-release as a typer CLI with --dry-run support. Added container policy.json and registries.conf to ringtail for skopeo.
- Add NixOS configuration for ringtail (gaming/compute workstation with RTX 4080). Includes declarative disk partitioning via disko, NVIDIA drivers, sway/Wayland desktop, Steam, Tailscale, and Ansible-driven provisioning.
- Add screen lock, idle timeout, and sleep prevention to ringtail: swaylock locks after 15min, display powers off after 60min, machine never suspends.
- Systemd Forgejo Actions runner on ringtail (`nix-container-builder` label) for building containers with `nix build` and pushing via `skopeo`. K3s cluster retained for future workloads. 1Password Connect + External Secrets Operator available for k8s secret management.

### Bug Fixes

- Cap detect FPS to 2 and sync motion masks/zones from live config
- Fix `zk-docs` task to use new path for troubleshooting doc after how-to reorg.
- Inhibit swayidle lock screen when a fullscreen window is active on ringtail, preventing screen lock during gamepad-only gaming sessions.
- Make 1Password secret tasks in ringtail playbook idempotent by checking kubectl apply output instead of always reporting changed.

### Infrastructure

- Port Frigate NVR to ringtail k3s with RTX 4080 GPU acceleration (TensorRT/ONNX), replacing the ZMQ-based Apple Silicon detector on indri.
- Replace Homepage Helm chart (jameswynn/homepage v2.1.0, pinned at app v1.2.0) with plain kustomize manifests and a custom Dockerfile built from upstream v1.10.1. Gives full version control and matches the pattern used by other blumeops services.
- Port ntfy to a locally built container image from forge mirror source.
- Port Mosquitto (MQTT) and ntfy to ringtail k3s; retire Apple Silicon Detector from indri.
- Ringtail post-install: NixOS config (sway with Catppuccin Macchiato theme, fish, 1Password, Steam, LibreWolf, Bluetooth audio, chezmoi, dev tools, nix-ld), Dagger flake-lock pipeline, improved provision-ringtail workflow, services-check integration, and reference documentation.
- Add ringtail DeviceTags to Pulumi and allow homelab-to-homelab Tailscale SSH for cross-host ansible/management.
- Update Frigate zone masks from live config and expand alert notifications to cover both Driveway and Driveway_entrance zones.
- Add Apple Silicon ZMQ detector for Frigate — inference moves from in-pod ONNX CPU to CoreML on indri via ZMQ, using YOLOv9-m model
- Deploy Tailscale operator on ringtail k3s cluster
- Upgrade ntfy from v2.11.0 to v2.17.0 and add ntfy and frigate reference docs.
- Update External Secrets Operator Helm chart from 1.3.1 to 2.0.0 (operator v1.3.2)
- Upgrade Frigate NVR from 0.16.4 to 0.17.0-rc2 (prerequisite for Apple Silicon ZMQ detector)

### Documentation

- Add Dex OIDC documentation: reference card, federated login explanation, services-check integration, and updated plan.
- Update services-check and documentation to reflect Frigate, Mosquitto, and ntfy migration from indri minikube to ringtail k3s (PRs #216, #217).
- Review and fix update-documentation how-to: add missing cache purge step, clean up fragment types table.


## [v1.9.4] - 2026-02-17

### Documentation

- Reorganize how-to guides into `deployment/`, `configuration/`, and `operations/` subdirectories; review and update gandi-operations doc; fix missing cv.eblu.me CNAME in gandi reference card.


## [v1.9.3] - 2026-02-16

### Features

- Add service version review system with `mise run service-review` task, tracking file, and how-to guide.
- Add UniFi admin link to homepage dashboard bookmarks.

### Infrastructure

- Eliminate double towncrier run in release workflow — changelog is now built once on the runner, then the pre-processed source tree is passed to a new `build_quartz` Dagger function for the Quartz site build only.
- First service version review: pin mosquitto to 2.0.22, bump tailscale-operator to v1.94.2, record 7 reviewed services


## [v1.9.2] - 2026-02-16

### Features

- Add how-to guide for building container images and port navidrome to a custom-built container image.

### Bug Fixes

- Fix Frigate repeatedly alerting on parked cars by removing per-object max_frames and setting stationary interval to 0. Make Frigate config writable so UI changes (zones, masks) persist within a pod lifecycle.
- Switch navidrome to custom container image with dedicated non-root user and fsGroup security context

### Documentation

- Review expose-service-publicly doc: replace stale inline code with references to actual files, add observability sidecar section, fix broken internal link, update templates to current patterns.


## [v1.9.1] - 2026-02-15

### Documentation

- Review connect-to-postgres, create-release-artifact-workflow, and deploy-k8s-service docs. Fix stale repoURL, incorrect Caddy config keys, add Tailscale tag documentation, and migrate remaining `op item get` calls to `op read`.


## [v1.9.0] - 2026-02-14

### Features

- Deploy cloud-free NVR stack: Frigate 0.16.4 (ARM64) with ONNX/YOLO-NAS-s detection, Mosquitto MQTT broker, Ntfy self-hosted push notifications (with iOS APNs relay), and frigate-notify for detection alerting. GableCam (ReoLink Elite Floodlight) connected via RTSP with NFS recordings on sifaka, Grafana dashboard, Prometheus scraping, Homepage integration, and Caddy reverse proxies at nvr.ops.eblu.me and ntfy.ops.eblu.me.

### Infrastructure

- Configure DinD sidecar to use Zot as a pull-through registry mirror for Docker Hub images, reducing bandwidth and avoiding rate limits during Dagger CI builds.
- Abandon UniFi Pulumi IaC (provider bugs caused network outage); add manual three-network segmentation plan for UX7 web UI.
- Upgrade Node.js from 20 to 22 (LTS) in Dagger docs build and forgejo-runner container
- Tier 1 version bumps: upstream images (prometheus, loki, alloy, kube-state-metrics, tailscale, navidrome), helm charts (CloudNativePG, 1Password Connect), and custom containers (miniflux, kubectl, kiwix-serve, nettest, transmission) updated to latest stable versions with Alpine 3.22 base.

### Documentation

- Add how-to guide for connecting to PostgreSQL as a superuser via psql.
- Review add-ansible-role doc: fix secrets to use `op read`, match tag format to playbook, fix handler pattern, add last-reviewed date.
- Review and fix why-gitops doc: correct wiki-links, fix apt->brew, broaden Pulumi scope, add last-reviewed.


## [v1.8.2] - 2026-02-13

### Features

- Recategorize homepage groups: "Content" (Immich, Kiwix, Miniflux, DJ, Grafana) and "Misc" (CV, TeslaMate, Transmission, Docs, Prometheus, PyPI)

### Infrastructure

- Move non-secret forgejo-runner env vars from ExternalSecret to deployment spec so version bumps trigger automatic rollouts
- Add yq to forgejo-runner container and replace sed-based YAML editing in workflows with yq


## [v1.8.0] - 2026-02-12

### Features

- Update CV release to v1.0.2
- Update CV release to v1.0.3.

### Bug Fixes

- Fix cache hit rate panels on APM and Fly.io dashboards showing blank/red or misleading 100% for low-traffic static sites.

### Documentation

- Add reference/tools/ category with Dagger, ArgoCD CLI, Ansible, and Pulumi reference cards

### Miscellaneous

- Add X-Clacks-Overhead header to public proxy for cv and docs: GNU Terry Pratchett.


## [v1.7.1] - 2026-02-12

### Features

- Expose CV service publicly at cv.eblu.me via Fly.io proxy.
- Update CV service to resume release v1.0.1.

### Infrastructure

- Add CV to services-check (tailnet and public endpoints).

### Miscellaneous

- Update CV homepage link to use public URL (cv.eblu.me).
- Remove `/_error` test endpoint from Fly.io nginx proxy.


## [v1.7.0] - 2026-02-12

### Features

- Add CV/resume web app at cv.ops.eblu.me — container, k8s manifests, Caddy route, and deploy workflow. Content built from separate cv repo.

### Infrastructure

- Extend forgejo_actions_secrets Ansible role to support multiple repos.

### Documentation

- Add CV service reference card and update apps registry, Caddy docs, and services index.
- Add how-to guide for creating release artifact workflows with Forgejo packages.


## [v1.6.9] - 2026-02-11

### Bug Fixes

- Set ``TZ=America/Los_Angeles`` in the Dagger ``build_changelog`` container so towncrier stamps the correct local date instead of UTC (which showed tomorrow's date for evening releases).


## [v1.6.8] - 2026-02-11

### Documentation

- Update "Deploy K8s Service" how-to with current ProxyGroup ingress pattern.


## [v1.6.7] - 2026-02-11

### Documentation

- Close Dagger CI plan (Phases 1–3 complete) and move to completed plans archive.


## [v1.6.6] - 2026-02-11

### Features

- Simplify Forgejo runner image (Dagger Phase 3): remove Node.js, Docker CLI, buildx, skopeo, gnupg, lsb-release, and xz-utils. Add tzdata and flyctl. All build tools now live inside Dagger containers.

### Bug Fixes

- Restore Docker CLI to Forgejo runner image — Dagger shells out to ``docker`` to provision its BuildKit engine.
- Restore Node.js to Forgejo runner image — required by ``actions/checkout@v4`` and other JavaScript Actions that were broken by the Phase 3 simplification.


## [v1.6.4] - 2026-02-12

### Bug Fixes

- Set Forgejo runner timezone to America/Los_Angeles. The runner previously used UTC, causing towncrier changelog entries to show tomorrow's date when releases were cut in the evening. Note: the v1.6.2 changelog entry shows 2026-02-12 due to this bug; dates may appear non-sequential as a result.


## [v1.6.2] - 2026-02-12

### Features

- Migrate docs build pipeline to Dagger (Phase 2): `dagger call build-docs --src=. --version=dev` now runs the full Quartz build locally, identically to CI. Adds `date-modified` frontmatter to all docs and a `docs-check-frontmatter` pre-commit hook.
- Adopt Dagger as CI build engine for container images (Phase 1). Replaces the Docker buildx + skopeo composite action with a Dagger Python module. BuildKit's push is compatible with Zot, eliminating the skopeo workaround.

### Bug Fixes

- Fix blumeops-tasks: migrate from deprecated Todoist REST API v2 to API v1, handle cursor-based pagination, and use `op read` for 1Password credential retrieval.


## [v1.6.1] - 2026-02-11

### Bug Fixes

- Fix Fly.io proxy cache purge command for BusyBox shell compatibility.


## [v1.6.0] - 2026-02-11

### Bug Fixes

- Purge Fly.io proxy cache after docs deploy so new releases are served immediately.


## [v1.5.4] - 2026-02-11

### Bug Fixes

- Bump Fly.io proxy VM memory from 256MB to 512MB to prevent Alloy OOM kills.

### Documentation

- Add plan documents for Dagger CI/CD adoption and upstream fork strategy.
- Add plan documents for OIDC provider adoption, zot registry hardening, and expanded network segmentation details.
- Review security-model.md: fix op CLI pattern, add Tailscale Operator section.


## [v1.5.3] - 2026-02-11

### Features

- Add BorgBase offsite backup repository for 3-2-1 backup strategy
- Fly.io proxy serves a friendly error page when upstreams are unreachable (indri offline, Tailscale tunnel down, etc.). Test at `docs.eblu.me/_error`.
- Add `op-backup` mise task for encrypted 1Password disaster recovery backups via borgmatic
- Add SMART disk health monitoring for sifaka NAS with smartctl_exporter, Grafana dashboard, Ansible playbook, and Caddy L4 routing via ops.eblu.me.

### Bug Fixes

- Replace `op item get --fields` with `op read` in all mise tasks (tailnet-up, tailnet-preview, dns-up, dns-preview) to prevent multi-line secret corruption.
- Fix 502 errors during Fly.io proxy deploys by deferring health check until Tailscale is connected.
- Fix minikube ansible role not restarting cluster after power loss — status check only examined host VM state, missing stopped kubelet/apiserver.
- Log real client IPs in Fly.io proxy access logs using Fly-Client-IP header instead of showing the internal proxy address.

### Infrastructure

- Switch CI container builds from deprecated `docker build` to `docker buildx build` (BuildKit).
- Install `docker-buildx-plugin` in forgejo-runner image to support `docker buildx build`.
- Eliminate 502 errors during Fly.io proxy deploys by starting nginx after Tailscale, switching to bluegreen deploys, and using service-level health checks for traffic gating.

### Documentation

- Add troubleshooting guide for CNI conflict after unclean shutdown to restart-indri how-to.
- Add migration plan for Forgejo brew-to-source transition
- Document `op read` vs `op item get` convention for 1Password secret retrieval
- Add power infrastructure reference card documenting the battery-backed UPS chain (Anker SOLIX F2000 → CyberPower UPS → homelab).
- Add plan and reference card for UniFi Express 7 Pulumi IaC management.
- Add how-to guide for restoring 1Password backup from borgmatic, with cross-links from disaster recovery, borgmatic, 1password, and backup policy docs


## [v1.5.2] - 2026-02-09

### Features

- Filter blumeops-tasks to only show dated/recurring tasks when due today or earlier.
- Add `docs-review` mise task that sorts docs by `last-reviewed` frontmatter date, prioritizing never-reviewed cards. Updated the review-documentation how-to to match.

### Bug Fixes

- Fix fly-deploy WARNING by starting nginx before Tailscale, deferring upstream DNS resolution to request time.

### Infrastructure

- Migrate all Ansible `op item get` calls to `op read` URI syntax for cleaner output and remove the `regex_replace` workaround on the Fly deploy token.
- Restrict fly.io proxy ACLs to dedicated `tag:flyio-target` endpoints instead of broad `tag:k8s` and `tag:homelab` grants. Migrate all Tailscale Ingresses to a shared ProxyGroup with per-Ingress tag overrides (`tag:flyio-target` on docs, loki, prometheus). Add `autoApprovers` for VIP service routes. Enable `--accept-routes` on indri for ProxyGroup VIP routing.


## [v1.5.1] - 2026-02-08

### Features

- Add observability to Fly.io proxy: Alloy collects nginx access logs (→ Loki) and derived metrics (→ Prometheus), with Grafana dashboards for Docs APM and Fly.io proxy health.

### Infrastructure

- Add docs.eblu.me and Fly.io health check to services-check


## [v1.5.0] - 2026-02-08

### Features

- Add Fly.io public reverse proxy infrastructure for exposing services to the internet (first target: docs.eblu.me)

### Documentation

- Add how-to guide for exposing services publicly via Fly.io reverse proxy + Tailscale tunnel.
- Update docs for public proxy: canonical URL is now docs.eblu.me, add Fly.io proxy reference card and operations how-to


## [v1.4.2] - 2026-02-08

### Documentation

- Update all docs frontmatter titles from slug-case to human-readable and delete title-test cards.


## [v1.4.1] - 2026-02-08

### Documentation

- Remove docs-check-titles pre-commit hook, add repo links to homepage, and test duplicate frontmatter titles.


## [v1.4.0] - 2026-02-08

### Features

- Add documentation consistency checks: orphan detection in doc-links, new doc-index (category index coverage), doc-stale (staleness report), and doc-tags (tag inventory).

### Bug Fixes

- Fix broken icons for Pulumi and ArgoCD in homepage Admin bookmarks section.

### Infrastructure

- Add pre-commit to mise.toml project tools.

### Documentation

- Review exploring-the-docs tutorial: simplify wiki-links, fix broken replication/ reference, add Related section, match zk-docs flags to CLAUDE.md. Update use-pypi-proxy to document env-var-based proxy toggle.
- Add Gandi DNS reference card and operations how-to, rewrite homepage intro for wider audience.
- Add missing `ai` changelog fragment type to update-documentation guide, consolidate `cicd`→`ci-cd` and `network`→`networking` tags
- Updated restart-indri how-to to reflect actual recovery procedure after power outage. Added UPS to indri specs.
- Fixed zk-docs links after file renames due to relative path issues

### Miscellaneous

- Rename `doc-*` mise tasks to `docs-check-*` / `docs-review-*` for clearer naming convention.


## [v1.3.4] - 2026-02-05

### Documentation

- Enforce unique filenames, simple wiki-links (no paths), and no spaces in wiki-link targets for obsidian.nvim compatibility


## [v1.3.3] - 2026-02-04

### Infrastructure

- Add IaC for Forgejo Actions secrets via new `forgejo_actions_secrets` Ansible role, syncing repository secrets from 1Password to Forgejo API

### Documentation

- Add how-to guide for safely restarting indri, plus AutoMounter reference card.


## [v1.3.2] - 2026-02-04

### Infrastructure

- Fix Quartz build to use -d docs flag for accurate git-based file dates


## [v1.3.1] - 2026-02-04

### Infrastructure

- Fix Quartz build to preserve git history for accurate file dates

### Documentation

- Fix misc changelog fragment type to show content (was showing empty entries)


## [v1.3.0] - 2026-02-04

### Features

- Build workflow now supports version bump selection (major/minor/patch) and includes changelog in release body
- Add 'ai' changelog fragment type for AI assistance changes

### Bug Fixes

- Fix Navidrome automatic library scan by correcting env var name from `ND_SCANSCHEDULE` to `ND_SCANNER_SCHEDULE`

### Infrastructure

- Move CHANGELOG.md to repository root (still included in docs build)
- Remove iCloud Photos from borgmatic backup (photos now managed via Immich)

### Documentation

- Document Forgejo Actions secrets in forgejo reference card
- Add troubleshooting how-to to zk-docs output

### AI Assistance

- Add wiki-link formatting convention to AI assistance guide

### Miscellaneous

- ,


## [v1.2.1] - 2026-02-04

### Features

- Add doc-random mise task for random documentation review

### Documentation

- Add Caddy reference card and fix replication tutorial sequence


## [v1.2.0] - 2026-02-04

### Documentation

- Complete Phase 6: migrate zk content, delete legacy cards, rewrite zk-docs for AI context priming


## [v1.1.5] - 2026-02-04

### Documentation

- Add Phase 5 explanation docs: why GitOps, architecture overview, and security model


## [v1.1.4] - 2026-02-04

### Documentation

- Add Phase 4 how-to guides: deploy k8s services, add ansible roles, update tailscale ACLs, and troubleshooting


## [v1.1.3] - 2026-02-04

### Features

- Build workflow now automatically deploys docs after creating a release - updates the deployment manifest with the new release URL and syncs via ArgoCD, triggering a pod rollout

### Miscellaneous

- Remove confirmation prompt from container-tag-and-release task for non-interactive use


## [v1.1.2] - 2026-02-04

No significant changes.


## [v1.1.1] - 2026-02-04

### Documentation

- Add Phase 3 tutorials: "What is BlumeOps?", "Exploring the Docs", "AI Assistance Guide", "Contributing", and "Replicating BlumeOps" with sub-tutorials for Tailscale, Kubernetes, ArgoCD, and Observability. Each tutorial explicitly identifies its target audiences.


## [v1.1.0] - 2026-02-04

No significant changes.


## [v1.0.14] - 2026-02-04

No significant changes.


## [v1.0.13] - 2026-02-04

No significant changes.


## [v1.0.12] - 2026-02-04

No significant changes.


## [v1.0.8] - 2026-02-04

### Documentation

- Convert wiki-link titles to lowercase slugs for reliable Quartz resolution


## [v1.0.7] - 2026-02-03

### Documentation

- Switch to title-based wiki-links with validation (Quartz resolves via frontmatter title)


## [v1.0.6] - 2026-02-03

### Documentation

- Fix wiki-links to use filename-based resolution with Quartz shortest path mode


## [v1.0.5] - 2026-02-03

### Documentation

- Convert wiki-links to title-based format and add duplicate title detection


## [v1.0.2] - 2026-02-03

### Features

- Add Reference section with 24 technical reference cards covering services, infrastructure, kubernetes, and storage

### Documentation

- Reorder documentation phases: Reference (Phase 2) now comes before Tutorials (Phase 3) so other docs can link to reference material


## [v1.0.1] - 2026-02-03

### Infrastructure

- Add towncrier for automated changelog generation from news fragments


## [0.1.0] - 2026-02-03

This is a historical release which doesn't actually exist and which aggregates
the changelogs prior to this date. The work on this blumeops project more or
less began around Jan 16 2026. To an extent you can find corroborating details
in the git commit log, but at the beginning (during this initial phase) there
was a fairly large amount of non-source-controlled work. If a more accurate
record is needed for this work, you may find it in borgmatic zk backups from
this time period.

### Features

- Add Grafana Alloy for metrics remote_write to Prometheus
- Add Alloy DaemonSet for automatic pod log collection and service health probes
- Set up Borgmatic daily backups to Sifaka NAS with PostgreSQL streaming support
- Add CloudNativePG PostgreSQL metrics scraping via Tailscale service
- Add devpi PyPI caching proxy in Kubernetes with custom container image
- Add Forgejo Actions CI runner in Kubernetes with host mode execution
- Add Homepage service dashboard with automatic Kubernetes service discovery
- Add Jellyfin media server with VideoToolbox hardware transcoding on indri
- Add Kiwix offline Wikipedia server with kiwix-tools on indri
- Add kube-state-metrics for Kubernetes resource metrics (pods, deployments, etc.)
- Add Loki log aggregation with 31-day retention and Grafana integration
- Add Miniflux RSS/Atom feed reader connected to PostgreSQL
- Add Navidrome music streaming server with NFS storage from Sifaka
- Add Prometheus metrics collection on indri with Sifaka node_exporter scraping
- Add TeslaMate vehicle data logger with 18 Grafana dashboards
- Add Transmission BitTorrent daemon for ZIM archive downloads
- Add Zot OCI registry as pull-through cache for Docker Hub, GHCR, and Quay

### Bug Fixes

- Build Alloy with CGO for macOS native DNS resolver (fixes Tailscale MagicDNS)
- Suppress noisy "v1 Endpoints is deprecated" warning from minikube storage-provisioner

### Infrastructure

- Deploy ArgoCD for GitOps continuous delivery with manual sync policy for workloads
- Set up Caddy reverse proxy for *.ops.eblu.me with ACME DNS-01 TLS via Gandi
- Deploy CloudNativePG operator and blumeops-pg PostgreSQL cluster in Kubernetes
- Migrate Grafana from Homebrew to Kubernetes via Helm chart
- Migrate Kiwix to Kubernetes with torrent-sync sidecar and ZIM watcher CronJob
- Migrate Loki to Kubernetes StatefulSet with 50Gi PVC
- Migrate Miniflux from Homebrew to Kubernetes with CloudNativePG database
- Set up Minikube single-node Kubernetes cluster on indri with Tailscale API access
- Migrate minikube from podman to docker driver for better stability and NFS support
- Manage Prometheus configuration via Ansible
- Migrate Prometheus to Kubernetes StatefulSet with 50Gi PVC
- Set up Pulumi for Tailnet ACL management with OAuth authentication
- Migrate Transmission to Kubernetes with NFS storage from Sifaka
- Migrate Zot registry from Tailscale serve to Caddy reverse proxy at registry.ops.eblu.me
- Integrate Zot as minikube registry mirror for all image pulls
