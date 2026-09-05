---
title: Security
modified: 2026-09-02
last-reviewed: 2026-08-30
tags:
  - operations
  - security
---

# Security

Security posture and periodic scanning for BlumeOps infrastructure.

> BlumeOps runs a weekly CIS Kubernetes Benchmark scan as a hygiene check, not as part of a formal compliance program. It once doubled as a PCI DSS / SOC 2 practice environment; that framing has been retired. The scan stays because it's a cheap, useful baseline — findings are triaged, remediated, or mutelisted with a written justification.

## Scanning tools

- [[prowler]] — CIS Kubernetes Benchmark scanner (weekly CronJob on ringtail). The container-image CVE scan and IaC scan were retired in 2026-06 (un-actioned noise — see [[deploy-prowler#Why only the K8s CIS scan]]); only the K8s CIS scan remains.
  - [[deploy-prowler]] — deployment and ad-hoc scan how-to
  - [[read-compliance-reports]] — accessing and interpreting reports
- Secret detection — [TruffleHog](https://github.com/trufflesecurity/trufflehog) runs as a prek hook on every commit/push.

## Pod Security Admission (PSA)

PSA is the preventive complement to the Prowler scan. Namespace-level
`pod-security.kubernetes.io/{enforce,warn,audit}` labels reject (or warn about)
insecure pods at admission time, closing the "deployed a new service
insecurely" class before it exists. Prowler stays as the RBAC-drift and
control-plane audit backstop behind it (PSA doesn't cover RBAC).

Rollout (heph `01KVQX81703HDE77ED88XDPSR2`):

1. Label every app namespace with `warn` + `audit` at its target level;
   enforce nothing. Zero risk by construction — violations surface as API
   warnings and audit events, nothing is denied.
2. Read the warnings and fix the near-miss workloads field by field.
3. Switch on `enforce` per namespace as each goes quiet; exemptions last.

Current state: step 2 is landed (#772, 2026-09-01) — the four
restricted-required fields (`runAsNonRoot` + `seccompProfile: RuntimeDefault`
at pod level, `allowPrivilegeEscalation: false` + `capabilities drop ALL` at
container level) are on the near-miss workloads under eblume/blumeops#753
(no `enforce` yet). Eight workloads whose images run as root wedged in
`CreateContainerConfigError` and were rolled back on all four fields
(ed4c0667); per-workload decisions for them are below (eblume/blumeops#797)
and each one still blocks its namespace's `enforce` flip until acted on.

Three workloads remain documented exceptions that block their own
namespace's `enforce` flip: grafana's `init-chown-data` init container runs
as root with CHOWN (needs a non-root chown pattern), birdnet-go (added after
this rollout's label pass, #765) runs its whole container as root (upstream
image has no USER; needs a non-root image or uid+PVC-ownership work), and
frigate (upstream image with an s6-overlay root entrypoint and no supported
non-root path — see decision table). Enforcement follows in per-namespace
PRs once warnings are quiet.

### Non-root decisions — the eight rolled-back workloads

Signed off per the eblume/blumeops#797 thread (2026-09-04).
House pattern for the local nix images: `User` in the `dockerTools` config +
matching pod `securityContext` (navidrome precedent). NFS-backed volumes
(sifaka) never get `fsGroup` — kubelet would chown the whole share
recursively at every mount. The plan called for a one-time pre-chown to
uid/gid 1000 on the NAS instead, but checking sifaka directly (2026-09-05)
showed it is unnecessary: both shares (`/volume1/paperless`,
`/volume1/photos`) export with `Squash=No mapping` and every object is mode
0777 under the Synology ACL (owner `admin:users`), so uid 1000 can already
create, modify and delete there. Ownership stays `admin:users` so File
Station keeps working; new files land as 1000:1000, which is fine.

| Workload (namespace) | Image (source) | Decision | Work needed |
|---|---|---|---|
| authentik-redis (authentik) | local `blumeops/authentik-redis` (nix, redis 8.6.3) | non-root image | `User` in `containers/authentik-redis/`; no volumes, so no fsGroup |
| immich-valkey (immich) | local `blumeops/valkey` (nix, 8.1.7) | non-root image | `User` in `containers/valkey/`; fsGroup 1000 on the `/data` emptyDir. Same image serves paperless's redis sidecar (emptyDir there too) |
| mealie (mealie) | local `blumeops/mealie` (nix, 3.20.1) | non-root image | `User` in `containers/mealie/`; fsGroup 1000 on the local-path data PVC (`init_db` writes `/app/data` at start) |
| paperless (paperless) | local `blumeops/paperless` (nix, 2.20.15) | non-root image | `User` in `containers/paperless/`; fsGroup on the emptyDir data volumes; media PVC is NFS (sifaka:/volume1/paperless) → one-time pre-chown to uid/gid 1000, no fsGroup there |
| teslamate (teslamate) | local `blumeops/teslamate` (nix, mix release 3.0.0) | non-root image | `User` in `containers/teslamate/` + a writable uid-owned `/opt/app` created in the image so HOME and SRTM_CACHE point at a directory that exists; stateless otherwise |
| frigate (frigate) | upstream `ghcr.io/blakeblackshear/frigate:0.17.1-tensorrt` | **PSA exception** | s6-overlay root entrypoint; PUID/PGID unimplemented upstream (frigate GH #3434, discussion #22837); /dev/shm log dirs and root-owned /config plus the NFS /media share break non-root. Revisit if upstream ships a non-root path |
| immich-server (immich) | upstream `ghcr.io/immich-app/immich-server:v3.0.2` | non-root via manifest | upstream's blessed rootless pattern is `user: 1000:1000` (immich's `docker-compose.rootless.yml`); runAsUser/runAsGroup 1000 + the four fields. Library PVC is NFS (sifaka:/volume1/photos, 2Ti) → deliberately **no fsGroup**; no pre-chown needed either (share is 0777, see above) |
| immich-machine-learning (immich) | upstream `ghcr.io/immich-app/immich-machine-learning:v3.0.2-cuda` | non-root via manifest | same rootless pattern; runAsUser 1000 + fsGroup 1000 on the cache PVC + the four fields; emptyDirs at `/.config` and `/.cache` (uid 1000 has no passwd entry, HOME is `/`; upstream FAQ lists both as required writable paths) |

| Namespace(s) | Target | Notes |
|---|---|---|
| 1password, argocd, authentik, external-secrets, homepage, horkos, immich, kiwix, mealie, miniflux, monitoring, navidrome, ntfy, paperless, shower, teslamate, torrent | `restricted` | near-misses fixed in step 2; the eight root-image workloads follow the decision table above |
| ollama, talos | `baseline` | hostPath use |
| alloy | exempt | alloy-tracing-ringtail needs privileged + hostPID (Beyla eBPF) |
| frigate | exempt | root s6-overlay entrypoint, no supported non-root path (decision table above) |
| nvidia-device-plugin | exempt | privileged + hostPath |
| prowler | exempt | hostPID + hostPath (the scanner reads the node it audits) |
| cnpg-system, databases, tailscale | deferred | operator-created pods have no repo manifest; judged with kubectl before labeling |

## Identity & access

- [[authentik]] — SSO/OIDC provider for all web services
- RBAC — Kubernetes role-based access control (audited by Prowler RBAC checks)

## Network & TLS

- [[caddy]] — TLS termination for `*.ops.eblu.me` services
- [[flyio-proxy]] — public ingress via Fly.io tunnel
- Tailscale — zero-trust mesh networking across all nodes

## Secrets management

- [[1password]] — root credential store
- [[external-secrets]] — Kubernetes secrets synced from 1Password

## Reports

All scan reports are stored on `sifaka:/volume1/reports/`. See [[read-compliance-reports]] for access and interpretation.

Suppressed findings are kept in Prowler mutelist YAML under `argocd/manifests/prowler-ringtail/mutelist/`. Each entry's `Description` field explains why the finding is muted; entries are reviewed ad-hoc rather than on a scheduled cadence.

## Known gaps

- k3s control plane checks produce no results (embedded binary, no static pods) — consider kube-bench
- No container-image CVE scanning (the Prowler image scan was retired 2026-06 as un-actioned noise). If reintroduced, scope it to critical-severity, currently-deployed tags, alert-on-new
- No automated IaC misconfiguration scanning (the Prowler IaC scan was retired 2026-06). Pod Security Admission (see above) now carries the preventive pod-security control; the accept-and-document gap is closed as enforcement rolls out.
