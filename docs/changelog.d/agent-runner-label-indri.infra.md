Renamed the `k8s` compat label on the indri Forgejo runner to the honest
`indri` label across all 6 workflows that used it (`runs-on: k8s` →
`runs-on: indri`), removed `k8s` from `forgejo_runner_labels` in the
`forgejo_runner` ansible role, and updated the docs that described the old
label as current state. The `nix-container-builder` runner is untouched.
