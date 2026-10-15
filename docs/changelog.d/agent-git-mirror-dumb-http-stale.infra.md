The fly git-mirror's dumb-HTTP metadata (`info/refs`, pack index) is kept
fresh entirely by a non-fatal, logged `post-receive` (failures to
`/volume/git-mirror/hooks.log`) whose final `update-server-info` runs
after the repack, with an EXIT-trap backstop — a failing cosmetic hook
step can no longer serve stale refs (eblume/blumeops#1640).
