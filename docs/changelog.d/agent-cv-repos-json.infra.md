Grant the `agents` bot read access to the private `eblume/cv` repo (the
`cv` service at cv.eblu.me) by adding it to repos.json, so the recurring
service review can finally review it from the pod. cv had been the most
stale service (last reviewed 2026-04-29) and was skipped every run because
the bot had no forge grant — Forgejo 404s the private repo, exposing only
the unauthenticated deployed-tarball endpoint, not the source or release
list. `pool: none`: the review flow clones the source on demand, so no
persistent checkout or webhook is needed; the release flow (dagger rebuild
+ Forgejo release) stays human-side, so read (not write) is all the bot
needs.
