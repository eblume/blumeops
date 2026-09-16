`rip-video` no longer mislabels its output: makemkvcon renumbers the
titles that survive `--minlength`, so the inventory's `DD1_t06.mkv` came
out of the rip as `DD1_t01.mkv` and `metadata.json` pointed at a file that
did not exist. The `all` pass now renames its outputs back to the
inventory's names, explicit `--titles` rip one title per pass without
`--minlength` so the ids mean what the inventory said, and ejecting
force-unmounts the disc volume first (as `rip-cd` now does). Found on The
Prestige. See [[rip-a-disc]].
The how-to also gains a section on discs that will not read: the drive
wedge, and imaging with ddrescue before ripping from the image.
`rip-video-finish` also accepts `extra:<Name>` and `extra:<kind>/<Name>`
targets for TV, filing bonus-disc material into the season's Jellyfin
extras folders.
Every makemkvcon call in `rip-video` (inventory scan, `all` rip, explicit
titles) now passes the same `--min-length`, since makemkvcon numbers titles
after that filter; a bonus disc scanned at the default and ripped at 60 s
had produced 29 files for a 13-title inventory.
