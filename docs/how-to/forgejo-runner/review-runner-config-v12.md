---
title: Review Runner Config for v12
status: active
modified: 2026-02-22
tags:
  - how-to
  - forgejo-runner
  - ci
---

# Review Runner Config for v12

Compare the current runner ConfigMap against the v12.7.0 default config to identify new, changed, or deprecated keys.

## Background

The runner config in `argocd/manifests/forgejo-runner/configmap.yaml` was written for v6.3.1. Six major versions may have introduced new config keys, changed defaults, or deprecated options.

## Current Config

```yaml
log:
  level: info
runner:
  file: /data/.runner
  capacity: 2
  timeout: 3h
  envs:
    DOCKER_HOST: tcp://127.0.0.1:2375
    TZ: America/Los_Angeles
container:
  network: "host"
  docker_host: tcp://127.0.0.1:2375
```

## Steps

1. Fetch the v12.7.0 example config:
   ```fish
   curl -L "https://code.forgejo.org/forgejo/runner/raw/tag/v12.7.0/.forgejo-runner.example.yaml"
   ```
2. Diff against our current config — note new sections/keys
3. Check the release notes for each major version (v7–v12) for config-related changes:
   - v7.0: `FORGEJO_*` env vars (backward compat with `GITHUB_*`)
   - v8.0: Default container image change
   - v12.7: `server.connections` for multi-server polling; secret URLs; ephemeral mode
4. Decide which new keys to adopt (if any) and update the ConfigMap
5. Pay attention to `container.valid_volumes` and `container.options` (added in v6.x for security) — we may want to configure these

## Key Areas to Check

- **`container.valid_volumes`** — allowlist for volume mounts in job containers (security hardening from v6.x)
- **`container.options`** — allowlist for container options
- **`runner.envs`** — are `FORGEJO_*` vars needed alongside `GITHUB_*`?
- **Ephemeral mode** (v12.7) — one-shot runners that de-register after a job. Not needed now but worth noting.
- **`server.connections`** — multi-server polling. Not needed (single Forgejo instance).

## Related

- [[upgrade-k8s-runner]] — Parent goal
