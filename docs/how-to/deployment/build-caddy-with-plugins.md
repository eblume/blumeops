---
title: Build Caddy with Plugins
modified: 2026-03-15
last-reviewed: 2026-03-15
tags:
  - how-to
  - caddy
  - networking
---

# Build Caddy with Plugins

Caddy is built from source using `xcaddy` with two plugins:

- `github.com/caddy-dns/gandi` — ACME DNS-01 challenges via Gandi API
- `github.com/mholt/caddy-l4` — Layer 4 (TCP/UDP) proxying

## How to Build

```bash
# Source and build location (mirrored on forge)
~/code/3rd/caddy/bin/caddy

# Build via mise task in the caddy clone
cd ~/code/3rd/caddy && mise run build
```

## Forge Mirrors

- `mirrors/caddy`
- `mirrors/caddy-gandi`
- `mirrors/xcaddy`
- `mirrors/caddy-l4`

## Related

- [[caddy]] — Service reference card
- [[routing]] — Service routing architecture
