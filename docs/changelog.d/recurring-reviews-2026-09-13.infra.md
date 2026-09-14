Daily service review: unpoller (argocd, last reviewed 2026-05-28). Bumped the
Nix build from v3.2.0 to v5.2.5 (latest stable, 2026-09-12) — the full train
jump eblume asked for on [eblume/blumeops#1048](https://forge.eblu.me/eblume/blumeops/issues/1048),
not just the latest v3 patch. Changelog v3.3.0→v5.2.5 reviewed release by
release: additive metrics/labels and dependency bumps throughout; the only
schema change in the span is v4.0.0's UNAS flag refactor, and UNAS is opt-in
and never configured here (stateless exporter, single up.conf, API key via
ExternalSecret), so no config changes are needed. v5.0.0's GitHub release
body is gone upstream (release deleted; the git tag survives in our mirror) —
small residual uncertainty, acceptable for a non-critical diagnostic plane.
Two build changes: v5.2.5's go.mod floor is go 1.26.0, so buildGoModule is
pinned to go_1_26 (same pattern as tempo/tailscale); v5's main.go no longer
declares the golift.io/version symbols, so the dead -X ldflags are trimmed.
The fetchgit hash for v5.2.5 was verified in-pod against the forge mirror
(the method reproduces the committed v3.2.0 hash exactly); vendorHash is left
as fakeHash for the CI TOFU round (the pod's build seccomp filter blocks the
in-pod go module download). The kustomization newTag lands in a follow-up
commit once the build-container warrant build is green; the app is
Automated (Prune), so the deploy is the merge itself.
