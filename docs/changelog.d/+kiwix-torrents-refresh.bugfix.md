Refreshed all stale ZIM torrent URLs in `kiwix-ringtail/torrents.txt`. kiwix only
keeps the `.torrent` for the latest build of each ZIM, so the whole `_2026-01`
devdocs section plus the `wikipedia_en_top1m_maxi_2025-09` entry had silently
404'd — the kiwix sidecar could no longer add them to transmission. Bumped
wikipedia to `2026-04` and every devdocs package to its current build (mostly
`2026-04`, some `2026-05`); all 43 URLs now resolve 200. Added a note documenting
the latest-only behavior so future 404s are an obvious date bump.
