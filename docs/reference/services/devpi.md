---
title: Devpi
modified: 2026-04-29
last-reviewed: 2026-04-29
tags:
  - service
  - python
---

# devpi (PyPI Proxy)

PyPI caching proxy and private package index. Runs natively on [[indri]] as a LaunchAgent (not in-cluster). See [[devpi-on-indri]] for deploy and operations.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | `https://pypi.ops.eblu.me` |
| **Listen** | `127.0.0.1:3141` (loopback only; reached via Caddy) |
| **Service** | LaunchAgent `mcquack.eblume.devpi` on indri |
| **Server-dir** | `/Users/erichblume/devpi/server-dir/` |
| **Runtime** | uv-managed venv at `/Users/erichblume/devpi/venv/` |
| **Owner** | Generation-owned (`darwin/indri`, nix-darwin postActivation); the ansible role is retired |
| **Versions** | Pinned in `darwin/indri/devpi-pins.yaml` (`devpi_server_version`, `devpi_web_version`) |

## Indices

| Index | Purpose |
|-------|---------|
| `root/pypi` | PyPI mirror/cache (auto-created by `devpi-init`) |
| `eblume/dev` | Private packages (inherits from `root/pypi`) |

## Credentials

Root password stored in 1Password (`blumeops` vault, item `devpi`, field `root password`). Consumed by the generation's devpi-init on first init (no longer fetched by ansible).

## Backup

The server-dir is **not** backed up. The PyPI cache (`+files/`) is re-fetchable from upstream on first request. The local `eblume/dev` index metadata is small but also not critical to retain — packages can be republished from source. If retention becomes important, add `/Users/erichblume/devpi/server-dir/` to `borgmatic_source_directories`.

## Related

- [[devpi-on-indri]] — Deploy, verify, and version-bump procedures
- [[use-pypi-proxy]] — Client configuration and package uploads
- [[1password]] — Secrets management
