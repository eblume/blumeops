`mise run reconcile-authentik-principals` reconciles live Authentik against
the principals rosters: it lists every live account the files do not know
about and empties the retiring queue (`--delete --apply`, with a zot
key-revocation gate and a Grafana JIT-user sweep). `zot-apikey-rotate` now
reads its identity table from the `credential` blocks in `principals.yaml`,
and a new Lint hook fails when the zot accessControl template grants a group
the roster does not declare.
