Add the `ringtail-rebuild` warrant action: apply a bound blumeops SHA to
ringtail (`nixos-rebuild switch`) through a single root path from the priv
runner — starting the `ringtail-apply@<sha>` unit, polkit-gated — in the
warrant-approval-gated-runs decomposition. First step toward
`provision-ringtail`, which stays `deny` (its ansible pre_tasks read the
blumeops vault).
