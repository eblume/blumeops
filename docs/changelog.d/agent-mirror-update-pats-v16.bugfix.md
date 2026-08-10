`mirror-update-pats` works again on Forgejo v16, which broke both halves of it.

The query half died outright: `mirror.remote_address` is now
`encrypted_remote_address`, a BLOB, so the task failed with `no such column` —
and then printed `No GitHub mirrors found.` and exited 0, the same
success-shaped failure the previous fix was meant to end. Discovery now comes
from the API (`/repos/search`, filtered on `mirror`, reading `original_url`),
which needs no database access and cannot break on an internal schema change.

The write half died more quietly. v16 moved the credential off disk into that
encrypted column and rewrites each mirror's git config to a sanitized,
password-free URL, so `git remote set-url` no longer sets the secret Forgejo
actually uses. There is no API for it — `routers/api/v1/api.go` exposes
`mirror-sync` and the `push_mirrors` group and nothing else, and the repo
settings form is the only sanctioned writer.

So the task drives Forgejo's own recovery path. `DecryptOrRecoverRemoteAddress`
treats a NULL `encrypted_remote_address` as "credentials may be on disk": it
reads the URL from git config, encrypts it into the database, and re-sanitizes
the config. Writing the authenticated URL and then clearing the column hands
Forgejo the new credential through the door it already opens for mirrors that
predate the encrypted column. Each mirror is then synced immediately, rather
than left up to 8h in a state indistinguishable from having no credential.

A new guard compares the API's mirror count against `SELECT COUNT(*) FROM
mirror` and refuses to proceed if they differ. The API returns only what the
token can see — 33 of 35 for a token without full visibility — so without this
the task would rotate a subset and report success, leaving the invisible
mirrors on the expiring PAT.

Two caveats worth knowing. Clearing the column is a write to a live WAL
database behind a running Forgejo, done with a busy timeout and immediately
followed by a sync. And the recovery path is documented upstream as being for
mirrors predating the column, so it may be removed — at which point this breaks
again. A pull-mirror credential endpoint is the durable fix and needs asking
for upstream.
