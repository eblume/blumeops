---
title: ArgoCD Config
date-modified: 2026-02-07
tags:
  - tutorials
  - replication
  - argocd
---

# Configuring ArgoCD

> **Audiences:** Replicator

This tutorial walks through installing ArgoCD and establishing GitOps-driven deployments for your homelab.

## What is GitOps?

GitOps means your git repository is the source of truth for infrastructure:
- Infrastructure state is defined in git
- Changes happen through commits and pull requests
- A controller (ArgoCD) syncs git state to the cluster
- Drift is detected and can be corrected automatically

For BlumeOps specifics, see [[argocd|ArgoCD Reference]].

## Step 1: Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for pods to be ready:
```bash
kubectl -n argocd get pods -w
```

## Step 2: Access the UI

### Get the Initial Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Expose the Service

For Tailscale access:
```bash
tailscale serve --bg --https 8443 https+insecure://localhost:$(kubectl -n argocd get svc argocd-server -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
```

Or create a Tailscale Ingress in Kubernetes (see [[tailscale-operator]]).

Access at `https://your-server.tailnet.ts.net:8443`

### Install the CLI

BlumeOps includes `argocd` in its Brewfile (`brew bundle`), or install it however you prefer.

Login:
```bash
argocd login your-server.tailnet.ts.net:8443
```

## Step 3: Connect Your Git Repository

Create a repository credential:

```bash
# For SSH
argocd repo add git@github.com:you/your-repo.git \
  --ssh-private-key-path ~/.ssh/id_ed25519

# For HTTPS
argocd repo add https://github.com/you/your-repo.git \
  --username you \
  --password your-token
```

## Step 4: Create Your First Application

Create a directory in your repo:
```
your-repo/
└── apps/
    └── hello-world/
        ├── deployment.yaml
        └── service.yaml
```

With a simple deployment:
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
    spec:
      containers:
      - name: hello
        image: nginx:alpine
        ports:
        - containerPort: 80
```

Create the ArgoCD Application:
```bash
argocd app create hello-world \
  --repo git@github.com:you/your-repo.git \
  --path apps/hello-world \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

## Step 5: Sync and Verify

```bash
# See what will be deployed
argocd app diff hello-world

# Deploy it
argocd app sync hello-world

# Check status
argocd app get hello-world
```

The pods should now be running:
```bash
kubectl get pods -l app=hello-world
```

## Step 6: App of Apps Pattern

For managing multiple applications, use the "app of apps" pattern:

```
your-repo/
├── argocd/
│   ├── apps/           # Application definitions
│   │   ├── hello-world.yaml
│   │   └── another-app.yaml
│   └── manifests/      # Actual Kubernetes manifests
│       ├── hello-world/
│       └── another-app/
```

Create a root Application that manages other Applications:
```yaml
# argocd/apps/apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:you/your-repo.git
    targetRevision: main
    path: argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
```

Now adding a new application is just creating a YAML file.

## Step 7: Configure Sync Policies

| Policy | When to Use |
|--------|-------------|
| Manual sync | Production, explicit control |
| Auto sync | Development, or trusted workloads |
| Auto prune | Remove resources deleted from git |
| Self heal | Revert manual kubectl changes |

BlumeOps uses manual sync for workloads, auto sync only for the `apps` Application itself.

## What You Now Have

- GitOps workflow for deployments
- UI for visualizing application state
- Automatic drift detection
- Declarative application management

## Next Steps

- [[observability-stack|Build observability]] - Monitor your deployments
- Add more applications to your repo
- Set up notifications for sync failures

## BluemeOps Specifics

BlumeOps' ArgoCD configuration includes:
- SSH connection to [[forgejo]] git server
- Manual sync policy for all workloads
- Separate manifests and apps directories

See [[argocd|ArgoCD Reference]] and [[apps|Apps Reference]] for full details.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Sync failed | Check `argocd app get <app>` for error details |
| Can't connect to repo | Verify credentials, check SSH key permissions |
| Resources not appearing | Ensure path in Application matches repo structure |
| Out of sync but no diff | Check for ignored differences in app config |
