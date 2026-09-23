`ringtail-apply@` now sets `restartIfChanged = false`, so a switch no longer
restarts the in-flight ringtail-rebuild apply (a nixpkgs roll rewrites the
unit's NixOS-injected `Environment=` lines, so the old switch killed the
apply's own job and reported a successful apply red). A nixpkgs-update apply
still goes red because the switch restarts the priv runner unit; the docs now
say that directly and list what to check before re-dispatching:
`nixos-rebuild list-generations`, the `/etc/nixos` profile link mtime, and
`/var/log/ringtail-apply/<sha>.log` (eblume/blumeops#1254).
