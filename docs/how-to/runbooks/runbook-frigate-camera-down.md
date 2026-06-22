---
title: "Runbook: Frigate Camera Down"
modified: 2026-03-22
last-reviewed: 2026-06-22
tags:
  - how-to
  - alerting
  - runbook
---

# Runbook: Frigate Camera Down

**Alert name:** `FrigateCameraDown`

A Frigate camera has reported 0 FPS for 5+ minutes, meaning the camera feed is not being received.

## Diagnostic Steps

1. **Check Frigate UI** — https://nvr.ops.eblu.me — look at the camera thumbnail and status
2. **Check Frigate API stats**:
   ```fish
   curl -s https://nvr.ops.eblu.me/api/stats | python3 -m json.tool
   ```
3. **Check Frigate pod logs** on ringtail:
   ```fish
   kubectl logs -n frigate -l app=frigate --context=k3s-ringtail --tail=30
   ```
4. **Check the camera itself** — verify it's powered on and network-connected. Try accessing the RTSP stream directly.

## Common Causes

- **Camera offline** — power outage, network issue, or camera crash
- **NFS mount lost** — Frigate storage on sifaka; if the NFS mount drops, recording stops and FPS may drop
- **Frigate pod restart** — during restart, camera FPS briefly drops to 0
- **RTSP stream timeout** — camera firmware issue; power cycle the camera

## Related

- [[frigate]] — Frigate NVR reference
- [[deploy-infra-alerting]] — Alerting pipeline overview
