talos image v0.2.3: bake the `mise run` toolchain (mise, uv, python3,
gnutar/gzip, which), a `/tmp`, and `/usr/bin/env` into the pod, and wrap
`tea` to route through the tag:agent SOCKS sidecar. Filing a warrant
request or opening a PR from the pod previously required hand-installing
`uv`, hand-exporting proxy env for `tea`, and working around the missing
`/tmp`; the uv-managed CPython it fell back to cannot execute in the
non-FHS image, so `python3` now rides on `PATH` instead.
