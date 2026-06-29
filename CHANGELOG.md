---
title: changelog
tags:
  - meta
---

# Changelog

All notable changes to BlumeOps are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<!-- towncrier release notes start -->

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
