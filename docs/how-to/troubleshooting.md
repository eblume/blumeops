---
title: Troubleshooting
modified: 2026-02-07
tags:
  - how-to
  - operations
---

# Troubleshooting Common Issues

Quick reference for diagnosing and fixing common BlumeOps issues.

## General Health Check

Run the comprehensive service health check:

```bash
mise run services-check
```

This checks all services on indri and in Kubernetes.

## Kubernetes Issues

### Pod not starting

```bash
# Check pod status
kubectl --context=minikube-indri -n <namespace> get pods

# Describe pod for events
kubectl --context=minikube-indri -n <namespace> describe pod <pod>

# Check logs
kubectl --context=minikube-indri -n <namespace> logs <pod>

# Previous container logs (if restarting)
kubectl --context=minikube-indri -n <namespace> logs <pod> --previous
```

Common causes:
- **ImagePullBackOff** - Image doesn't exist or registry unreachable
- **CrashLoopBackOff** - Application crashing; check logs
- **Pending** - Insufficient resources or node issues
- **ContainerCreating** - Waiting for volumes or secrets

### ArgoCD sync issues

```bash
# Check app status
argocd app get <app>

# See what will change
argocd app diff <app>

# Force sync
argocd app sync <app> --force

# Sync with prune (removes deleted resources)
argocd app sync <app> --prune
```

**App stuck in "Syncing":**
Check if there are failed hooks or jobs:
```bash
kubectl --context=minikube-indri -n <namespace> get jobs
kubectl --context=minikube-indri -n <namespace> get pods --field-selector=status.phase=Failed
```

**ArgoCD login expired:**
```bash
argocd login argocd.ops.eblu.me --username admin --password "$(op --vault vg6xf6vvfmoh5hqjjhlhbeoaie item get srogeebssulhtb6tnqd7ls6qey --fields password --reveal)"
```

### kubectl connection refused

```bash
# Check if minikube is running (on indri)
ssh indri 'minikube status'

# Restart if needed
ssh indri 'minikube start'

# Verify tailscale is serving the API
ssh indri 'tailscale serve status --json'
```

## Indri Service Issues

### Service not responding

```bash
# Check LaunchAgent status
ssh indri 'launchctl list | grep mcquack'

# Restart a LaunchAgent
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.<service>.plist'
ssh indri 'launchctl load ~/Library/LaunchAgents/mcquack.<service>.plist'

# Check service logs
ssh indri 'tail -50 ~/Library/Logs/mcquack.<service>.err.log'
ssh indri 'tail -50 ~/Library/Logs/mcquack.<service>.out.log'
```

### Forgejo not accessible

```bash
# Check if forgejo is running
ssh indri 'lsof -nP -iTCP:3001 -sTCP:LISTEN'

# Check logs
ssh indri 'tail -50 ~/Library/Logs/mcquack.forgejo.err.log'

# Restart forgejo
ssh indri 'launchctl kickstart -k gui/$(id -u)/mcquack.forgejo'
```

### Registry (Zot) issues

```bash
# Test registry API
ssh indri 'curl -s http://localhost:5050/v2/_catalog | jq'

# Check if zot is running
ssh indri 'lsof -nP -iTCP:5050 -sTCP:LISTEN'

# Restart zot
ssh indri 'launchctl kickstart -k gui/$(id -u)/mcquack.zot'
```

## Network Issues

### Service unreachable via *.ops.eblu.me

Caddy handles routing for `*.ops.eblu.me`:

```bash
# Check if Caddy is running
ssh indri 'launchctl list | grep caddy'

# View Caddy logs
ssh indri 'tail -50 ~/Library/Logs/caddy/access.log'
ssh indri 'tail -50 ~/Library/Logs/caddy/error.log'

# Restart Caddy
ssh indri 'launchctl kickstart -k gui/$(id -u)/homebrew.mxcl.caddy'
```

### Tailscale MagicDNS not resolving

```bash
# Check tailscale serve status
ssh indri 'tailscale serve status --json'

# Restart tailscale if needed
ssh indri 'tailscale down && tailscale up'
```

## Observability

### Check metrics

```bash
# Open Grafana
open https://grafana.ops.eblu.me

# Check Prometheus directly
open https://prometheus.ops.eblu.me
```

### Check logs

```bash
# Open Grafana Explore
open https://grafana.ops.eblu.me/explore

# Query Loki directly
curl -G 'https://loki.ops.eblu.me/loki/api/v1/query_range' \
  --data-urlencode 'query={service="<service>"}' \
  --data-urlencode 'limit=100'
```

### Alloy (metrics/logs collector) issues

```bash
# Indri alloy (host metrics)
ssh indri 'launchctl list | grep alloy'
ssh indri 'tail -50 ~/Library/Logs/alloy/alloy.log'

# K8s alloy (pod logs)
kubectl --context=minikube-indri -n monitoring logs -l app=alloy
```

## Database Issues

### PostgreSQL connection failed

```bash
# Check CNPG cluster status
kubectl --context=minikube-indri -n databases get cluster

# Check PostgreSQL pods
kubectl --context=minikube-indri -n databases get pods -l cnpg.io/cluster=blumeops-pg

# Connect to database
kubectl --context=minikube-indri -n databases exec -it blumeops-pg-1 -- psql -U postgres
```

## Backup Issues

### Check backup status

```bash
# View latest backup info
ssh indri 'cat /opt/homebrew/var/node_exporter/textfile/borgmatic.prom'

# Run backup manually
ssh indri 'borgmatic --verbosity 1'

# Check backup logs
ssh indri 'tail -100 /opt/homebrew/var/log/borgmatic/borgmatic.log'
```

## Related

- [[observability]] - Metrics and logs
- [[argocd]] - GitOps platform
- [[cluster]] - Kubernetes cluster
- [[routing]] - Service routing
