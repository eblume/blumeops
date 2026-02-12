---
title: "Plan: Forgejo Actions Dashboard"
date-modified: 2026-02-11
tags:
  - how-to
  - plans
  - forgejo
  - monitoring
  - grafana
---

# Plan: Forgejo Actions Dashboard

> **Status:** Planned (not yet executed)

## Background

BlumeOps CI/CD runs on Forgejo Actions. There is currently no visibility into CI health — no metrics on job success/failure rates, durations, queue depth, or runner status. When a build fails silently or takes longer than expected, the only way to notice is to check the Forgejo web UI manually.

### Goals

- **Grafana dashboard** showing CI health at a glance: recent runs, pass/fail rates, durations, queue depth
- **Prometheus metrics** for Forgejo Actions data, following the established textfile exporter pattern
- **Alerting foundation** — once metrics exist, alerts can be added later (e.g., "no successful build in 24h")

## Current State

### What Forgejo Exposes

**Built-in `/metrics` endpoint:** No Actions data. The Prometheus endpoint (currently disabled in `app.ini`) only exposes platform-level counters (`gitea_repositories`, `gitea_issues`, etc.). There is an [open feature request](https://codeberg.org/forgejo/forgejo/issues/4803) to add Actions metrics, but it is not yet implemented.

**API (v11+):** Rich Actions data is available via REST API. BlumeOps runs Forgejo v14.0.2, so all endpoints are available:

| Endpoint | Data |
|----------|------|
| `GET /api/v1/repos/{owner}/{repo}/actions/runs` | Workflow runs: status, duration, timestamps, workflow ID, event, commit SHA |
| `GET /api/v1/repos/{owner}/{repo}/actions/tasks` | Tasks: status, timestamps, workflow ID, run number |
| `GET /api/v1/admin/actions/runners/jobs` | Global job search: status, runner labels, dependencies |
| `GET /api/v1/repos/{owner}/{repo}/actions/runners/jobs` | Per-repo job search |

### Existing Metrics Pattern

Custom exporters on indri follow a consistent pattern:

1. **Bash script** polls a local API and writes `.prom` files
2. **LaunchAgent** runs the script on a schedule (e.g., every 60s)
3. **node_exporter textfile collector** picks up `.prom` files from `/opt/homebrew/var/node_exporter/textfile/`
4. **Alloy** scrapes node_exporter and remote-writes to Prometheus
5. **Grafana dashboard** in a ConfigMap auto-discovered by the sidecar

Examples: `ansible/roles/zot_metrics/`, `ansible/roles/borgmatic_metrics/`, `ansible/roles/jellyfin_metrics/`

### Grafana Dashboard Pattern

Dashboards are stored as ConfigMaps in `argocd/manifests/grafana-config/dashboards/` with label `grafana_dashboard: "1"`. The Grafana sidecar auto-discovers and provisions them. See `configmap-zot.yaml` or `configmap-services.yaml` for examples.

## Plan

### 1. Create `forgejo_actions_metrics` Ansible Role

A new role following the established pattern:

```
ansible/roles/forgejo_actions_metrics/
├── defaults/main.yml       # API URL, token var, output dir, repos list
├── tasks/main.yml          # Deploy script + LaunchAgent
└── templates/
    ├── forgejo-actions-metrics.sh.j2   # Collection script
    └── forgejo-actions-metrics.plist.j2  # LaunchAgent
```

**The collection script** polls the Forgejo API and writes Prometheus-format metrics:

```
# HELP forgejo_actions_runs_total Total workflow runs by status
# TYPE forgejo_actions_runs_total gauge
forgejo_actions_runs_total{repo="blumeops",status="success"} 42
forgejo_actions_runs_total{repo="blumeops",status="failure"} 3
forgejo_actions_runs_total{repo="blumeops",status="running"} 1

# HELP forgejo_actions_run_duration_seconds Duration of recent workflow runs
# TYPE forgejo_actions_run_duration_seconds gauge
forgejo_actions_run_duration_seconds{repo="blumeops",workflow="build-blumeops",status="success"} 127

# HELP forgejo_actions_jobs_waiting Number of jobs waiting in queue
# TYPE forgejo_actions_jobs_waiting gauge
forgejo_actions_jobs_waiting 0

# HELP forgejo_actions_jobs_running Number of jobs currently running
# TYPE forgejo_actions_jobs_running gauge
forgejo_actions_jobs_running 1

# HELP forgejo_actions_last_success_timestamp_seconds Unix timestamp of last successful run
# TYPE forgejo_actions_last_success_timestamp_seconds gauge
forgejo_actions_last_success_timestamp_seconds{repo="blumeops",workflow="build-blumeops"} 1707600000

# HELP forgejo_actions_up Forgejo Actions API is reachable
# TYPE forgejo_actions_up gauge
forgejo_actions_up 1
```

**Metrics to expose** (refine during implementation):

| Metric | Type | Labels | Source |
|--------|------|--------|--------|
| `forgejo_actions_up` | gauge | — | API reachability check |
| `forgejo_actions_runs_total` | gauge | `repo`, `status` | `/actions/runs` filtered by status |
| `forgejo_actions_run_duration_seconds` | gauge | `repo`, `workflow`, `status` | Most recent run per workflow |
| `forgejo_actions_jobs_waiting` | gauge | — | `/actions/runners/jobs` filtered by status |
| `forgejo_actions_jobs_running` | gauge | — | `/actions/runners/jobs` filtered by status |
| `forgejo_actions_last_success_timestamp_seconds` | gauge | `repo`, `workflow` | Most recent successful run timestamp |
| `forgejo_actions_last_run_status` | gauge | `repo`, `workflow` | 1=success, 0=failure (last run per workflow) |

**Authentication:** The script needs a Forgejo API token. The existing `_forgejo_api_token` pattern from the playbook's `pre_tasks` can be reused, or a dedicated read-only token can be created and stored in 1Password.

**Repos to monitor:** Start with `eblume/blumeops` (the only repo with active workflows). The role should accept a list of repos so more can be added later.

**Collection interval:** 60 seconds (same as zot_metrics, jellyfin_metrics).

### 2. Create Grafana Dashboard ConfigMap

Add `argocd/manifests/grafana-config/dashboards/configmap-forgejo-actions.yaml` with a dashboard showing:

- **Overview row:** jobs running, jobs waiting, last build status
- **Success/failure trend:** runs by status over time
- **Duration trend:** run duration over time, per workflow
- **Staleness:** time since last successful build per workflow
- **Table:** recent runs with status, duration, commit

The specific dashboard layout will be designed during implementation — this plan focuses on the data pipeline.

### 3. Wire Into Ansible Playbook

Add the new role to `ansible/playbooks/indri.yml` alongside the other metrics roles:

```yaml
- role: forgejo_actions_metrics
  tags: forgejo_actions_metrics
```

No changes needed to Alloy — it already picks up all `.prom` files from the textfile directory.

## Execution Steps

1. **Create the Ansible role** (`ansible/roles/forgejo_actions_metrics/`)
   - Write collection script that queries the Forgejo API
   - Write LaunchAgent plist
   - Add to `indri.yml` playbook

2. **Create or reuse API token**
   - Check if existing Forgejo API token has sufficient permissions
   - If not, create a dedicated read-only token and store in 1Password

3. **Deploy and verify metrics collection**
   - `mise run provision-indri -- --tags forgejo_actions_metrics`
   - Verify `.prom` file appears in textfile directory
   - Verify metrics appear in Prometheus: `curl 'https://prometheus.ops.eblu.me/api/v1/query?query=forgejo_actions_up'`

4. **Create Grafana dashboard ConfigMap**
   - Build dashboard JSON (can use Grafana UI, then export)
   - Wrap in ConfigMap with `grafana_dashboard: "1"` label
   - Sync via ArgoCD

5. **Update documentation**
   - Add changelog fragment
   - Update `docs/reference/services/forgejo.md` if it exists, or note in the plan's reference card

## Verification Checklist

- [ ] Collection script runs without errors on indri
- [ ] `.prom` file in `/opt/homebrew/var/node_exporter/textfile/` has expected metrics
- [ ] Metrics queryable in Prometheus
- [ ] Grafana dashboard loads and shows data
- [ ] LaunchAgent survives indri restart
- [ ] `mise run services-check` passes

## Open Questions

- **Scope of repos:** Start with `eblume/blumeops` only, or also monitor mirrored repos that have workflows?
- **Historical depth:** How far back should the script query? The API paginates — querying the last N runs (e.g., 50) per repo is likely sufficient rather than scanning all history.
- **Runner health:** The Forgejo API does not expose a runner list endpoint. Runner health could be inferred (if jobs stay in "waiting" too long, the runner is likely down), but direct runner metrics aren't available without querying the Forgejo database directly.

## Reference Pattern Files

| File | Purpose |
|------|---------|
| `ansible/roles/zot_metrics/` | Textfile exporter role pattern (simplest example) |
| `ansible/roles/borgmatic_metrics/` | More complex exporter with multiple metrics |
| `ansible/roles/jellyfin_metrics/` | Exporter with API key authentication |
| `argocd/manifests/grafana-config/dashboards/configmap-zot.yaml` | Dashboard ConfigMap pattern |
| `argocd/manifests/grafana-config/dashboards/configmap-services.yaml` | Multi-panel dashboard example |
| `ansible/roles/forgejo/templates/app.ini.j2` | Forgejo configuration |
| `ansible/roles/alloy/templates/config.alloy.j2` | Alloy config (textfile collector) |

## Related

- [[forgejo]] — Forgejo service reference
- [[cluster]] — Grafana and Prometheus run here
- [[grafana]] — Dashboard host
