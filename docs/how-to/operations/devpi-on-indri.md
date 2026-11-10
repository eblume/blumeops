---
title: Devpi on Indri
modified: 2026-04-29
last-reviewed: 2026-04-29
tags:
  - how-to
  - operations
---

# Devpi on Indri

How devpi (the PyPI caching mirror at `pypi.ops.eblu.me`) is deployed on indri as a launchd-managed native service. Replaces the prior minikube StatefulSet.

## Why native, not Kubernetes

Devpi has no runtime dependencies beyond a Python interpreter, a writable directory, and outbound HTTPS to upstream PyPI. Running it on indri natively removes a layer of operational complexity, frees minikube resources, and decouples this critical-path tooling (used by every Python build, including the `mise run` task scripts themselves) from cluster health.

## Layout

| Concern | Path / detail |
|---|---|
| Service binary | `/Users/erichblume/devpi/venv/bin/devpi-server` |
| Server-dir (data) | `/Users/erichblume/devpi/server-dir/` |
| Logs | `/Users/erichblume/Library/Logs/mcquack.devpi.{out,err}.log` |
| LaunchAgent label | `mcquack.eblume.devpi` |
| LaunchAgent plist | `~/Library/LaunchAgents/mcquack.eblume.devpi.plist` |
| Listen address | `127.0.0.1:3141` (loopback only) |
| Public URL | `https://pypi.ops.eblu.me` (via Caddy reverse proxy) |
| Root password secret | 1Password item `devpi`, field `root password` |

The venv, its pinned `devpi-server` and `devpi-web` versions, and the LaunchAgent are owned by the nix-darwin generation (`darwin/indri`, installed in postActivation). The ansible devpi role is retired (eblume/blumeops#2262).

## Deploy

Deploys are generation applies: merge to `main` and let the indri auto-apply run, or apply by hand with `mise run provision-indri -- --tags rebuild`.

The generation will:

1. Create the venv at `~/devpi/venv` if absent and install the pinned `devpi-server` + `devpi-web`
2. Initialize the server-dir (only when `.serverversion` is missing, and only once `~/devpi/root-password` is seeded; while it is unseeded the init is skipped and the server-dir is untouched)
3. Kickstart `mcquack.eblume.devpi` when the venv changed

Caddy already proxies `pypi.ops.eblu.me` → `127.0.0.1:3141`; nothing else routes traffic.

## Verify

```fish
ssh indri 'launchctl list mcquack.eblume.devpi'
curl -fsS https://pypi.ops.eblu.me/+api | jq
uv pip install --index-url https://pypi.ops.eblu.me/root/pypi/+simple/ requests
```

## Logs

```fish
ssh indri 'tail -f ~/Library/Logs/mcquack.devpi.err.log'
```

## Bumping devpi versions

Edit `devpi_server_version` / `devpi_web_version` in `darwin/indri/devpi-pins.yaml` and merge to `main`. The indri auto-apply (or `mise run provision-indri -- --tags rebuild`) rebuilds the venv in place; the server-dir survives.

## Backup

The server-dir is **not** in `borgmatic_source_directories` and is not backed up. The PyPI cache (`+files/`) is re-fetchable from upstream on first request; the local `eblume/dev` index can be republished from source. If retention becomes important, add `/Users/erichblume/devpi/server-dir/` to the borgmatic source list.

## Related

- [[restart-indri]] — devpi is one of the LaunchAgents to stop on graceful shutdown
- [[connect-to-postgres]] — pattern for indri-native services (different stack, similar shape)
