---
title: NVIDIA Device Plugin
modified: 2026-06-30
last-reviewed: 2026-06-30
tags:
  - service
  - gpu
---

# NVIDIA Device Plugin

Kubernetes device plugin that exposes NVIDIA GPUs to pods on [[ringtail]]. Required for GPU workloads like [[frigate]] (object detection) and [[ollama]] (LLM inference).

## Quick Reference

| Property | Value |
|----------|-------|
| **Namespace** | `nvidia-device-plugin` |
| **Image** | `nvcr.io/nvidia/k8s-device-plugin:v0.19.2` |
| **Upstream** | https://github.com/NVIDIA/k8s-device-plugin |
| **Manifests** | [argocd/manifests/nvidia-device-plugin/](https://forge.eblu.me/eblume/blumeops/src/branch/main/argocd/manifests/nvidia-device-plugin) |

## Architecture

Runs as a DaemonSet with `privileged` security context, mounting the host's device-plugins socket, CDI specs, and NVIDIA driver libraries. A `RuntimeClass` named `nvidia` is defined for pods that need GPU access.

Time-slicing is configured with 4 replicas per GPU (`time-slicing-config.yaml`), allowing up to four pods to share a single physical GPU.
