---
id: teslamate
aliases:
  - tesla
tags:
  - blumeops
---

# TeslaMate

TeslaMate is a self-hosted Tesla data logger running in Kubernetes (minikube on indri), collecting and visualizing vehicle data from the Tesla Owner API.

## Service Details

- URL: https://tesla.tail8d86e.ts.net
- Namespace: `teslamate`
- Image: `teslamate/teslamate:2.2.0`
- Database: [[postgresql]] (CloudNativePG cluster at pg.tail8d86e.ts.net)
- ArgoCD app: `teslamate`

## What TeslaMate Collects

- Battery level, state of charge, range estimates
- Charging sessions (location, energy, cost, duration)
- Drives (distance, efficiency, routes)
- Climate/HVAC usage
- Software update history
- Vampire drain analysis
- Vehicle states (asleep, driving, charging, online)

## Grafana Dashboards

18 dashboards available in Grafana under the "TeslaMate" folder at https://grafana.tail8d86e.ts.net:

- Overview, Charges, Drives, Efficiency, States
- Battery Health, Vampire Drain, Statistics
- Charge Level, Locations, Trip, Mileage
- Drive Stats, Charging Stats, Projected Range
- Timeline, Updates, Visited

Dashboards use the `TeslaMate` PostgreSQL datasource (not Prometheus).

## Useful Commands

```bash
# View logs
kubectl --context=minikube-indri -n teslamate logs -f deployment/teslamate

# Check pod status
kubectl --context=minikube-indri -n teslamate get pods

# Restart deployment
kubectl --context=minikube-indri -n teslamate rollout restart deployment/teslamate

# Sync from ArgoCD
argocd app sync teslamate
```

## Credentials

**1Password items (blumeops vault):**
- `TeslaMate` - contains `db_password` and `api_enc_key` fields

**Kubernetes secrets:**
- `teslamate-db` (teslamate ns) - DATABASE_PASS for PostgreSQL connection
- `teslamate-encryption` (teslamate ns) - ENCRYPTION_KEY for token encryption
- `blumeops-pg-teslamate` (databases ns) - CloudNativePG managed role password
- `grafana-teslamate-datasource` (monitoring ns) - Grafana datasource password

## Backup

TeslaMate data is backed up via [[borgmatic]]:
- PostgreSQL database `teslamate` included in `borgmatic_postgresql_databases`
- Backed up alongside miniflux to sifaka NAS

## Tesla API Authentication

TeslaMate uses Tesla's Owner API (not Fleet API) via OAuth:

1. Access https://tesla.tail8d86e.ts.net
2. Click "Sign in with Tesla"
3. Complete OAuth flow in browser
4. Tokens are encrypted with ENCRYPTION_KEY and stored in database
5. TeslaMate automatically refreshes tokens as needed

**Standalone OAuth tool:** If you need to manually obtain tokens, there's a Rust-based helper:
- Mirror: https://forge.tail8d86e.ts.net/eblume/tesla_auth.git
- Runs OAuth flow and outputs access/refresh tokens

## Database Notes

- TeslaMate requires PostgreSQL 17.3+ or 18.x
- The `teslamate` user has superuser privileges (required for extension management during migrations)
- Extensions used: `cube`, `earthdistance` (for geospatial calculations)

## Related

- [[1767747119-YCPO|BlumeOps]]
- [[argocd|ArgoCD]]
- [[postgresql|PostgreSQL]]
- [[borgmatic|Borgmatic]]

## Log

### Thu Jan 23 2026

- Initial deployment to Kubernetes
- 18 Grafana dashboards imported from TeslaMate project
- Upgraded CloudNativePG 1.25 -> 1.28 for major version upgrade support
- Upgraded PostgreSQL 17.2 -> 18.1 (required for TeslaMate 2.2.0)
- Tailscale Ingress at `tesla.tail8d86e.ts.net`
- Backup configuration added to borgmatic
