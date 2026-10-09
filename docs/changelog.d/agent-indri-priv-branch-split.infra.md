Split the `pull_request`-triggered `indri` jobs (`forge-reconcile`,
`indri-flake-check`, `lint` → `workflows-validate`) onto the unprivileged
`indri-build` runner via a trigger-conditional `runs-on`, so nothing
triggerable by a PR executes on the privileged `indri` label (#1358).
