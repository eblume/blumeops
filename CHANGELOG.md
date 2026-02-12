---
title: changelog
tags:
  - meta
---

# Changelog

All notable changes to BlumeOps are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<!-- towncrier release notes start -->

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
