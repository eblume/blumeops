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
- `metadata.json` — the draft: an exact MusicBrainz match fills it in,
  otherwise CD-TEXT does, otherwise it is blank

Review `metadata.json`. `artist`, `album` and every track `title` are
required; `artist_sort` names the library folder (`Bowie, David`);
`musicbrainz_release_id` fetches cover art from the Cover Art Archive when
`cover` (path or URL) is unset. Things the draft flags for you:

- **Several exact matches** (`_source` says so, `_candidates` lists them) —
  the same album pressed in several countries or packagings. The first one
  filled the draft; swap `musicbrainz_release_id` if another is the disc in
  your hand, since that decides which cover art is fetched.
- **A disc of a set** — `disc_number`/`disc_total` come from MusicBrainz
  when the release has more than one medium; set them by hand otherwise.
  The finish task files every disc of a set into the same album folder as
  `<disc>-NN - Title.flac`, so the discs can be ripped in any order.
- **A hidden track** — audio of 2 s or more before track 1 is ripped as
  `00.flac` and the draft carries a track `0` for it; title it, or delete
  both. Shorter pregap audio (common, and silent) is dropped without comment
  beyond a log line.

Then:

```fish
mise run rip-cd-finish ~/rips/cd/<dir> --dry-run   # show the plan
mise run rip-cd-finish ~/rips/cd/<dir> --clean     # tag, move, remove staging
```

Tracks land in `/Volumes/music/<artist_sort>/<album>/NN - Title.flac` with
`cover.jpg` and `<album>.rip.log` (`<album>.disc<N>.rip.log` for a set)
beside them, and [[navidrome]] finds them
on its hourly scan (its NFS mount is the same sifaka share). Older albums in
the library sit directly under the artist folder — that was XLD's layout —
and Navidrome does not care about the difference.

Re-running `rip-cd` on a disc whose staging dir exists resumes: tracks with a
FLAC or a complete WAV are not re-extracted, a partial WAV from an
interrupted run is discarded, only the missing span is ripped, and an edited
`metadata.json` is never overwritten (a regenerated draft goes to `metadata.draft.json` beside it).
`--skip-rip` refreshes `rip.json` without running cd-paranoia; it still
needs the disc in the drive, since the disc IDs come from the TOC.

### Audiobooks

An audiobook CD is ripped exactly like a music disc, but filed differently:
set `"kind": "audiobook"` in `metadata.json` and the finish task writes
[Audiobookshelf](https://www.audiobookshelf.org/)'s layout (blumeops issue #1120 deploys it) under the same share, one file per disc:

```
/Volumes/music/Audiobooks/<author>/[<series>/]<title>/Disc NN.opus
```

The metadata keys are `artist` (author), `album` (title), optional `series`,
`series_part` and `narrator`, plus `disc_number`/`disc_total`. Track titles
are not needed: audiobook CDs cut a track every few minutes as seek points
for car players, not chapters, so the finish task concatenates the disc's
tracks losslessly and encodes once. Each disc then shows up as one chapter
in Audiobookshelf; real chapters, if wanted, are added there by hand. Opus
at 48 kb/s is the default because it is speech (a 17-hour book is about
400 MB rather than 5 GB); `--lossless` keeps FLAC.

MusicBrainz rarely knows audiobook discs, so expect to fill the draft by
hand. Rip the discs in any order; `disc_number` names the file. The
`Audiobooks/` folder carries a `.ndignore` marker, so [[navidrome]] skips
it and Audiobookshelf's library is pointed at that folder alone.

## DVD / Blu-ray

```fish
mise run rip-video                 # → ~/rips/video/<label>-<timestamp>/
```

`rip-video` inventories the disc with `makemkvcon info`, rips every title at
least `--min-length` seconds long (default 600; `--titles 0,3` picks
explicitly), and ejects. `rip.json` lists each title's duration, chapter
count, size and source playlist; `metadata.json` is the draft, with the
longest title pre-marked as the feature.

The inventory is makemkvcon's own numbering (it hides titles under two
minutes itself), and the staged files carry those ids — `DD1_t06.mkv` is
title 6 — even though makemkvcon renumbers internally when it rips with a
minimum length; the task renames its outputs back. A DVD's play-all
featurette usually appears once as a long title and again as its segments,
each a few minutes; keep the long one.

Set `kind`:

- **movie** — `title`, `year`; each file's `target` is `"feature"`,
  `"extra:<Name>"`, or `null` to drop it.
- **tv** — `show`, `season`; each file's `target` is `"E3"`,
  `"E3:Episode Title"`, `"E3-4"` for a double episode, or `null`.
  `season_dir` overrides the `Season NN` folder name for shows already
  filed with another convention.
  Bonus-disc material takes `"extra:<Name>"` (filed under the season's
  `extras/`) or `"extra:<kind>/<Name>"` with a Jellyfin extras folder name —
  `featurettes`, `deleted scenes`, `behind the scenes`, `interviews`,
  `trailers` — and shows up under that season's Extras in Jellyfin with no
  sidecar metadata. Rip a bonus disc with `--min-length 60`, since most of
  its titles are shorter than the default cutoff.

```fish
mise run rip-video-finish ~/rips/video/<dir> --dry-run
mise run rip-video-finish ~/rips/video/<dir> --clean
```

Files go to `/Volumes/allisonflix/Movies/<Title (Year)>/<Title (Year)>.mkv`
(extras under `extras/`) or
`/Volumes/allisonflix/TV/<Show>/Season NN/<Show> - SNNENN - <Title>.mkv`,
which [[jellyfin]] parses without any sidecar metadata. Nothing in the
library is ever overwritten; a clash aborts the whole move.

## A disc that will not read

Counterfeit pressings (shrink-wrapped, InterActual files and all) show up
as `MEDIUM ERROR: L-EC UNCORRECTABLE ERROR` in makemkvcon's messages, then
`Failed to save title N`. Cleaning rarely helps; the sectors are bad in the
plastic. Two things to know:

- **The drive wedges.** On these sectors the Pioneer retries inside its
  firmware for minutes, the reading process sits in an uninterruptible
  wait at zero CPU, and afterwards `drutil status` and `diskutil eject`
  hang too. Kill the reader, then press the drive's eject button or
  replug its USB cable. Nothing software-side clears it.
- **Image it, then rip the image.** `brew install ddrescue`, unmount the
  volume (`diskutil unmount force /Volumes/<label>`), and run

  ```fish
  ddrescue -b 2048 -s <bytes from diskutil info> -n /dev/rdiskN disc.iso disc.map
  ```

  It copies everything readable in one pass and skips the rest, so a
  disc makemkvcon gives up on comes out 98% intact. Skip the retry and
  scrape passes (`-r`, no `-n`): each unreadable sector costs the drive
  10–30 s, so recovering a few more kilobytes takes hours. Then
  `makemkvcon -r mkv iso:disc.iso <title> <dir>` extracts titles from the
  image with no drive involved, and a hand-written `metadata.json`
  (same schema as the draft) lets `rip-video-finish` file them. Decode-check
  the result (`ffmpeg -v error -i f.mkv -map 0:v:0 -f null -`, ignoring the
  null muxer's `non monotonically increasing dts` noise, which every DVD rip
  produces) and note where the glitches fall before filing.

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

**One process on the drive at a time.** A `makemkvcon info` probe while
cd-paranoia is reading (or the MakeMKV GUI opening on insert) contends for
the drive and can leave the rip stuck in an uninterruptible read with zero
CPU and a WAV that stops growing. Kill it and rerun; the rip resumes. Disc
auto-launch is off on indri (`defaults read com.apple.digihub` shows
`action = 1` for music CDs and video DVDs); keep it that way.

The tasks guard their binaries with `_require`, so running one from
[[gilbert]] or an agent pod fails at the door with an explanation.

## Related

- [[navidrome]] — where CDs end up
- [[jellyfin]] — where video ends up
- [[automounter]] — the SMB mounts the finish tasks write through
- [[mise-tasks]] — the full task list
