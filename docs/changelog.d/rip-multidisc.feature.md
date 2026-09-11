`rip-cd` now handles what the second disc of a box set threw at it: several
exact MusicBrainz matches prefill the draft (with `_candidates` to pick
from) instead of leaving it blank, `disc_number`/`disc_total` are filled
from the release and `rip-cd-finish` files a set's discs into one album
folder as `<disc>-NN - Title.flac`, and cd-paranoia's "track 0" (audio
before track 1) is dropped when it is sub-2-second slop or kept as a
hidden track when it is not — previously it produced a stray `00.flac`
that made the finish task refuse. `--skip-rip` no longer overwrites an
edited `metadata.json`. See [[rip-a-disc]].
