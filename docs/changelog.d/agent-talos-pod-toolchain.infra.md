talos image v0.2.3: bake the `mise run` toolchain (mise, uv, python3,
gnutar/gzip, which), a `/tmp`, and `/usr/bin/env` into the pod. Filing a
warrant request from the pod previously required hand-installing `uv`
and working around the missing `/tmp`; the uv-managed CPython it fell
back to cannot execute in the non-FHS image, so `python3` now rides on
`PATH` instead.
