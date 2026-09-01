Add the `ringtail-rebuild` warrant action: apply a bound blumeops SHA to
ringtail (`nixos-rebuild switch`) through a single NOPASSWD sudo rule for
`/etc/ringtail-apply/apply` on the priv runner, in the
warrant-approval-gated-runs decomposition. First step toward
`provision-ringtail`, which stays `deny` (its ansible pre_tasks read the
blumeops vault).
