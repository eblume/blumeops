Closed two backup gaps in the [[borgmatic]] role on [[indri]]. The
[[hephaestus|heph]] hub DB (`heph.db`, the only copy of all task/context data)
is now snapshotted by a before-backup `sqlite3 .backup` hook — WAL-safe and
fails loud, unlike borgmatic's native `sqlite_databases` hook whose `.dump` can
fail silently on a live WAL database. [[navidrome]]'s database (users, play
counts, playlists) — a gap predating the ringtail migration — is now captured by
enabling navidrome's own `ND_BACKUP_*` snapshots (`/data/backup`, daily 01:00,
keep 7) and ferrying the newest snapshot off the PVC via a new
`borgmatic_k8s_file_dumps` hook (`ls`/`cat` over `kubectl exec`); this added
`coreutils` to the navidrome nix image for the in-pod tooling.
