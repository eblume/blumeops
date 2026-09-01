Reviewed the Borgmatic service card (`docs/reference/services/borgmatic.md`):
added missing backup sources — `/Volumes/shower` (SMB mount), the local
Forgejo SQLite dump, and the horkos k8s dump — corrected the Immich photos
sources to the `library/` + `upload/` subdirs with their excludes, and fixed
the Grafana dashboard name to "Borg Backups". Stamped `last-reviewed`.
