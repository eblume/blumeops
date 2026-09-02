Reviewed the storage backups reference (`docs/reference/storage/backups.md`):
added the missing backup sources `~/.local/share/borgmatic/k8s-dumps` and
`/Volumes/shower`, corrected the Immich photos sources to the `library/` +
`upload/` subdirs, fixed the k8s dump method for mealie/shower to the in-pod
python3 sqlite3 helper and noted mealie's ringtail host, and fixed the Grafana
dashboard name to "Borg Backups". Stamped `last-reviewed`.
