---
title: TeslaMate
modified: 2026-03-23
last-reviewed: 2026-03-23
tags:
  - service
  - vehicle
---

# TeslaMate

Self-hosted Tesla data logger collecting vehicle telemetry from the Tesla API.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://tesla.ops.eblu.me |
| **Namespace** | `teslamate` |
| **Image** | `registry.ops.eblu.me/blumeops/teslamate` (see `argocd/manifests/teslamate/kustomization.yaml` for current tag) |
| **Database** | [[postgresql]] |

## Data Collected

- Battery level, state of charge, range estimates
- Charging sessions (location, energy, cost, duration)
- Drives (distance, efficiency, routes)
- Climate/HVAC usage
- Software update history
- Vampire drain analysis
- Vehicle states (asleep, driving, charging, online)

## Grafana Dashboards

18 dashboards in the "TeslaMate" folder:
- Overview, Charges, Drives, Efficiency, States
- Battery Health, Vampire Drain, Statistics
- Charge Level, Locations, Trip, Mileage
- Drive Stats, Charging Stats, Projected Range
- Timeline, Updates, Visited

Dashboards use PostgreSQL datasource (not Prometheus).

## Authentication

Uses Tesla Owner API via OAuth:
1. Access https://tesla.ops.eblu.me
2. Click "Sign in with Tesla"
3. Tokens encrypted with ENCRYPTION_KEY

## Credentials

**1Password:** `TeslaMate` item with `db_password` and `api_enc_key`

## Related

- [[postgresql]] - Data storage
- [[grafana]] - Dashboards
- [[borgmatic]] - Database backup
