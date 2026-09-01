---
title: BirdNET-Go
modified: 2026-09-01
last-reviewed: 2026-09-01
tags:
  - service
  - surveillance
---

# BirdNET-Go

Local, cloud-free bird-song identification: 24/7 BirdNET inference on the GableCam's audio, with a dashboard, detection clips, and ntfy alerts.

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://birds.ops.eblu.me |
| **Tailscale URL** | https://birds.tail8d86e.ts.net |
| **Namespace** | `birdnet-go` |
| **Image** | `ghcr.io/tphakala/birdnet-go` pinned by digest (release `20260823`) |
| **Upstream** | https://github.com/tphakala/birdnet-go |
| **Manifests** | `argocd/manifests/birdnet-go/` |

## Architecture

```
ReoLink Camera (GableCam)
    │ RTSP (audio: AAC @ 16 kHz)
    ▼
Frigate pod — go2rtc restream (:8554, cluster-local, unauthenticated)
    │ rtsp://frigate.frigate.svc.cluster.local:8554/gablecam?audio
    ▼
BirdNET-Go pod (ringtail k3s, CPU-only TFLite)
    ├── :8080  dashboard (Tailscale Ingress "birds")
    ├── :8090  Prometheus /metrics (prometheus-ringtail scrapes it)
    ├── /data  SQLite + detection clips (local-path PVC, 5Gi)
    └── ntfy   → topic birdnet-alerts → mobile
```

- **Source:** consumes Frigate's go2rtc restream with the `?audio` track selector — audio only, no second RTSP session to the camera, no credentials.
- **Config:** the repo (`birdnet-go-config.yml`) is the source of truth. The web UI writes settings into an emptyDir, so UI edits do not survive a pod restart.
- **Routing:** Tailscale Ingress `birds` → Caddy on indri maps `birds.ops.eblu.me` (`caddy_services` in `ansible/roles/caddy/defaults/main.yml`, applied by `provision-indri`).

## Known limitation

The Reolink microphone is fixed at 16 kHz, so real spectral content tops out at 8 kHz. BirdNET runs at 48 kHz and BirdNET-Go resamples up, but high-pitched species (kinglets, waxwings, some warblers) will be under-detected. Fine for the common 2–8 kHz band. The upgrade path, if this ever matters, is a dedicated RTSP mic (BirdNET-Go supports ESP32-based ones) — not camera surgery.
