Add a second, unprivileged Forgejo Actions runner on indri: the dedicated
`indri-build` macOS user (no sudo, home 0700) runs a colima-backed runner
daemon (label `indri-build`), with the runner identity and colima profile
role-rendered and gated on registration. Moving workflows to the new label
follows in eblume/blumeops#1358.
