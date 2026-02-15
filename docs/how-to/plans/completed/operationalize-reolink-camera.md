---
title: "Plan: Operationalize ReoLink Camera"
modified: 2026-02-11
tags:
  - how-to
  - plans
  - security
  - surveillance
  - frigate
---

# Plan: Operationalize ReoLink Camera

> **Status:** Completed (2026-02-15)
> **Depends on:** [[add-unifi-pulumi-stack]] — the camera must be on the IoT VLAN, isolated from the rest of the network.
> **PR:** #190

## Background

A ReoLink Elite Floodlight WiFi outdoor camera has been purchased. The goal is to operate it in a fully **cloud-free, privacy-first** configuration — no ReoLink cloud account, no Ring-style surveillance state participation. All video stays on local infrastructure.

### Goals

- **NVR recording to sifaka** — continuous and event-based recording stored on the Synology NAS via NFS, not on any cloud service
- **No SD card** — the camera does not need one when recording externally; avoid relying on on-device storage
- **Cloud-free** — disable UID/P2P, block internet access at the firewall, operate as a pure LAN device
- **Object detection and alerting** — detect people, vehicles, animals and send notifications without relying on ReoLink's cloud AI features
- **Ring buffer retention** — automatic storage management so recordings don't fill the NAS
- **IoT VLAN isolation** — camera lives on the isolated IoT/Appliances network with only the required ports open to the services subnet

## ReoLink Elite Floodlight WiFi

### Capabilities

| Feature | Details |
|---------|---------|
| Resolution | 4K/8MP (5120x1552 stitched dual-lens panoramic, 180°) |
| Codec | H.265 (HEVC) main stream, H.264 sub stream |
| Connectivity | WiFi 6 (802.11ax) dual-band |
| RTSP | Yes (disabled by default, enable in settings) — `rtsp://admin:<pw>@<IP>:554/Preview_01_main` |
| ONVIF | Yes (port 8000, disabled by default) |
| HTTP API | Yes — `https://<IP>/cgi-bin/api.cgi?cmd=<Cmd>&user=admin&password=<pw>` |
| Floodlight control | Via HTTP API (`SetWhiteLed`) — brightness, mode (off/smart/always/timer) |
| On-device AI | Person/vehicle/pet detection (runs locally on camera, fires ONVIF events) |

### Cloud-Free Operation

The camera operates fully without internet:

1. **Disable UID (P2P):** Settings > Network > Advanced > Enable UID → Off
2. **Block internet at firewall:** IoT VLAN rule denies all outbound to WAN
3. **No ReoLink cloud account needed** — initial setup via app on local network, skip account prompts

What works without internet: RTSP, ONVIF, HTTP API, on-device AI detection, floodlight control, live view.

What is lost: remote app access (use VPN/Tailscale instead), push notifications (use Frigate alerting), OTA firmware updates (manual firmware files instead).

### SD Card: Not Required

Confirmed: the camera streams RTSP and fires ONVIF events without an SD card. On-device recording/playback and local AI video search require an SD card, but both are unnecessary when using an external NVR.

### Required Network Ports

| Port | Protocol | Purpose | Who connects |
|------|----------|---------|-------------|
| 554 | TCP (RTSP) | Video streaming | Frigate (services subnet) |
| 443 | TCP (HTTPS) | API control | Home Assistant / scripts (services subnet) |
| 8000 | TCP (ONVIF) | Event subscriptions | Home Assistant (services subnet) |

These ports need to be allowed from the BlumeOps Services subnet (`192.168.10.0/24`) to the camera's IP on the IoT VLAN (`192.168.3.0/24`). All other traffic to/from the camera is blocked.

## Frigate NVR

Frigate is the clear choice for homelab NVR — open-source, container-native, sophisticated retention, native Prometheus metrics, and first-class ReoLink support.

### Architecture

Frigate runs as a container in the k8s cluster on indri. It consumes the camera's RTSP streams via go2rtc (an embedded RTSP restreaming proxy that handles connection reliability), performs object detection on the sub stream, and writes recordings to sifaka via NFS.

```
ReoLink Camera (IoT VLAN)
    │
    │ RTSP (port 554)
    ▼
Frigate (k8s pod on indri)
    ├── go2rtc          — RTSP restream proxy
    ├── FFmpeg          — stream decoding
    ├── ONNX detector   — object detection (CPU)
    ├── /media/frigate  — NFS mount to sifaka
    └── /db             — local SQLite (emptyDir or PV)
        │
        ├──→ Prometheus   (/api/metrics endpoint)
        └──→ MQTT         (detection events)
```

### Object Detection on M1

Indri is an Apple M1 Mac mini. Inside minikube's Linux VM, the Apple Neural Engine is not accessible. Detection options:

- **ONNX (CPU):** Works on ARM64. For a single camera, M1's performance cores handle detection comfortably. This is the starting point.
- **Hailo-8L (future):** If more cameras are added, a USB-attached Hailo-8L accelerator (~$30) could be passed through to the VM. Evaluate only if CPU detection proves insufficient.

### Recording and Retention (Ring Buffer)

Frigate's retention system is the most sophisticated of any homelab NVR:

```yaml
record:
  enabled: true
  retain:
    days: 3              # Keep ALL continuous recordings for 3 days
    mode: all
  alerts:
    retain:
      days: 30           # Keep alert clips (person/vehicle) for 30 days
      mode: active_objects
  detections:
    retain:
      days: 14           # Keep all detection clips for 14 days
      mode: motion
```

**Safety mechanism:** When less than 1 hour of storage remains, the oldest 2 hours of recordings are deleted automatically (checked every 5 minutes).

**Recordings are written directly from the camera stream — no re-encoding.** This means zero CPU cost for recording; CPU is only used for detection on the sub stream.

### Storage Estimates

For a single 4K H.265 camera at moderate quality:

| Strategy | Per Day | 30 Days | Notes |
|----------|---------|---------|-------|
| 24/7 continuous | ~80-130 GB | 2.4-3.9 TB | Upper bound |
| Motion-only | ~8-26 GB | 240-780 GB | Depends on scene activity |
| Detection-only (active objects) | ~2-13 GB | 60-390 GB | Most efficient |
| Hybrid: 3d continuous + 30d events | — | ~600 GB-1 TB | Recommended starting point |

A dedicated 2 TB NFS share on sifaka gives comfortable headroom for the hybrid approach with one camera.

### NFS Storage Setup

Mount an NFS share from sifaka into the Frigate pod:

- **Recordings:** NFS PersistentVolume (e.g., `sifaka:/volume1/frigate`) mounted at `/media/frigate`
- **Database:** Local storage (emptyDir or a hostPath PV) mounted at `/db` — SQLite performs poorly over NFS

This follows the same pattern as Navidrome (`argocd/manifests/navidrome/pv-nfs.yaml`) and Immich (`argocd/manifests/immich/pv-nfs.yaml`).

**NFS export on sifaka:** Add `/volume1/frigate` with access restricted to the BlumeOps Services subnet (`192.168.10.0/24`) and Docker NAT range (`100.64.0.0/10`).

### Prometheus Metrics

Frigate exposes a native `/api/metrics` Prometheus endpoint with:

- `frigate_cpu_usage_percent`, `frigate_mem_usage_percent`
- `frigate_camera_fps`, `frigate_detection_fps`, `frigate_process_fps`
- `frigate_skipped_fps`, `frigate_detection_enabled`

A pre-built [Grafana dashboard](https://grafana.com/grafana/dashboards/18226-frigate/) exists. Add a Prometheus scrape target and a Grafana dashboard ConfigMap.

### Alerting

Options for detection-based notifications (no Home Assistant required):

- **[frigate-notify](https://github.com/0x2142/frigate-notify):** Standalone notification service supporting Telegram, Ntfy, Pushover, Discord, webhooks, and more. Runs as a separate container, subscribes to Frigate's MQTT events.
- **MQTT events:** Frigate publishes to MQTT on every detection — can be consumed by any MQTT subscriber.
- **Home Assistant automations:** If HA is added later, full integration with notification channels.

### ReoLink-Specific Configuration

ReoLink cameras need go2rtc as an intermediary (direct RTSP from Frigate can drop connections). Frigate config sketch:

```yaml
go2rtc:
  streams:
    front_floodlight:
      - "ffmpeg:http://admin:<your-password>@192.168.3.X/flv?port=1935&app=bcs&stream=channel0_main.bcs#video=copy#audio=copy#audio=opus"
    front_floodlight_sub:
      - "ffmpeg:http://admin:<your-password>@192.168.3.X/flv?port=1935&app=bcs&stream=channel0_sub.bcs"

cameras:
  front_floodlight:
    enabled: true
    ffmpeg:
      inputs:
        - path: rtsp://127.0.0.1:8554/front_floodlight
          input_args: preset-rtsp-restream
          roles: [record]
        - path: rtsp://127.0.0.1:8554/front_floodlight_sub
          input_args: preset-rtsp-restream
          roles: [detect]
    detect:
      enabled: true
      width: 640
      height: 480
    objects:
      track: [person, car, dog, cat]
```

Camera settings to apply: enable RTSP and ONVIF, set "fluency first" encoding mode, set interframe space to 1x.

## Execution Steps

1. **Prerequisite: Network segmentation** (see [[add-unifi-pulumi-stack]])
   - Camera on IoT VLAN (`192.168.3.0/24`)
   - Firewall rules allowing ports 554, 443, 8000 from services subnet

2. **Camera initial setup**
   - Connect to WiFi (IoT SSID)
   - Set static IP or DHCP reservation
   - Enable RTSP, ONVIF in camera settings
   - Disable UID/P2P
   - Set admin password, store in 1Password
   - Block internet access at firewall

3. **Create NFS share on sifaka**
   - Create `/volume1/frigate` shared folder in Synology DSM
   - Set NFS permissions: `192.168.10.0/24` and `100.64.0.0/10`

4. **Deploy Frigate to k8s**
   - Create `argocd/manifests/frigate/` with Deployment, Service, ConfigMap, PV/PVC
   - NFS PV for recordings, local storage for database
   - Configure go2rtc + camera streams
   - Start with CPU detection (ONNX)

5. **Deploy MQTT broker** (if not already present)
   - Frigate needs MQTT for event publishing
   - Evaluate lightweight options: Mosquitto as a k8s pod

6. **Set up alerting**
   - Deploy frigate-notify (or equivalent) as a sidecar or separate pod
   - Configure notification channel (Ntfy, Telegram, or similar)

7. **Add Prometheus scrape target and Grafana dashboard**
   - Add Frigate to `argocd/manifests/prometheus/configmap.yaml`
   - Add `configmap-frigate.yaml` dashboard to `argocd/manifests/grafana-config/dashboards/`

8. **Update documentation**
   - Create reference card for the camera and Frigate
   - Add changelog fragment
   - Update sifaka NFS export documentation

## Verification Checklist

- [x] Camera streams accessible via RTSP from services subnet
- [ ] Camera has no internet access (blocked at firewall) — pending IoT VLAN segmentation
- [x] Frigate pod is running and showing live camera feed in web UI
- [x] Recordings appearing in NFS share on sifaka
- [x] Object detection working (person/vehicle detected in Frigate UI)
- [x] Retention policy active (old recordings cleaned up automatically)
- [x] Alerts firing on detection events (ntfy push notifications with ~6s delivery)
- [x] Prometheus metrics visible in Grafana dashboard
- [x] `mise run services-check` passes

## Open Questions (Resolved)

- **MQTT broker:** Deployed Mosquitto (eclipse-mosquitto:2) in the `mqtt` namespace. Lightweight, anonymous access, cluster-internal only (no Caddy/ingress needed since MQTT is TCP, not HTTP).
- **Home Assistant:** Deferred. Frigate + frigate-notify + ntfy provides a complete pipeline without HA.
- **Sifaka NFS share sizing:** Allocated 2 TB. Hybrid retention (3d continuous, 30d alerts, 14d detections) keeps usage well within bounds.
- **Additional cameras:** Using ONNX/YOLO-NAS-s on CPU at ~535ms/frame, ~2 FPS detection. Adequate for single camera. Apple Silicon Detector (ASD) via ZMQ is the next upgrade path for better performance (~15ms via Neural Engine). Requires Frigate 0.17+.
- **Floodlight automation:** Deferred to future Home Assistant evaluation.

## Future Considerations

- **Home Assistant** — adds powerful automation for camera + floodlight + notifications
- **License plate recognition** — Frigate supports LPR with appropriate models
- **Multiple cameras** — the pattern scales; add more cameras to the same Frigate instance
- **Frigate+** ($50/yr) — improved detection models trained on community data, fewer false positives

## Reference Pattern Files

| File | Purpose |
|------|---------|
| `argocd/manifests/navidrome/pv-nfs.yaml` | NFS PersistentVolume pattern |
| `argocd/manifests/immich/pv-nfs.yaml` | NFS PV with ReadWriteMany |
| `argocd/manifests/grafana-config/dashboards/configmap-zot.yaml` | Grafana dashboard ConfigMap pattern |
| `argocd/manifests/prometheus/configmap.yaml` | Prometheus scrape target config |
| `docs/reference/storage/sifaka.md` | NFS export documentation |

## Related

- [[add-unifi-pulumi-stack]] — network segmentation (IoT VLAN for camera)
- [[sifaka]] — NAS storage for recordings
- [[cluster]] — k8s cluster hosting Frigate
- [[grafana]] — monitoring dashboards
