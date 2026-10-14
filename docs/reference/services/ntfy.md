---
title: Ntfy
modified: 2026-10-14
last-reviewed: 2026-10-14
tags:
  - service
  - notifications
---

# Ntfy

Self-hosted push notification service. Ntfy receives HTTP POST messages and delivers them to subscribed clients (mobile apps, web UI, CLI).

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://ntfy.ops.eblu.me |
| **Tailscale URL** | https://ntfy.tail8d86e.ts.net |
| **Namespace** | `ntfy` |
| **Image** | `registry.ops.eblu.me/blumeops/ntfy:v2.28.0-2288d19-nix` (locally built) |
| **Upstream** | https://github.com/binwiederhier/ntfy |
| **Manifests** | `argocd/manifests/ntfy/` |
| **Topic declaration** | `ntfy/topics.json` |

## Architecture

Ntfy runs as a single pod with no persistent storage — message cache and attachments use an `emptyDir` volume. This is intentional: ntfy is treated as an ephemeral delivery channel, not a message store. Messages lost on pod restart are acceptable.

The upstream relay (`ntfy.sh`) is configured so mobile app clients can receive push notifications via Google FCM / Apple APNs without self-hosting those integrations.

## Topics

Mirrors `ntfy/topics.json` — the declared-state file that is the single source of truth for topics, checked by `mise run ntfy-lint` (a topic literal in the tree that is not declared there fails CI).

| Topic | Purpose | Volume | Priority | Actionable | Producers |
|-------|---------|--------|----------|------------|-----------|
| `ops-approvals` | Warrant requests, auto-apply refusal/failure alerts, the weekly auto-apply digest, host apply verdicts (ringtail / indri rebuild watchers) | a handful per day; bursts on rebuild failures | 3 | yes | `.forgejo/workflows/auto-apply-digest.yaml`, `.forgejo/workflows/provision-indri.yaml`, `.forgejo/workflows/ringtail-rebuild.yaml`, `mise-tasks/request-run`, the two host apply watchers |
| `infra-alerts` | Grafana Unified Alerting pipeline: service health, pod readiness, PostgreSQL, textfile freshness, Frigate cameras, ArgoCD sync status | a few per day; group_wait 1m, group_interval 12h, repeat_interval 24h | 3 | yes | `argocd/manifests/grafana-ringtail/alerting.yaml` |
| `frigate-alerts` | Frigate camera detection events (person, car) in the driveway zones, with action buttons into the review UI | a few per day in driveway zones only | 3 | no | `argocd/manifests/frigate/frigate-notify-config.yml` |
| `ceramics` | Skagit CCE ceramics watch — **retired 2026-09-01**, kept declared so a silent re-addition fails the lint | none — producer retired | 3 | (was yes) | none |

### Adding a producer to a topic

A recurring notification on a phone-subscribed topic is a **reviewed change to `ntfy/topics.json`**: update the topic's `producers` and `budget.volume` there (and this table), then add the literal in the code. An undeclared topic literal fails `mise run ntfy-lint` (prek hook + Ntfy Lint CI). The budget columns exist so notification creep is visible in the diff: if the cadence grows, the declaration grows with it.

## Subscribe to

The one list a new phone or device setup needs. Add each topic in the ntfy app (server: https://ntfy.ops.eblu.me):

- [ ] `ops-approvals` — warrant requests, auto-apply alerts, host apply verdicts. **Actionable**: sound + banner always on; this is the topic that carries the approval gate.
- [ ] `infra-alerts` — Grafana alerting pipeline with runbook links. Actionable, but repeats are the norm (24h repeat interval).
- [ ] `frigate-alerts` — driveway camera detections. FYI; consider a distinct sound or lower volume.
- [ ] ~~`ceramics`~~ — retired 2026-09-01. **Remove any existing subscription** (client-side only; nothing server-side remains).

## Producers

Every producer posts to a declared topic. The topic *literals* live in the producers themselves (shell watchers, workflows, the `request-run` task, and the `argocd/` manifests that lint-only by design — ArgoCD owns that tree); `ntfy/topics.json` declares which topics exist, what posts to them, and at what budget.

- **Host apply watchers** (`nixos/ringtail/ringtail-apply-watcher.sh`, `darwin/indri/mcquack-indri-rebuild-watcher.sh`) post apply verdicts; `NTFY_TOPIC` env override, default the declared topic.
- **`mise-tasks/request-run`** posts a notification per `--notify`.
- **CI workflows** (`auto-apply-digest.yaml`, `ringtail-rebuild.yaml`, `provision-indri.yaml`) post the digest and refusal/failure alerts.
- **Grafana** posts via the webhook contact point in `argocd/manifests/grafana-ringtail/alerting.yaml` (topic set in the message template).
- **frigate-notify** posts detection alerts via `argocd/manifests/frigate/frigate-notify-config.yml` (cluster-internal address `http://ntfy.ntfy.svc.cluster.local:80`).

## Configuration

Server config is in a ConfigMap (`ntfy-config`):

| Setting | Value |
|---------|-------|
| `base-url` | `https://ntfy.ops.eblu.me` |
| `upstream-base-url` | `https://ntfy.sh` |
| `attachment-total-size-limit` | 1 GB |
| `attachment-file-size-limit` | 10 MB |
| `attachment-expiry-duration` | 24h |

No authentication is configured — access is restricted by Tailscale ACLs (only tailnet clients can reach the service).

## Related

- [[routing]] - How ntfy is exposed via Caddy
- [[observability]] - Monitoring and alerting infrastructure
- [[declared-state-files]] - The convention `ntfy/topics.json` follows
