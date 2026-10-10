forge-reconcile `--check` now fails on any repo targeting a privileged runner
label it is not declared to (indri, indri-priv, priv, nix-container-builder) —
the label-usage drift guard for the #1358 runner re-scoping.
