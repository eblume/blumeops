---
title: Power
date-modified: 2026-02-09
tags:
  - infrastructure
---

# Power Infrastructure

The homelab runs on battery-backed power to survive grid outages.

## Power Chain

```
AC Grid (120V) → Anker SOLIX F2000 → CyberPower CP1000PFCLCD → Homelab
```

| Stage | Device | Notes |
|-------|--------|-------|
| **Grid** | 120V AC mains | Charges the battery station |
| **Battery** | Anker SOLIX F2000 GaNPrime | 2048Wh portable power station |
| **UPS** | CyberPower CP1000PFCLCD | 1000VA / 600W, pure sine wave output |

## Devices on UPS

| Device | Role |
|--------|------|
| [[indri]] | Primary server |
| [[sifaka]] | NAS |
| UniFi Express 7 | WiFi router |
| Starlink | Satellite internet uplink |

## Related

- [[hosts]] - Device inventory
- [[restart-indri]] - Shutdown and startup procedure
