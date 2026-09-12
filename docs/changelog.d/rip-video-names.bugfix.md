`rip-video` no longer mislabels its output: makemkvcon renumbers the
titles that survive `--minlength`, so the inventory's `DD1_t06.mkv` came
out of the rip as `DD1_t01.mkv` and `metadata.json` pointed at a file that
did not exist. The `all` pass now renames its outputs back to the
inventory's names, explicit `--titles` rip one title per pass without
`--minlength` so the ids mean what the inventory said, and ejecting
force-unmounts the disc volume first (as `rip-cd` now does). Found on The
Prestige. See [[rip-a-disc]].
