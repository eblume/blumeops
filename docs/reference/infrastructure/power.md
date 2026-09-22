---
title: Power
modified: 2026-09-22
last-reviewed: 2026-09-22
tags:
  - infrastructure
  - reference
---

# Power Infrastructure

The homelab runs on battery-backed power to survive grid outages. Since the
home-office rewiring of 2026-09-21 the battery station and the UPS are two
tiers, not one chain: only the two servers and their switch get the UPS.

## Power Chain

```
AC Grid (120V) → Anker SOLIX F2000 ─┬─→ CyberPower CP1000PFCLCD → indri, ringtail, ethernet switch
                                    └─→ everything else (sifaka, UX7, Starlink, desk, peripherals)
```

| Stage | Device | Notes |
|-------|--------|-------|
| **Grid** | 120V AC mains | Charges the battery station |
| **Battery** | Anker SOLIX F2000 GaNPrime | 2048Wh portable power station; everything in the office runs through it |
| **UPS** | CyberPower CP1000PFCLCD | 1000VA / 600W, pure sine wave output, fast transfer; servers only |

## Devices on UPS

| Device | Role |
|--------|------|
| [[indri]] | Primary server |
| [[ringtail]] | GPU compute / gaming PC |
| Ethernet switch | The UniFi Flex Mini the servers hang off ([[unifi]]) |

## Devices on the battery station only

| Device | Role | Outage behaviour |
|--------|------|------------------|
| [[sifaka]] | NAS | Survives on battery; may see the station's transfer blip |
| UniFi Express 7 | WiFi router | Same; expect a brief network drop during a grid outage |
| Starlink | Satellite internet uplink | Same |
| Standing desk, monitors, chargers | Office | Same |

## Why the split

Before the rewiring every device sat behind the UPS, which was oversubscribed:
transient loads such as raising the standing desk (its motors are the largest
single draw in the office) while ringtail was under heavy load pushed the UPS
past 600W and it alarmed. Moving everything but the servers and their switch
onto the battery station keeps the UPS's headroom and its pure-sine, fast-transfer
output for the two hosts that cannot tolerate a power blip.

The cost is that the router and Starlink now ride the battery station's slower
transfer, so a grid outage can still drop the network briefly even though the
servers stay up. There is no wire routing today that avoids this; a second,
larger UPS would.

## Related

- [[hosts]] - Device inventory
- [[unifi]] - Network topology
- [[restart-indri]] - Indri shutdown and startup procedure
- [[restart-ringtail]] - Ringtail shutdown and startup procedure
