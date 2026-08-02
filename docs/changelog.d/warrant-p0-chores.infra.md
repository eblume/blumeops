Warrant P0 chores: `agent-repo-access.yaml` moves off the retired `k8s`
runner label (the one straggler added after #439 branched), and
`policy.hujson` gains `sshTests` pinning two invariants — `tag:agent` has no
Tailscale SSH anywhere, and the load-bearing homelab→homelab SSH (borgmatic's
`ssh:eblume@ringtail` dumps, the rule PR #441 nearly removed) can't be
dropped silently.
