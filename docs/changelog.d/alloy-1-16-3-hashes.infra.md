Finish the Nix-built Grafana Alloy v1.16.3 bump (#790, #787): pin the real
fixed-output hashes for the alloy-ui npm deps and the Go module cache
(computed on ringtail, the same nix-container-builder CI uses), build the
image from the branch head, and point alloy-tracing-ringtail at the new
`v1.16.3-<sha>-nix` tag. #790 merged with the hashes intentionally stale for
CI TOFU, so `main` briefly carried an unbuildable containers/alloy.
