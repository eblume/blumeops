The FOD eval check now pins fetcher `postFetch` text by exact-text allow-list (`fod-eval-check/allowed-postfetch.json`) instead of accepting it unconditionally on the fetchzip, fetchgithub, fetchpatch and fetchgit families.
The allow-list ships empty, so any non-empty `postFetch` on those families is currently reported as unlisted until entries are reviewed and added.
