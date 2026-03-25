---
title: Snowflake Proxy
modified: 2026-03-24
tags:
  - service
  - privacy
  - anti-censorship
---

# Snowflake Proxy

Tor Snowflake proxy that helps censored users reach the Tor network. Runs as a native systemd service on [[ringtail]].

## Quick Reference

| Property | Value |
|----------|-------|
| **Host** | ringtail |
| **Type** | NixOS systemd service |
| **Package** | `pkgs.snowflake` (nixpkgs) |
| **Binary** | `proxy` |
| **Upstream** | https://snowflake.torproject.org/ |
| **Source** | https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake |
| **Metrics** | `localhost:9999/metrics` (Prometheus) |

## Architecture

Snowflake is a pluggable transport for Tor that uses WebRTC to provide short-lived proxies. The proxy:

1. Polls the Tor broker for censored clients needing a bridge
2. Establishes a WebRTC connection with the client
3. Forwards the encrypted traffic to a Tor bridge (relay)

**This proxy is NOT a Tor exit node.** Traffic exits through Tor exit nodes operated by others. The proxy operator cannot see traffic content (double-encrypted: WebRTC DTLS + Tor onion routing) and destination servers never see the proxy's IP.

```
Censored user ──[WebRTC/DTLS]──▶ THIS PROXY ──[encrypted]──▶ Tor bridge ──▶ Tor network ──▶ Exit node
```

## Configuration

The service runs with default settings — no special configuration needed. Key defaults:

| Setting | Value |
|---------|-------|
| **Broker** | `https://snowflake-broker.torproject.net/` |
| **Relay** | `wss://snowflake.torproject.net/` |
| **STUN** | Google + BlackBerry STUN servers |
| **Capacity** | Unlimited concurrent clients |
| **Summary interval** | 1 hour |
| **Metrics port** | 9999 (Prometheus format) |

## Resource Usage

Based on community reports, a Snowflake proxy typically uses:

- **Bandwidth:** ~5-10 GB/day (varies with client demand)
- **Memory:** Under 100 MB
- **CPU:** Negligible

## Legal Considerations

Running a Snowflake proxy carries very low legal risk in the US:

- Traffic does not exit from the proxy's IP (exit nodes are elsewhere)
- Content is not visible to the proxy operator (end-to-end encrypted)
- No known legal cases against Snowflake proxy operators worldwide
- EFF and Tor Project both classify this as minimal-risk activity
- US intermediary protections (Section 230, ECPA) apply

## Related

- [[ringtail]] - Host machine
- [[architecture]] - Overall system design
