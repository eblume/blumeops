Replaced ringtail's swap-based systemd-oomd kill (root slice, `SwapUsedLimit=80%`)
with a PSI pressure-triggered kill scoped to `user.slice`
(`systemd.oomd.enableUserSlices`, 50% avg10 full-pressure for 30s). The swap
counter ratchets — stale slot accounting (12.6G "used" vs ~1.6G real zram data
at 111d uptime) kept the kill condition permanently armed, executing the desktop
session on every RAM spike, and the kills could never reclaim the stale slots
that armed them. Pressure is measured, not bookkept, and k3s pods are
structurally outside `user.slice`, so pods remain non-candidates by construction.
