# Changelog

All notable changes to BlumeOps are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<!-- towncrier release notes start -->

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
