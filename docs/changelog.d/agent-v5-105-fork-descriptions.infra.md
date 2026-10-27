forge-reconcile now manages each managed fork's description from a top-level `managed_fork_description` template in repos.json: `--check` fails on drift, and an apply with `--fork-token` sets it.
