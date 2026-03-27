# QArt Tuner

Generate QR codes whose data modules form a recognizable image.

This implements the [QArt technique](https://research.swtch.com/qart) invented
by [Russ Cox](https://swtch.com/~rsc/). The trick: QR error correction gives
some freedom in choosing bit values. By picking bits that satisfy the
Reed-Solomon constraints *and* match a target image's brightness, the QR
modules themselves draw a picture — no logo overlay, no center cutout.

This tool uses the [rsc.io/qr](https://github.com/rsc/qr) library (BSD
3-clause) for QR layout, data encoding, and GF(256) arithmetic. The
image-targeting algorithm — contrast-priority bit selection via GF(2) Gaussian
elimination — is an original implementation based on the technique description
in Russ Cox's blog post.

## Quick start

```fish
# Launch the interactive web UI
QART_IMAGE=~/path/to/photo.png mise run serve

# Or with a custom URL and port
QART_URL=https://example.com QART_IMAGE=photo.png QART_PORT=9090 mise run serve
```

The web UI lets you adjust version, mask, rotation, x/y offset, and scale with
live preview. Keyboard shortcuts: arrow keys (dx/dy), `[`/`]` (mask), `-`/`=`
(version), `r` (rotate).

## CLI usage

```fish
# Single image
mise x go -- go run . -url "https://docs.eblu.me" -image photo.png -out qart.png \
  -version 6 -mask 4 -dx 6 -dy 4 -scale 8

# All 8 mask variants
mise x go -- go run . -url "https://docs.eblu.me" -image photo.png -out qart.png -all-masks
```

### Flags

| Flag | Default | Description |
|------|---------|-------------|
| `-url` | (required) | URL to encode in the QR code |
| `-image` | (required) | Source photo (PNG or JPEG) |
| `-out` | `qart.png` | Output file path |
| `-version` | `6` | QR version (1-8, higher = more modules = more detail) |
| `-mask` | `0` | QR mask pattern (0-7, affects visual texture) |
| `-scale` | `8` | Pixels per QR module |
| `-rotation` | `0` | Quarter turns (0-3) |
| `-dx` | `0` | Horizontal image offset (-15 to 15) |
| `-dy` | `0` | Vertical image offset (-15 to 15) |
| `-dither` | `false` | Enable Floyd-Steinberg dithering |
| `-seed` | (random) | RNG seed for reproducible output |
| `-all-masks` | `false` | Generate all 8 mask variants |
| `-serve` | `false` | Launch web UI instead of writing a file |
| `-port` | `8088` | Web UI port |

## Tips

- **Version** controls QR density. Higher = more modules = finer image detail,
  but the code becomes harder to scan at small sizes.
- **Mask** dramatically affects which pixels the algorithm can control. Try all
  8 — the best one varies per image.
- **dx/dy offsets** shift the image relative to the QR structure. Use this to
  avoid the central alignment dot landing on an eye (it makes you look
  unhinged).
- The QR code uses **error correction level L** (lowest) to maximize the number
  of bits available for image rendering.

## Credits

The QArt technique was invented by Russ Cox and described in his 2012 blog
post [QArt Codes](https://research.swtch.com/qart). The
[rsc.io/qr](https://github.com/rsc/qr) library provides the QR code
primitives this tool builds on. Thank you, Russ.

This tool was written by [Claude Code](https://claude.ai/claude-code) (Opus
4.6) with direction from Erich Blume. The image-targeting algorithm is an
original implementation based on the technique description — not a copy of
rsc's reference implementation.
