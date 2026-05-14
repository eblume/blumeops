Fix nightly borgmatic backups failing for 2 days. The shower SQLite
dump hook referenced `kubectl --context=k3s-ringtail`, but indri's
kubeconfig deliberately doesn't carry the ringtail credentials. The
`before_backup` hook's failure aborted the entire run, taking out
*both* the local sifaka repo and the BorgBase offsite. Replaced
the inline-shell dump with a `~/bin/borgmatic-k8s-sqlite-dump`
helper deployed by the ansible role. Each dump entry now declares a
`target` of either `local:<context>` (mealie — kubectl uses indri's
kubeconfig) or `ssh:<user@host>` (shower — ssh into ringtail and
run `k3s kubectl` there, no indri-side kubeconfig needed; k3s.yaml
on ringtail is mode 644 so no sudo required). Bytes stream back via
`kubectl exec ... -- cat` rather than `kubectl cp`, since `kubectl
cp` requires `tar` inside the pod and nix-built images like shower
don't bundle it.
