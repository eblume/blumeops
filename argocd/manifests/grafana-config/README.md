# Grafana Configuration

This directory contains Kubernetes manifests for Grafana configuration:
- Tailscale Ingress for external access
- Dashboard ConfigMaps for provisioning

## Secrets Management

**Current approach**: Secrets are manually injected using 1Password CLI.

Before deploying Grafana, create the admin password secret:

```bash
kubectl create namespace monitoring
op inject -i secret-admin.yaml.tpl | kubectl apply -f -
```

The secret template (`secret-admin.yaml.tpl`) references 1Password:
- Vault: `vg6xf6vvfmoh5hqjjhlhbeoaie` (blumeops)
- Item: `oxkcr3xtxnewy7noep2izvyr6y`
- Field: `password`

**Future improvement**: Migrate to External Secrets Operator or similar for
automated secret synchronization from 1Password to Kubernetes.

## Dashboards

Dashboard JSON files are stored as ConfigMaps in the `dashboards/` directory.
The Grafana sidecar automatically discovers ConfigMaps with label
`grafana_dashboard: "1"` and provisions them.

To add a new dashboard:
1. Export the dashboard JSON from Grafana UI
2. Create a ConfigMap with the JSON content
3. Add the `grafana_dashboard: "1"` label
4. Add the ConfigMap to `kustomization.yaml`
