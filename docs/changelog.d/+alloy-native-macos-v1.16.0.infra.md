Upgrade native macOS Alloy on indri to v1.16.0. Built on gilbert with Go
1.26.2 + CGO (required for the macOS native DNS resolver, which Tailscale
MagicDNS depends on), scp'd to `~/.local/bin/alloy` on indri, codesigned,
and the LaunchAgent reloaded. Completes the v1.16.0 fleet upgrade started
in #345 — all four Alloy services (alloy-k8s, alloy-ringtail,
alloy-tracing-ringtail, alloy ansible) now run v1.16.0.
