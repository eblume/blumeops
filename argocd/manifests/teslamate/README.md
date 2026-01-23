# TeslaMate

TeslaMate is a self-hosted Tesla data logger that collects and visualizes vehicle data.

## Prerequisites

### 1. Create 1Password Secrets

Create two items in the blumeops 1Password vault:

1. **TeslaMate DB Password**
   - Generate a secure password for the teslamate PostgreSQL user
   - Add a field named `password` with the generated value

2. **TeslaMate Encryption Key**
   - Generate with: `openssl rand -base64 32`
   - Add a field named `key` with the generated value
   - This encrypts Tesla API tokens at rest in the database

### 2. Apply Kubernetes Secrets

```bash
# Create namespace
kubectl create namespace teslamate

# Apply database user secret (for CNPG)
op inject -i argocd/manifests/databases/secret-teslamate.yaml.tpl | kubectl apply -f -

# Apply teslamate secrets
op inject -i argocd/manifests/teslamate/secret-encryption-key.yaml.tpl | kubectl apply -f -
op inject -i argocd/manifests/teslamate/secret-db.yaml.tpl | kubectl apply -f -
```

### 3. Create Database

After the teslamate user exists in PostgreSQL (sync blumeops-pg first):

```bash
PGPASSWORD=$(op --vault blumeops item get <eblume-item-id> --fields password --reveal) \
  psql -h pg.tail8d86e.ts.net -U eblume -c "CREATE DATABASE teslamate OWNER teslamate;"
```

## Deployment

```bash
# Sync ArgoCD apps
argocd app sync apps
argocd app sync blumeops-pg teslamate grafana grafana-config
```

## Tesla API Setup

1. Access TeslaMate UI at https://tesla.tail8d86e.ts.net
2. Click "Sign in with Tesla"
3. Complete OAuth flow in browser
4. Tokens are encrypted and stored in database
5. Verify vehicle appears and data collection starts

## Grafana Dashboards

TeslaMate dashboards are available in Grafana at https://grafana.tail8d86e.ts.net

They use the "TeslaMate" PostgreSQL datasource (not Prometheus).

## Notes

- MQTT is disabled (can be enabled later for Home Assistant integration)
- Timezone is set to America/Los_Angeles
- Encryption key protects Tesla API tokens at rest
