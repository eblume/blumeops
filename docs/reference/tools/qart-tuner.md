---
title: QArt Tuner
modified: 2026-03-27
last-reviewed: 2026-07-04
tags:
  - reference
  - tools
  - utils
---

# QArt Tuner

Generates QR codes whose data modules form a recognizable image, using the [QArt technique](https://research.swtch.com/qart) by Russ Cox. Lives in `utils/qart/`.

## Quick Reference

| Item | Value |
|------|-------|
| **Source** | `utils/qart/main.go` |
| **Language** | Go (managed via mise) |
| **Dependency** | [rsc.io/qr](https://github.com/rsc/qr) (BSD 3-clause) |
| **Launch web UI** | `QART_IMAGE=photo.png mise run serve` (from `utils/qart/`) |
| **CLI** | `mise x go -- go run . -url URL -image IMG -out out.png` |

## How It Works

QR error correction (Reed-Solomon coding) allows some data and check bits to be freely chosen. The tool:

1. Builds a QR code plan for the given URL and version
2. Converts the source photo to a grayscale brightness grid at QR module resolution
3. For each ECC block, models the data/check bit relationships as a matrix over GF(2)
4. Uses Gaussian elimination to find which bits can be independently assigned
5. Assigns bits to match the target image brightness, prioritizing high-contrast areas

The result is a valid, scannable QR code whose black/white modules approximate the source image.

## Web UI

The interactive tuner (`-serve` flag) provides sliders for all parameters with live preview.

**Keyboard shortcuts:** arrow keys (dx/dy offset), `[`/`]` (mask), `-`/`=` (version), `r` (rotate).

## Parameters

| Parameter | Range | Effect |
|-----------|-------|--------|
| **version** | 1-8 | QR density — higher = more modules = finer detail |
| **mask** | 0-7 | QR mask pattern — dramatically affects which pixels are controllable |
| **dx/dy** | -15 to 15 | Shifts image relative to QR structure (avoids alignment dot on eyes) |
| **rotation** | 0-3 | Quarter turns |
| **scale** | 1-16 | Output pixels per QR module |
| **dither** | on/off | Floyd-Steinberg dithering |

## Credits

- **Technique:** [Russ Cox](https://swtch.com/~rsc/), [QArt Codes](https://research.swtch.com/qart) (2012)
- **QR library:** [rsc.io/qr](https://github.com/rsc/qr) — QR layout, encoding, GF(256) arithmetic
- **Implementation:** Claude Code (Opus 4.6) with direction from Erich Blume

## Related

- [[mise-tasks]] — Task runner for BlumeOps operations
