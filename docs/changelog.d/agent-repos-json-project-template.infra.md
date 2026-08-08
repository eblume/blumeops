Share `eblume/project-template` with the agents bot — `write` + `canonical` in
`containers/agent-ws/repos.json`, so it lands in the pod's checkout pool like any
other worked-on repo. Three open template tasks (rename `build.yaml`, pin the
mise versions, reconcile the `prek` step) all stalled at the same line in their
notes: *"NOT checked out under ~/code/personal — a later session must clone it to
edit."* The repo is public, so it was always readable; what was missing was push,
and a checkout to notice it from.

Also corrects the bootstrap how-to, which still told a human to grant repo access
by hand in the Forgejo web UI and listed a repo set predating `repos.json`. That
instruction is now actively wrong: the reconcile is authoritative in both
directions, so a hand-clicked grant is reverted on the next run.
