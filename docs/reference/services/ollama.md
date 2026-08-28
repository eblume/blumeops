---
title: Ollama
modified: 2026-08-28
last-reviewed: 2026-08-28
tags:
  - service
  - ai
---

# Ollama

LLM inference server with GPU acceleration. Runs on [[ringtail]] with declarative model management via a sidecar. Scaled to 0 by default — it is an on-demand workload because it shares the RTX 4080 with gaming.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://ollama.ops.eblu.me |
| **Tailscale URL** | https://ollama.tail8d86e.ts.net |
| **Namespace** | `ollama` |
| **Cluster** | ringtail k3s |
| **Image** | `ollama/ollama:0.32.14` |
| **Upstream** | https://github.com/ollama/ollama |
| **Manifests** | `argocd/manifests/ollama/` |
| **API Port** | 11434 |

## Scaling (on-demand)

The deployment stays at `replicas: 0` except for evaluation windows. Scale from a workstation with the ringtail kubeconfig (see `mise run ensure-k3s-ringtail-kubectl-config`):

| Task | Effect |
|------|--------|
| `mise run ollama-up` | Scale to 1, wait for rollout |
| `mise run ollama-down` | Scale to 0, free the GPU |

Both are `[human]` tasks (kubectl access). A cold scale-up pays a one-off ~60s llama.cpp shader-compile stall on the first request per new batch shape.

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

Declared in `argocd/manifests/ollama/models.txt`. The model-sync sidecar pulls missing models on startup and every 30 minutes. Ollama stores model names lowercased; the sidecar matches case-insensitively so mixed-case `hf.co` refs do not re-pull every cycle.

| Model | Parameters |
|-------|------------|
| `qwen2.5:14b` | 14B |
| `deepseek-r1:14b` | 14B |
| `phi4:14b` | 14B |
| `gemma3:12b` | 12B |
| `qwen3.5:9b` | 9B |
| `qwen3.5:27b` | 27B |
| `qwen3.8:27b` | 27B |
| `hf.co/unsloth/Qwen3.8-27B-GGUF:UD-IQ3_S` | 27B, 12GB, ~3.4 bpw |

The 12GB UD-IQ3_S quant is the only 27B config that runs fully GPU-resident on the RTX 4080 at 128K context (the official ~18GB quant cannot fit — [eblume/talos#64](https://forge.eblu.me/eblume/talos/issues/64)). It is served with the 128K-oriented settings below; clients must request `num_ctx: 131072` (there is no global `OLLAMA_NUM_CTX`).

## GPU

Shares [[ringtail]]'s RTX 4080 with [[frigate]] via NVIDIA device plugin time-slicing (2 virtual slots). Constrained to one loaded model and one parallel request to avoid VRAM contention.

| Setting | Value |
|---------|-------|
| `OLLAMA_MAX_LOADED_MODELS` | 1 |
| `OLLAMA_NUM_PARALLEL` | 1 |
| `OLLAMA_FLASH_ATTENTION` | 1 |
| `OLLAMA_KV_CACHE_TYPE` | q4_0 |
| GPU limit | `nvidia.com/gpu: "1"` (time-sliced) |

The q4_0 KV cache is what makes 128K context fit: ~2.3GB of KV at 131072 tokens versus ~5GB at f16. Host RAM is the hazard, not VRAM — the model loads mmap'd and stays GPU-resident, so the pod's 24Gi memory limit stays generous.

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
