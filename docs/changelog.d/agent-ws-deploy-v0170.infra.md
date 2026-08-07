Deploy agent-ws `v0.17.0-5418120-nix`, the image built from the
`CLAUDE_CODE_OAUTH_TOKEN` revert. The cluster had stayed pinned to the broken
`v0.16.0` image — which crash-loops, since Remote Control refuses an
inference-only token — because the revert changed `containers/agent-ws/` without
bumping `kustomization.yaml`.
