---
id: jellyfin
tags:
  - blumeops
---

# Jellyfin Management Log

Jellyfin is a free, open-source media server running natively on [[indri|Indri]] for full VideoToolbox hardware transcoding support.

## Service Details

- URL: https://jellyfin.ops.eblu.me
- Port: 8096 (localhost only, proxied via Caddy)
- Data directory: `~/Library/Application Support/jellyfin`
- Media path: `/Volumes/allisonflix` (NFS from sifaka)
- LaunchAgent: `mcquack.jellyfin`

## Useful Commands

```bash
# Check LaunchAgent status
ssh indri 'launchctl list | grep jellyfin'

# View logs
ssh indri 'tail -f ~/Library/Logs/mcquack.jellyfin.err.log'

# Check port is listening
ssh indri 'lsof -nP -iTCP:8096 -sTCP:LISTEN'

# Restart Jellyfin
ssh indri 'launchctl unload ~/Library/LaunchAgents/mcquack.jellyfin.plist && launchctl load ~/Library/LaunchAgents/mcquack.jellyfin.plist'

# Check metrics
ssh indri 'cat /opt/homebrew/var/node_exporter/textfile/jellyfin.prom'
```

## Hardware Transcoding

Jellyfin uses Apple VideoToolbox for hardware-accelerated transcoding on the M1 Mac Mini.

**Capabilities:**
- H.264 encode/decode: Hardware
- HEVC (H.265) encode/decode: Hardware
- AV1 decode: Software only (requires M3+)
- HDR to SDR tone mapping: VPP (hardware)
- Concurrent 4K streams: ~3 with HDR tonemapping

**Configuration** (Dashboard > Playback):
1. Hardware Acceleration: Apple VideoToolbox
2. Allow hardware encoding: Enabled
3. VPP Tone mapping: Enabled (for HDR to SDR)

## Observability

- Metrics: Collected via `jellyfin_metrics` ansible role to Prometheus textfile
- Logs: Forwarded to Loki via Alloy (`service="jellyfin"`)
- Dashboard: "Jellyfin Media Server" in Grafana

### Metrics collected:
- `jellyfin_up` - Server availability
- `jellyfin_version_info` - Server version
- `jellyfin_library_items{library,type}` - Library counts
- `jellyfin_sessions_total` - Active sessions
- `jellyfin_sessions_playing` - Playing sessions
- `jellyfin_transcode_sessions_total` - Transcoding sessions

## API Key Setup

Metrics collection requires an API key:

1. Open https://jellyfin.ops.eblu.me
2. Go to Dashboard > API Keys > Add
3. Create key with description "metrics"
4. Save to indri:
```bash
ssh indri 'echo "YOUR_API_KEY" > ~/.jellyfin-api-key && chmod 600 ~/.jellyfin-api-key'
```

## Log

### 2026-01-30 (Initial Deployment)
- Deployed Jellyfin natively on indri via Ansible
- Installed via Homebrew cask, managed via LaunchAgent
- Added Caddy routing for `jellyfin.ops.eblu.me`
- Added metrics collection (jellyfin_metrics role)
- Added log collection via Alloy
- Created Grafana dashboard
