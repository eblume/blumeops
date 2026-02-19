---
title: Frigate
modified: 2026-02-19
tags:
  - service
  - surveillance
---

# Frigate

Open-source network video recorder (NVR) with object detection. Runs cloud-free with all video stored locally on [[sifaka]].

## Quick Reference

| Property | Value |
|----------|-------|
| **URL** | https://nvr.ops.eblu.me |
| **Tailscale URL** | https://nvr.tail8d86e.ts.net |
| **Namespace** | `frigate` |
| **Image** | `ghcr.io/blakeblackshear/frigate:0.17.0-rc2-tensorrt` |
| **Upstream** | https://github.com/blakeblackshear/frigate |
| **Manifests** | `argocd/manifests/frigate/` |

## Architecture

```
ReoLink Camera (GableCam)
    │ RTSP
    ▼
Frigate pod (ringtail k3s)
    ├── go2rtc         — RTSP restream proxy
    ├── FFmpeg          — stream decoding
    ├── detector       — ONNX with CUDA (RTX 4080)
    ├── /media/frigate  — NFS recordings (sifaka)
    └── /db             — SQLite (local PVC)
        │
        └──→ MQTT (Mosquitto) → frigate-notify → ntfy → mobile
```

## Cameras

| Camera | IP | Location | Objects Tracked |
|--------|----|----------|-----------------|
| GableCam | `192.168.1.159` | Front gable | person, car, dog, cat, bird |

Camera credentials are stored in 1Password and synced via [[external-secrets]] to the `frigate-camera` Secret.

## Detection

Object detection runs on [[ringtail]]'s RTX 4080 via the ONNX detector with CUDA execution provider. The model is YOLO-NAS-S (`yolo_nas_s.onnx`). The previous Apple Silicon Detector on [[indri]] has been retired.

Two zones are configured: `driveway_entrance` (triggers review alerts for person/car) and `driveway` (triggers review detections).

## Retention

| Type | Duration | Mode |
|------|----------|------|
| Continuous recording | 3 days | all |
| Alert clips | 30 days | active objects |
| Detection clips | 14 days | motion |
| Snapshots | 14 days | — |

## Storage

| Mount | Backend | Size |
|-------|---------|------|
| `/media/frigate` | NFS PV on [[sifaka]] (`/volume1/frigate`) | 2 Ti |
| `/db` | Local PVC (`frigate-database`) | SQLite |
| `/dev/shm` | Memory-backed `emptyDir` | 512 Mi |

## Alerting (frigate-notify)

A separate **frigate-notify** pod (`ghcr.io/0x2142/frigate-notify:v0.3.5`) subscribes to Frigate's MQTT events via Mosquitto and pushes alerts to [[ntfy]] on the `frigate-alerts` topic. Alert messages include action buttons linking back to the Frigate review UI.

## Related

- [[ntfy]] - Push notification delivery
- [[sifaka]] - NAS storage for recordings
- [[observability]] - Prometheus metrics at `/api/metrics`
- [[operationalize-reolink-camera]] - Original deployment plan
