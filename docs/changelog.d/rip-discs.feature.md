Disc archiving on indri is now four mise tasks instead of a chain of GUI apps:
`rip-cd`/`rip-cd-finish` (cd-paranoia → FLAC → tagged into `/Volumes/music`)
and `rip-video`/`rip-video-finish` (makemkvcon → Jellyfin layout in
`/Volumes/allisonflix`), split around an editable `metadata.json` so the
labeling step can be done by hand or by an agent. Replaces XLD + Picard +
MakeMKV GUI + FileBot (license lapsed). See [[rip-a-disc]].
