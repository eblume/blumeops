Deploy adelaide-baby-shower-app v1.1.0 to ringtail k3s. Replaces the
boolean lock with a four-phase `ShowerState` (`pre_event` → `party` →
`prizes_locked` → `event_locked`), adds an append-only "guest memories"
panel where guests can leave photos and comments for the baby, and
polishes the admin and QR views. Three Django migrations
(`0009_shower_phase`, `0010_guest_memories`, `0011_book_description`)
run automatically in the entrypoint against the SQLite PV. No config
or env-var changes.

Container build also gains a Forgejo-PyPI workaround: Forgejo's simple
index returns absolute file URLs hardcoded to the public ROOT_URL
(`forge.eblu.me`), which the Fly edge 403s on `/api/packages/*`. The
wheel and sdist are now both pulled via direct `fetchurl` against
`forge.ops.eblu.me` (tailnet-only) and the wheel is handed to pip as
a local path.
