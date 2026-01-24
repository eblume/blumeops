# Phase 1: Enable Forgejo Actions

**Goal**: Configure Forgejo to support Actions workflows and deploy a runner in k8s

**Status**: Completed (2026-01-23)

**Prerequisites**: None (uses existing brew-based Forgejo)

---

## Current State

- Forgejo runs via `brew services` on indri
- Config at `/opt/homebrew/var/forgejo/custom/conf/app.ini`
- Actions not enabled
- No runners deployed

---

## Step 1: Enable Actions in Forgejo

### 1.1 Update app.ini

SSH to indri and edit the Forgejo config:

```bash
ssh indri 'vim /opt/homebrew/var/forgejo/custom/conf/app.ini'
```

Add the following sections:

```ini
[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://code.forgejo.org

[repository]
; Allow workflows to be stored in .forgejo/workflows
DEFAULT_REPO_UNITS = repo.code,repo.issues,repo.pulls,repo.releases,repo.wiki,repo.projects,repo.packages,repo.actions
```

### 1.2 Restart Forgejo

```bash
ssh indri 'brew services restart forgejo'
```

### 1.3 Verify Actions Enabled

1. Go to https://forge.tail8d86e.ts.net
2. Navigate to any repo → Settings → Actions
3. Should see "Enable Repository Actions" option

---

## Step 2: Create Runner Registration Token

### 2.1 Generate Token in Forgejo UI

1. Go to https://forge.tail8d86e.ts.net/admin/actions/runners
2. Click "Create new Runner"
3. Copy the registration token
4. Store in 1Password (blumeops vault) as "Forgejo Runner Token"

### 2.2 Create k8s Secret Template

Create `argocd/manifests/forgejo-runner/secret-token.yaml.tpl`:

```yaml
# Template for op inject
apiVersion: v1
kind: Secret
metadata:
  name: forgejo-runner-token
  namespace: forgejo-runner
type: Opaque
stringData:
  token: "op://blumeops/<runner-token-item>/token"
```

---

## Step 3: Deploy Runner to Kubernetes

### 3.1 Create ArgoCD Application

Create `argocd/apps/forgejo-runner.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: forgejo-runner
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ssh://forgejo@indri.tail8d86e.ts.net:2200/eblume/blumeops.git
    targetRevision: main
    path: argocd/manifests/forgejo-runner
  destination:
    server: https://kubernetes.default.svc
    namespace: forgejo-runner
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

### 3.2 Create Runner Manifests

Create directory `argocd/manifests/forgejo-runner/` with:

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: forgejo-runner
resources:
  - namespace.yaml
  - deployment.yaml
  - serviceaccount.yaml
  - secret-token.yaml
```

**namespace.yaml**:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: forgejo-runner
```

**serviceaccount.yaml**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: forgejo-runner
  namespace: forgejo-runner
```

**deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: forgejo-runner
  namespace: forgejo-runner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: forgejo-runner
  template:
    metadata:
      labels:
        app: forgejo-runner
    spec:
      serviceAccountName: forgejo-runner
      containers:
        - name: runner
          image: code.forgejo.org/forgejo/runner:3.5.1
          env:
            - name: FORGEJO_INSTANCE_URL
              value: "https://forge.tail8d86e.ts.net"
            - name: RUNNER_NAME
              value: "k8s-runner-1"
            - name: RUNNER_TOKEN
              valueFrom:
                secretKeyRef:
                  name: forgejo-runner-token
                  key: token
          command:
            - /bin/sh
            - -c
            - |
              # Register runner if not already registered
              if [ ! -f /data/.runner ]; then
                forgejo-runner register \
                  --instance "$FORGEJO_INSTANCE_URL" \
                  --token "$RUNNER_TOKEN" \
                  --name "$RUNNER_NAME" \
                  --labels "ubuntu-latest:docker://node:20-bookworm,ubuntu-22.04:docker://ubuntu:22.04" \
                  --no-interactive
              fi
              # Start the runner daemon
              forgejo-runner daemon
          volumeMounts:
            - name: runner-data
              mountPath: /data
            - name: docker-sock
              mountPath: /var/run/docker.sock
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "1Gi"
              cpu: "1000m"
      volumes:
        - name: runner-data
          emptyDir: {}
        - name: docker-sock
          hostPath:
            path: /var/run/docker.sock
            type: Socket
```

**Note**: The runner needs access to Docker to run workflow jobs in containers. In minikube with docker driver, `/var/run/docker.sock` is available.

---

## Step 4: Deploy and Verify

### 4.1 Inject Secrets and Deploy

```bash
# Inject secrets
op inject -i argocd/manifests/forgejo-runner/secret-token.yaml.tpl \
  -o argocd/manifests/forgejo-runner/secret-token.yaml

# Sync apps
argocd app sync apps
argocd app sync forgejo-runner
```

### 4.2 Verify Runner Registration

```bash
# Check runner pod
kubectl --context=minikube-indri -n forgejo-runner get pods

# Check runner logs
kubectl --context=minikube-indri -n forgejo-runner logs -f deployment/forgejo-runner

# Verify in Forgejo UI
# Go to https://forge.tail8d86e.ts.net/admin/actions/runners
# Should see "k8s-runner-1" as online
```

---

## Step 5: Test with Simple Workflow

### 5.1 Create Test Workflow

In the blumeops repo, create `.forgejo/workflows/test.yml`:

```yaml
name: Test CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Hello World
        run: |
          echo "Hello from Forgejo Actions!"
          echo "Runner: ${{ runner.name }}"
          echo "Repo: ${{ github.repository }}"
```

### 5.2 Push and Verify

```bash
git add .forgejo/
git commit -m "Add test workflow for Forgejo Actions"
git push
```

Check https://forge.tail8d86e.ts.net/eblume/blumeops/actions for the workflow run.

---

## Verification Checklist

- [x] Actions enabled in app.ini
- [x] Forgejo restarted successfully
- [x] Runner token stored in 1Password
- [x] Runner deployment created in ArgoCD
- [x] Runner pod running in k8s
- [x] Runner shows as online in Forgejo admin
- [x] Test workflow runs successfully

---

## Troubleshooting

### Runner Can't Connect to Forgejo

The runner needs to reach `forge.tail8d86e.ts.net` from inside k8s. This should work via Tailscale operator egress (already configured for ArgoCD).

If not working:
```bash
# Test from inside k8s
kubectl --context=minikube-indri run -it --rm curl --image=curlimages/curl -- \
  curl -v https://forge.tail8d86e.ts.net/api/v1/version
```

### Docker Socket Permission Denied

The runner container needs to access the Docker socket. In minikube with docker driver, this should work. If permission denied:

```bash
# Check socket permissions
kubectl --context=minikube-indri -n forgejo-runner exec deployment/forgejo-runner -- ls -la /var/run/docker.sock
```

May need to run runner as root or adjust security context.

---

## Next Phase

Once runner is working, proceed to [Phase 2: Mirror & Build](P2_mirror_and_build.md).
