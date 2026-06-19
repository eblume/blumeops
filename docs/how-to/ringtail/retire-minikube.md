---
title: Retire minikube on indri
modified: 2026-06-11
last-reviewed: 2026-06-10
tags:
  - how-to
  - operations
  - ringtail
  - migration
---

# Retire minikube on indri

**COMPLETE 2026-06-11: all six phases executed in a single day** —
minikube is deleted, every Kubernetes workload (including ArgoCD) runs
on `k3s-ringtail`, and the forgejo-runner serves host-mode jobs as a
native launchd service on indri. This card is retained as the
historical plan and execution record.

Move every remaining Kubernetes workload off `minikube-indri` onto
`k3s-ringtail`, convert the forgejo-runner into a native macOS launchd
service on indri (ansible-managed), and decommission minikube
entirely. This is the umbrella plan for the final act of the
indri-k8s decommission that began with [[migrate-immich-to-ringtail]]
and [[migrate-wave1-ringtail]].

**Trigger:** prometheus container builds (runs #587/#589, 2026-06-10)
killed Docker Desktop on indri at the ~33-minute mark — the runner
lives inside minikube and source builds compete with the LGTM stack
inside the shrunken VM. PR #375 (prometheus v3.12.0) is parked on
this. Beyond the immediate pressure, the single-node minikube setup
has been chronically overcommitted (OOM episodes 2026-04 and
2026-06).

## End state

- indri runs **native services only**: Forgejo, Zot, Caddy, Borgmatic,
  Alloy, heph, devpi, Jellyfin, docs/CV — plus the forgejo-runner as a
  launchd service backed by Docker Desktop.
- ringtail k3s hosts **all** Kubernetes workloads, including ArgoCD
  itself.
- minikube is deleted from indri; the `minikube` and
  `minikube_metrics` ansible roles, the `minikube-indri` kubeconfig,
  and all minikube-targeted ArgoCD apps/manifests are removed.
- Service hostnames (`*.ops.eblu.me`) are unchanged throughout — Caddy
  on indri remains the single routing entry point, and Tailscale
  ingress device names transfer from minikube to ringtail per service.

## Non-goals

- Version bumps beyond what the Nix ports force (lift-and-shift,
  except prometheus, which lands v3.12.0 as its port — unparking
  PR #375).
- Localizing the remaining *external* images (loki/tempo are already
  local; argocd/cnpg/external-secrets/1password-connect stay upstream
  multi-arch for now — tracked separately by the local-registry
  compliance task).
- ~~Removing Docker Desktop from indri.~~ Scope expanded 2026-06-11:
  indri goes fully docker-free — see phase 6. (During phases 0–5 the
  runner still uses Docker Desktop; the flip to host-mode jobs and
  Docker removal come after minikube delete.)

## Constraints

### No data loss (downtime is fine)

Cold cutovers per service, same discipline as
[[migrate-wave1-ringtail]]: quiesce the source, copy, **verify, then**
flip routing; never drop the source until the ringtail side has
served real traffic. Run a manual [[borgmatic]] backup before each
data-bearing phase as the backstop.

Data surfaces:

| Surface | Where today | Size | Notes |
|---|---|---|---|
| miniflux DB | minikube `blumeops-pg` | small | feeds, read state |
| **authentik DB** | minikube `blumeops-pg` | small | **SSO identities for everything**; authentik *runs* on ringtail but reaches its DB cross-cluster via `pg.ops.eblu.me:5432` (host value lives in the 1Password item) |
| prometheus TSDB | minikube PVC | 20Gi | long-retention metrics |
| loki chunks | minikube PVC | 20Gi | log history |
| tempo traces | minikube PVC | 10Gi | lowest value, copy anyway |
| grafana sqlite | minikube PVC | 1Gi | dashboards/alerts are in git, but annotations/silences/history are not |
| navidrome data | minikube PVC | 10Gi | play counts, playlists (music itself is read-only NFS) |
| NFS shares (torrents/music/reports) | sifaka | — | never move; remount from ringtail (see [[sifaka-nfs-from-ringtail]]) |
| forgejo-runner | emptyDir | — | no persistent state |

Ringtail has ~490Gi free on `local-path`; the ~61Gi of new PVCs fit
comfortably.

One caveat to state honestly: metrics/logs *scraped during* the LGTM
cutover window are buffered by the alloy WALs only for a bounded time.
Keep that window short; a small scrape gap is downtime, not stored
data loss.

### Architecture: indri builds are arm64, ringtail is amd64

Every locally-built image currently deployed on minikube is a
single-arch **arm64** image (built by the in-cluster runner on Apple
Silicon) and will not run on ringtail (x86_64) — the valkey
exec-format failure in wave 1 proved this the hard way. Per the
standing wave-1 decision, each migrating container gets a **Nix
`default.nix` port** built by the ringtail `nix-container-builder`
(`-nix` amd64 tags).

Ports needed (all in `containers/`, currently Dockerfile/container.py
only): `miniflux`, `navidrome`, `kiwix-serve`, `kubectl`,
`transmission`, `transmission-exporter`, `prowler`, `unpoller`,
`prometheus`, `loki`, `tempo`, `grafana`, `grafana-sidecar`.

Already ported (wave 1 and prior): alloy, authentik(+redis),
external-secrets, homepage, kingfisher, kube-state-metrics, mealie,
ntfy, paperless, shower, tailscale(+operator), teslamate, valkey.
ArgoCD itself uses pinned upstream multi-arch images — no port needed.

Most ports should be thin wrappers over nixpkgs (miniflux, navidrome,
kiwix-tools, transmission, kubectl, prometheus, grafana, loki, tempo
are all packaged); transmission-exporter and grafana-sidecar are small
from-source builds; prowler is the established custom container.
Iterate with `nix-build` directly on ringtail before the real forge
build (wave-1 technique).

## Execution model

Each phase is its own **C1** feature branch + PR, deployed from the
branch and merged after verification — exactly the wave-1 cadence.
This card is the umbrella plan; per-phase PRs update it as reality
intrudes.

## Phase 0 — forgejo-runner → launchd on indri ✅ (2026-06-11)

Unblocks PR #375 immediately and removes the build/VM resource
contention that triggered this project. No data at risk.

New ansible role `forgejo_runner` (model on the `heph` + `forgejo`
launchd patterns):

- **Binary:** build the macOS arm64 `forgejo-runner` binary from the
  existing mirror at `~/code/3rd/forgejo-runner`, pinned to the
  deployed version (v12.8.2) — same source-build approach as the
  `forgejo` role. No container image for the runner itself.
- **Config:** port `argocd/manifests/forgejo-runner/config.yaml`.
  Capacity 2, same 3h timeouts. Jobs keep running as containers
  (`docker://registry.ops.eblu.me/blumeops/runner-job-image:...`,
  arm64 — correct for indri) against Docker Desktop's daemon
  (`unix:///var/run/docker.sock` instead of the DinD sidecar's
  `tcp://127.0.0.1:2375`).
- **Labels:** advertise both `k8s` (compatibility — every workflow in
  every forge repo uses `runs-on: k8s`, including template-derived
  projects) and a new honest `indri` label. Migrate workflows
  opportunistically; drop `k8s` in a later cleanup.
- **Registration:** new 1Password fields `runner_indri_uuid` /
  `runner_indri_token` in the "Forgejo Secrets" item, fetched via
  ansible `pre_tasks` `op read`. A distinct identity lets the launchd
  runner and the k8s runner coexist during testing, and makes
  rollback "scale the k8s deployment back up."
- **Registry mirror:** the DinD `daemon.json` pointed at
  `host.minikube.internal:5050` (zot). Docker Desktop's daemon needs
  the equivalent mirror (`http://host.docker.internal:5050` — verify
  the daemon itself resolves it; fall back to indri's tailnet name).
  Managed via `~/.docker/daemon.json`; note Docker Desktop must
  restart to pick it up.
- **Logs:** `~/Library/Logs/mcquack.forgejo-runner.{out,err}.log`,
  plus an alloy role addition to ship them to Loki like the other
  indri services.

Cutover: deploy the launchd runner alongside the k8s one → re-run the
prometheus build workflow (the job that killed Docker Desktop) pinned
to the new runner → once green, scale the k8s runner to 0 → after a
few days of clean runs, delete the `forgejo-runner` app + manifests
and the old uuid/token fields. Update the [[forgejo-runner]] reference
and replace the configure-k8s-runner how-to with
[[configure-launchd-runner]].

## Phase 1 — simple apps to ringtail ✅ (2026-06-11)

miniflux, kiwix, torrent (transmission), navidrome, unpoller, prowler
— one service at a time, each following the wave-1 cold-cutover steps
(quiesce → copy data → verify → delete minikube tailscale ingress to
release the device name → sync `<app>-ringtail` → verify
`services-check`).

Service-specific notes:

- **miniflux:** create the `miniflux` database + role in ringtail's
  `blumeops-pg` (out-of-band or Database CR — ringtail's bootstrap
  created only `paperless`), `pg_dump`/`pg_restore` from the quiesced
  source, repoint the app at
  `blumeops-pg-rw.databases.svc.cluster.local`, verify row counts
  (feeds, entries, users). Update the borgmatic miniflux entry from
  port 5432 → 5434.
- **navidrome:** copy the 10Gi `navidrome-data` PVC via helper pods
  (wave-1 mealie technique); music stays read-only NFS from sifaka.
- **torrent + kiwix:** share the sifaka `torrents` NFS export —
  recreate the NFS PV/PVC pair on ringtail (shower/paperless pattern).
  kiwix's zim-watcher CronJob runs `kubectl` against its own
  deployment: port the RBAC and the local `kubectl` image.
- **prowler:** reports NFS PV remounts; scanning target becomes
  ringtail — this folds in the standing "prowler scan against
  ringtail" task. `review-compliance-reports`' minikube node
  verification goes away in phase 5.
- **unpoller:** stateless; just needs the Nix port and tailnet/LAN
  reachability to the UX7.

## Phase 2 — authentik DB move ✅ (2026-06-11), retire minikube blumeops-pg (soaking until ~2026-06-18)

Small, but the highest-blast-radius data surface: authentik is SSO
for ArgoCD, Grafana, forge, and everything else. Must complete before
phase 4 (ArgoCD re-login depends on working SSO).

1. Manual borgmatic run (backstop), then quiesce authentik on
   ringtail (scale server+worker to 0) — no writers.
2. `pg_dump` authentik from minikube `blumeops-pg`, `pg_restore` into
   ringtail `blumeops-pg` (create role/db first). Versions match
   (PG 18.x both sides); plain dump/restore, no Django migrations
   involved.
3. Verify row counts (`authentik_core_user`, groups, providers,
   applications) and a schema-only diff.
4. Update the `postgresql-host` field in the 1Password
   "Authentik (blumeops)" item from `pg.ops.eblu.me` to
   `blumeops-pg-rw.databases.svc.cluster.local` (authentik is already
   on ringtail — in-cluster DNS now works and removes the cross-host
   SPOF). Force the ExternalSecret refresh, scale back up.
5. Log in via SSO (Grafana or forge) **and** keep one authentik admin
   session/recovery path open during the window.
6. Update borgmatic's authentik entry 5432 → 5434; verify a dump.

After the authentik move, minikube `blumeops-pg` carries no live
tenants (the miniflux database was deliberately left in place at its
phase-1 cutover — it retires with the cluster): keep it idle for a
week, then remove the `blumeops-pg` + `cloudnative-pg` minikube apps. Retire the Caddy L4 `:5432` route and
its `.pgpass` line (5433 immich / 5434 blumeops-pg-ringtail remain);
the `pg.tail8d86e.ts.net` device name dies with the minikube ingress.

## Phase 3 — observability stack ✅ cutover 2026-06-11 (minikube LGTM parked for rollback soak)

prometheus, loki, tempo, grafana (+grafana-config), and deletion of
minikube-only alloy-k8s / kube-state-metrics (ringtail variants
already run). Sequenced after the app waves so monitoring stays up
while they move.

- Nix ports for prometheus/loki/tempo/grafana(+sidecar) — built on
  ringtail, which **permanently solves the builds-kill-indri problem**
  for the LGTM stack. Prometheus lands v3.12.0 here, superseding
  PR #375's docker-pipeline build.
- Data copy per service, cold: scale the source StatefulSet to 0, tar
  the PVC contents between helper pods across clusters
  (`kubectl exec tar -c | kubectl exec tar -x`), verify sizes/block
  counts, bring up on ringtail, then release/claim the tailscale
  ingress name. Prometheus first (largest, most valuable), then loki,
  tempo, grafana.
- During each window, writers buffer: indri alloy and ringtail alloy
  remote_write/loki push retry against `prometheus.ops.eblu.me` /
  `loki.ops.eblu.me` (Caddy hostnames, unchanged). Keep each window
  well under the WAL horizon (~2h).
- **alloy-k8s survives this phase** (deviation from the original plan
  to delete it here): it still ships minikube pod logs and absorbs the
  in-cluster scrapes the minikube prometheus loses at cutover (argocd
  metrics — the argocd-sync alert depends on them — and minikube
  kube-state-metrics). Its loki/prometheus endpoints and the
  prometheus/loki/grafana blackbox probes repoint to the external
  names. argocd's scrape dies in phase 4, the rest in phase 5.
- prometheus-ringtail's scrape config also picks up **in-cluster CNPG
  metrics for both ringtail pg clusters** (new ClusterIP metrics
  services in databases-ringtail) — closing a pre-existing gap: only
  the minikube blumeops-pg was ever scraped, and it idles toward
  retirement, which would have left the postgres-cluster-unhealthy
  alert evaluating nothing.
- Grafana datasource URLs are in-cluster names — identical on
  ringtail (`monitoring` namespace). The TeslaMate datasource already
  points at `:5434`. Verify dashboards, alert rules, and the alerting
  → ntfy pipeline post-move.
- indri-side alloy needs **no change**: it writes to the
  `*.ops.eblu.me` hostnames, which flip transparently when the
  ingress device names transfer.

## Phase 4 — ArgoCD self-migration ✅ (2026-06-11)

Last workload off minikube, after everything it manages already runs
on ringtail.

1. Stand up ArgoCD on ringtail from the same kustomization (upstream
   multi-arch images; external-secrets + 1password-connect-ringtail
   already provide the forge repo credential).
2. Fold in the "rotate argocd admin password" task — fresh
   `argocd-secret` on the new install.
3. Release the `argocd` tailscale ingress name from minikube, claim
   it on ringtail. Hostname (`argocd.ops.eblu.me`) and therefore the
   Authentik OIDC redirect URLs are unchanged — no Authentik edits.
   The RBAC patch already grants both the SSO `admins` group and the
   break-glass local admin.
4. Rewrite app destinations: ringtail-targeted apps switch from
   `https://ringtail.tail8d86e.ts.net:6443` to in-cluster
   `https://kubernetes.default.svc`; the `apps` app-of-apps moves
   with them. No minikube cluster secret on the new install.
   **Critical corollary (added at execution):** every minikube-only
   Application definition must be DELETED from `argocd/apps/` in the
   same change — after the move, `kubernetes.default.svc` means
   ringtail, and a stale minikube app definition would deploy minikube
   infra (tailscale-operator, blumeops-pg, …) onto ringtail. Their
   live minikube workloads keep running unmanaged until phase 5;
   alloy-k8s config changes deploy manually via
   `kubectl kustomize | kubectl apply` from then on. The argocd
   metrics job moves back in-cluster (prometheus-ringtail) and its
   alloy-k8s scrape + blackbox probe are removed (the live alloy-k8s
   needs one manual apply at cutover for this).
5. Sync everything from the new ArgoCD; scale the minikube ArgoCD's
   controllers to 0 (don't delete until phase 5).
6. `argocd login argocd.ops.eblu.me --sso` re-login; verify
   `mise run services-check` end to end.

## Phase 5 — decommission and cleanup ✅ (2026-06-11, soak collapsed by user call)

Only after every prior phase has soaked:

1. Delete remaining minikube infra apps (tailscale-operator last — it
   owns the ingress proxies; external-secrets(+crds),
   1password-connect, alloy-k8s, kube-state-metrics, argocd).
2. `minikube stop`. Park one week as the final rollback window.
3. **`minikube delete` — explicit user go required** (AGENTS.md hard
   rule), then `brew uninstall minikube`, remove the
   `~/.kube/minikube-indri` kubeconfig. Docker Desktop **stays** (the
   runner needs it).
4. Ansible: drop `minikube` + `minikube_metrics` roles from
   `indri.yml` and delete the role dirs.
5. mise-tasks: `services-check` (remove minikube/apiserver checks;
   point the ArgoCD app query at ringtail),
   `ensure-minikube-indri-kubectl-config` (delete),
   `review-compliance-reports` (remove `_ssh_minikube` node
   verification), `runner-logs` (comment updates only).
6. Pulumi: remove `tag:k8s-api` and `tag:loki` from indri's device
   tags; sweep `policy.hujson` for rules referencing them. Clean up
   stale tailnet devices, including the `ingress-0-1` rename debt.
7. Docs sweep: delete/archive `rebuild-minikube-cluster` (done); revise
   [[restart-indri]], [[architecture]], the kubernetes cluster +
   tailscale-operator reference cards, [[indri]],
   disaster-recovery, deploy-k8s-service, mise-tasks reference, and
   **AGENTS.md** (rule 2's `--context=minikube-indri` and the
   minikube-delete warning invert: `k3s-ringtail` becomes the only
   context). Remove the minikube entry from `service-versions.yaml`.
8. Final `mise run services-check` + a full borgmatic run.

## Phase 6 — host-mode runner (scope revised: Docker Desktop stays for dagger) ✅ (2026-06-11)

**Decision (2026-06-11): indri goes fully docker-free.** The Docker
Desktop guest VM doesn't play well with indri's native workloads, and
once every service image is Nix-built amd64 on ringtail, the only
things keeping docker around are the runner's job containers and
dagger.

**Scope revised at execution (2026-06-11): Docker Desktop STAYS.**
The original "docker-free indri" goal assumed the docs build was the
only non-container-build dagger user — wrong: `hephaestus` runs its
whole cargo CI via `dagger call check` and `cv` releases via
`dagger call build`. Rather than rework three repos' CI, Docker
Desktop survives **solely as the dagger engine host**, right-sized
from the minikube-era 6cpu/8GiB down to **2cpu/4GiB** (the heaviest
remaining job is the Quartz docs build, ~1–1.5GiB; container image
builds are all nix-on-ringtail now). What actually shipped:

- The runner flips to **host-mode jobs**: labels `k8s:host` /
  `indri:host`, jobs run directly as `erichblume` with indri's
  mise-managed toolchain (PATH gets mise shims in the launchd plist).
  `runner-job-image` is deleted; dagger pipelines work unchanged —
  the CLI (mise-pinned `dagger@0.20.6`, matching `dagger.json`) talks
  to the engine in Docker Desktop. `prek@0.3.4` joins the host
  toolchain, fixing the standing template-`validate` issue. flyctl is
  self-installed by `deploy-fly`; nothing in CI needs argocd.
- The stale arm64 build files are deleted (every remaining
  `container.py` except the dagger module itself, plus the
  kube-state-metrics/ntfy/kubectl Dockerfiles), and
  `build-container.yaml` is nix-only.
- The zot docker.io mirror in Docker Desktop's `daemon.json` stays —
  the dagger engine still pulls base images through it.
- Accepted trade: no container isolation for CI jobs. In this setup
  the boundary was already thin — jobs could reach the host docker
  socket, and the runner shares a host (and user) with the forge
  itself. Mitigations: Actions stay disabled for the `mirrors/` org
  (the one place third-party commits could reach CI); a dedicated
  runner user is optional future hardening.
- Host-mode moots the dagger-version-decoupling (now an explicit mise
  pin) and DinD-cache-PVC tasks.

## Cross-cutting cautions

- **Tailscale device names:** always delete the minikube ingress
  *before* the ringtail one claims the name, or you get `-1`-suffixed
  devices (the existing `ingress-0-1` debt). ProxyGroup ingresses
  must omit `host:` or use `host: *`.
- **ArgoCD hashed configmaps:** sync with `--prune` when configmap
  hashes change, or orphans accumulate (wave-1 lesson).
- **`-nix` tags only on ringtail** — a plain (arm64) tag fails with
  exec format error, sometimes confusingly mid-rollout.
- **sifaka NFS** from ringtail requires sifaka's Tailscale TUN mode
  (see [[sifaka-nfs-from-ringtail]]).
- **borgmatic `.pgpass`** is a hardcoded host/port list — every DB
  port change needs a matching line, and a verified dump afterwards.

## Open decisions (flagged for review)

1. **Runner label strategy** — recommendation above: advertise
   `k8s` + `indri`, migrate workflows opportunistically. Alternative:
   keep only `k8s` forever (zero churn, misleading name).
2. **App naming** — keep the `-ringtail` suffix convention for the
   new apps (consistent with wave 1) even though it becomes noise
   once ringtail is the only cluster; optional rename sweep later.
3. **Caddy L4 `:5432`** — plan retires it; alternative is repointing
   it at ringtail as an alias. Retirement is cleaner; nothing should
   reference it after phase 2.
4. **Phase 1 service order** — proposed: miniflux → navidrome →
   torrent+kiwix → unpoller → prowler, but they're independent.
