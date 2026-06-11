[[retire-minikube]] phase 3 groundwork: Nix `default.nix` ports for the
five LGTM-stack containers (prometheus v3.12.0 with the embedded mantine
UI built from source, grafana 12.4.2 from the official release tarball,
loki v3.6.7, tempo v2.10.3, grafana-sidecar 2.6.0), all build-verified
on ringtail. Their Dockerfile/dagger build paths are retired. The
`*-ringtail` manifests stage the move: prometheus-ringtail gains
in-cluster CNPG metrics scrapes for both ringtail pg clusters
(previously dark), alloy-k8s repoints to the external LGTM names and
absorbs the argocd/kube-state-metrics scrapes, and the PVC data copies
+ cutover follow on this branch.
