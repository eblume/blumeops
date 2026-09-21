Add the `provision-indri` warrant action: apply a bound blumeops SHA's
nix-darwin generation to indri (`darwin-rebuild switch`) via the zero-prompt
`--tags rebuild` path from the host-mode indri runner — the phase-1 enabler
that turns later box flips from provisioning windows into warrant approvals.
The `provision-indri` task's pushed-HEAD guard is now detached-aware (verifies
origin/main ancestry instead of branch-tip equality), so a non-tip merged
SHA can be applied without a human window. Part of eblume/blumeops#1220.
