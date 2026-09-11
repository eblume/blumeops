---
title: Rip a Disc
modified: 2026-09-11
last-reviewed: 2026-09-11
tags:
  - how-to
  - operations
  - media
---

# Rip a Disc

Archive an audio CD, DVD or Blu-ray from the Pioneer BDR-S13U USB drive on
[[indri]] into the [[navidrome]] or [[jellyfin]] library. Four `mise` tasks,
run **on indri** (they need the drive), in two halves with a labeling step
between them:

| Disc | Extract | Label | File |
|------|---------|-------|------|
| Audio CD | `mise run rip-cd` | edit `metadata.json` | `mise run rip-cd-finish <dir>` |
| DVD / Blu-ray | `mise run rip-video` | edit `metadata.json` | `mise run rip-video-finish <dir>` |

The split is deliberate. Extraction is mechanical; naming is where the
judgement lives — an obscure local pressing no database knows, a
MusicBrainz candidate that is the wrong country's release, CD-TEXT that
dropped its apostrophes, or a TV disc where episode order has to be
reconstructed from durations and chapter counts. That step is a JSON file
anyone can edit, including an agent in a Claude Code session on indri, which
is the intended way to run this: `rip-cd`, let the agent research and fill
the draft, review, `rip-cd-finish`.

## Audio CD

```fish
mise run rip-cd                    # → ~/rips/cd/<slug>-<discid8>/
```

`rip-cd` reads the table of contents and CD-TEXT with `cd-info`, computes
the MusicBrainz and freedb disc IDs, asks MusicBrainz for releases matching
the disc, then extracts with `cd-paranoia` (secure mode, full retries) and
encodes to FLAC with ffmpeg. The drive ejects when extraction finishes. It
writes:

- `01.flac … NN.flac` — untagged tracks
- `paranoia.log` — cd-paranoia's per-track summary; a blank bar is a clean read
- `rip.json` — disc IDs, TOC, CD-TEXT, MusicBrainz candidates, and a
  `submit_url` for adding an unknown disc ID to MusicBrainz
- `metadata.json` — the draft: a single exact MusicBrainz match fills it in,
  otherwise CD-TEXT does, otherwise it is blank

Review `metadata.json`. `artist`, `album` and every track `title` are
required; `artist_sort` names the library folder (`Bowie, David`);
`musicbrainz_release_id` fetches cover art from the Cover Art Archive when
`cover` (path or URL) is unset. Then:

```fish
mise run rip-cd-finish ~/rips/cd/<dir> --dry-run   # show the plan
mise run rip-cd-finish ~/rips/cd/<dir> --clean     # tag, move, remove staging
```

Tracks land in `/Volumes/music/<artist_sort>/<album>/NN - Title.flac` with
`cover.jpg` and `<album>.rip.log` beside them, and [[navidrome]] finds them
on its hourly scan (its NFS mount is the same sifaka share). Older albums in
the library sit directly under the artist folder — that was XLD's layout —
and Navidrome does not care about the difference.

Re-running `rip-cd` on a disc whose staging dir exists resumes: tracks with a
FLAC are not re-extracted, and an edited `metadata.json` is never
overwritten. `--skip-rip` refreshes `rip.json` without running cd-paranoia.

## DVD / Blu-ray

```fish
mise run rip-video                 # → ~/rips/video/<label>-<timestamp>/
```

`rip-video` inventories the disc with `makemkvcon info`, rips every title at
least `--min-length` seconds long (default 600; `--titles 0,3` picks
explicitly), and ejects. `rip.json` lists each title's duration, chapter
count, size and source playlist; `metadata.json` is the draft, with the
longest title pre-marked as the feature.

Set `kind`:

- **movie** — `title`, `year`; each file's `target` is `"feature"`,
  `"extra:<Name>"`, or `null` to drop it.
- **tv** — `show`, `season`; each file's `target` is `"E3"`,
  `"E3:Episode Title"`, `"E3-4"` for a double episode, or `null`.
  `season_dir` overrides the `Season NN` folder name for shows already
  filed with another convention.

```fish
mise run rip-video-finish ~/rips/video/<dir> --dry-run
mise run rip-video-finish ~/rips/video/<dir> --clean
```

Files go to `/Volumes/allisonflix/Movies/<Title (Year)>/<Title (Year)>.mkv`
(extras under `extras/`) or
`/Volumes/allisonflix/TV/<Show>/Season NN/<Show> - SNNENN - <Title>.mkv`,
which [[jellyfin]] parses without any sidecar metadata. Nothing in the
library is ever overwritten; a clash aborts the whole move.

## What this replaced

Until 2026-09 the drive was driven by GUI apps: XLD auto-started secure rips
of audio CDs into `~/tmp` (gnudb lookups, AccurateRip), MusicBrainz Picard
tagged them, MakeMKV's GUI ripped video into `~/Movies`, and FileBot renamed
it for Jellyfin. None of it was scriptable — XLD's command line only decodes
files, not discs — and FileBot's license lapsed in 2025-11. The apps are
still installed and still work for a one-off; the tasks above are the
supported path.

Trade-off worth knowing: cd-paranoia verifies by re-reading, not against
AccurateRip. For a pressing that *is* in AccurateRip and matters, XLD's GUI
still gives the stronger guarantee.

## Requirements on indri

| Tool | Source | Used by |
|------|--------|---------|
| `cd-paranoia`, `cd-info` | Homebrew `libcdio-paranoia` (in the dotfiles Brewfile) | `rip-cd` |
| `ffmpeg` | Homebrew | `rip-cd` |
| `makemkvcon` | Homebrew cask `makemkv` (needs a current MakeMKV key) | `rip-video` |
| `drutil` | macOS | both |
| `/Volumes/music`, `/Volumes/allisonflix` | [[automounter]] | the finish tasks |

The tasks guard their binaries with `_require`, so running one from
[[gilbert]] or an agent pod fails at the door with an explanation.

## Related

- [[navidrome]] — where CDs end up
- [[jellyfin]] — where video ends up
- [[automounter]] — the SMB mounts the finish tasks write through
- [[mise-tasks]] — the full task list
