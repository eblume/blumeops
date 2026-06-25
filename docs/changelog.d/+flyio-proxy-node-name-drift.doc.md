Documented the [[flyio-proxy]] Tailscale node name drift (`flyio-proxy` →
`flyio-proxy-1` → `-2`): caused by ephemeral microVM state with no persisted
`/var/lib/tailscale`, benign because routing/ACLs are tag-based and offline
nodes auto-GC. Recorded the Fly-volume fix and the decision not to apply it
(volume anchors the otherwise stateless proxy to one host).
