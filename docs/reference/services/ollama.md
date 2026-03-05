---
title: Ollama
modified: 2026-03-04
tags:
  - service
  - ai
---

# Ollama

LLM inference server with GPU acceleration. Runs on [[ringtail]] with declarative model management via a sidecar.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://ollama.ops.eblu.me |
| **Tailscale URL** | https://ollama.tail8d86e.ts.net |
| **Namespace** | `ollama` |
| **Cluster** | ringtail k3s |
| **Image** | `ollama/ollama:0.17.5` |
| **Upstream** | https://github.com/ollama/ollama |
| **Manifests** | `argocd/manifests/ollama/` |
| **API Port** | 11434 |

## Architecture

```
models.txt (ConfigMap, declarative)
    │
    ▼
model-sync sidecar ──ollama pull──► Ollama server (GPU)
    │                                    │
    │ reads /config/models.txt           │ serves /api/*
    │ polls every 30 min                 │ NVIDIA runtime (RTX 4080, time-sliced)
    │                                    │
    └────────────────────────────────────┘
                     │
                /models (200 Gi hostPath PV)
                /mnt/storage1/ollama on ringtail
```

## Models

Declared in `argocd/manifests/ollama/models.txt`. The model-sync sidecar pulls missing models on startup and every 30 minutes.

| Model | Parameters |
|-------|------------|
| `qwen2.5:14b` | 14B |
| `deepseek-r1:14b` | 14B |
| `phi4:14b` | 14B |
| `gemma3:12b` | 12B |

To add or remove models, edit `models.txt` and sync via ArgoCD.

## GPU

Shares [[ringtail]]'s RTX 4080 with [[frigate]] via NVIDIA device plugin time-slicing (2 virtual slots). Constrained to one loaded model and one parallel request to avoid VRAM contention.

| Setting | Value |
|---------|-------|
| `OLLAMA_MAX_LOADED_MODELS` | 1 |
| `OLLAMA_NUM_PARALLEL` | 1 |
| GPU limit | `nvidia.com/gpu: "1"` (time-sliced) |

## Storage

| Mount | Backend | Size |
|-------|---------|------|
| `/models` | hostPath PV (`/mnt/storage1/ollama`) | 200 Gi |

PV reclaim policy is `Retain` — models survive PV deletion.

## Networking

| Endpoint | Reachable from |
|----------|----------------|
| `https://ollama.ops.eblu.me` | Public internet (Fly.io → Caddy) |
| `https://ollama.tail8d86e.ts.net` | Tailnet clients |
| `http://ollama.ollama.svc.cluster.local:11434` | In-cluster (ringtail) |

Tailscale ingress uses ProxyGroup `ingress` — no explicit `host:` field (see [[tailscale-operator]]).

## Related

- [[frigate]] — Shares GPU via time-slicing
- [[ringtail]] — Host node
- [[apps]] — ArgoCD application registry
- [[tailscale-operator]] — Tailscale ingress
