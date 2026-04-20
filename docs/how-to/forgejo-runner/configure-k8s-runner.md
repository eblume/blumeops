---
title: Configure K8s Forgejo Runner
modified: 2026-04-20
last-reviewed: 2026-04-20
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Configure K8s Forgejo Runner

Configure the Kubernetes Forgejo runner on [[indri]] using declarative `server.connections` config instead of first-boot `register`.

## Why This Flow

The older bootstrap pattern used `forgejo-runner register` on container start and persisted `/data/.runner` in an `emptyDir`. That works, but it depends on deprecated CLI flows and mutates runner identity at runtime.

The preferred pattern is:

- Create runner credentials once on the Forgejo host
- Store the runner UUID and token in 1Password
- Inject them into Kubernetes via [[external-secrets]]
- Render `server.connections` in `argocd/manifests/forgejo-runner/config.yaml`

This keeps runner identity under secret management and makes pod restarts idempotent.

## Create Runner Credentials

On [[indri]], use Forgejo's local CLI instead of the web UI:

```bash
ssh indri 'cd ~/code/3rd/forgejo && ./forgejo forgejo-cli actions register \
  --name k8s-runner \
  --scope instance \
  --secret "$(openssl rand -hex 32)"'
```

This returns a runner UUID. The generated secret becomes the runner token. Store both in 1Password under the "Forgejo Secrets" item as:

- `runner_k8s_uuid`
- `runner_k8s_token`

## Kubernetes Secret Wiring

Expose those fields with `argocd/manifests/forgejo-runner/external-secret.yaml` and make them available to the runner container as environment variables.

The deployment should not carry registration-only env vars like `FORGEJO_URL`, `RUNNER_NAME`, or `RUNNER_TOKEN`.

## Runner Config

Keep the runner configuration in `argocd/manifests/forgejo-runner/config.yaml`. The key change is adopting `server.connections`:

```yaml
server:
  connections:
    forgejo:
      url: https://forge.ops.eblu.me
      uuid: ${FORGEJO_RUNNER_UUID}
      token: ${FORGEJO_RUNNER_TOKEN}
      labels:
        - k8s:docker://registry.ops.eblu.me/blumeops/runner-job-image:<tag>
```

Other settings that still matter for this deployment:

- `runner.capacity: 2`
- `runner.timeout: 3h`
- `runner.shutdown_timeout: 3h`
- `container.network: host`
- `container.docker_host: tcp://127.0.0.1:2375`

We do not currently use cache configuration, extra volume mounts, or multiple Forgejo connections.

## Deployment Shape

The pod still runs two containers:

1. `runner` — Forgejo runner daemon
2. `dind` — Docker-in-Docker sidecar

The startup script only needs to wait for DinD and then launch the daemon. It should no longer call `forgejo-runner register` or depend on `/data/.runner`.

## Upgrade Procedure

When bumping the runner version:

1. Update `VERSION` in `containers/forgejo-runner/container.py`
2. Review release notes for runner breaking changes
3. Confirm `config.yaml` is still compatible with the current runner defaults
4. Build and release the updated `forgejo-runner` image
5. Update `argocd/manifests/forgejo-runner/kustomization.yaml` to the new image tag
6. Validate workflows with [[validate-forgejo-workflows]]
7. Sync the `forgejo-runner` ArgoCD app and trigger a test workflow

## Related

- [[validate-forgejo-workflows]] — Validate workflow schema against the deployed runner line
- [[forgejo-runner]] — Service reference
- [[build-container-image]] — Build and release the runner image
