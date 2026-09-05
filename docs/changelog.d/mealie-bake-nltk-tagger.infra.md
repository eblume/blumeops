mealie image bakes the NLTK `averaged_perceptron_tagger_eng` into
`/usr/share/nltk_data` and ships a 1777 `/tmp`, so the non-root container no
longer fetches from GitHub at startup or needs the `/nltk_data` emptyDir
hotfix (#888); pinned as `v3.20.1-0ff99a6-nix`.
