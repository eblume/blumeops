Fix navidrome 0.63.2 crash-loop: the Nix image ships no `/tmp`, so SQLite's
large `bpm`/`bit_depth` migration failed with `disk I/O error: permission
denied` (no writable temp dir for the statement journal). Mount an emptyDir at
`/tmp` (paperless precedent) and switch the deployment to `Recreate` so the old
pod never holds the SQLite DB while a new pod runs startup migrations.
