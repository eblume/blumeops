Clear out the last references to the Homebrew-era forgejo tree, which the
brew→source migration left behind in three places. The husk at
`/opt/homebrew/var/forgejo` still exists on indri, frozen at 2026-04-06, so each
of these read something plausible rather than erroring — the reason none of them
were noisy.

- `mirror-update-pats` queried the husk's `forgejo.db` for the mirror list and
  resolved bare repos under the husk's `forgejo-repositories`. Against a
  four-month-old snapshot it would skip any mirror added since, and rewrite
  remotes on paths that are no longer the live ones. It now reads
  `~/forgejo/data`, matching `forgejo_work_path`.
- The alloy role tailed `/opt/homebrew/var/log/forgejo.log` for the `forgejo`
  service. The forge writes `~/Library/Logs/mcquack.forgejo.{out,err}.log` as a
  LaunchAgent, so **the forge's own log has never reached Loki since the brew
  exit.** Moved to `alloy_mcquack_logs` with both streams.
- The backup policy doc still listed the husk as the critical forgejo source
  directory; borgmatic has backed up `~/forgejo` plus a WAL-safe `forgejo.db`
  dump since the migration.

`mirror-update-pats` also grows a preflight check on the database path. It
swallowed sqlite3's stderr and treated an empty result as "No GitHub mirrors
found", so a wrong path exited 0 with a success-shaped message; since the task
is driven by the github-mirror-pat rotation, that surfaces as mirrors quietly
going stale after a rotation rather than as an error during it. The query is
now `-readonly`, appropriate for a database forgejo is serving live.
