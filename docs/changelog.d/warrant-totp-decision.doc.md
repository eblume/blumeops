Record the approval-factor decision: no hardware key on hand, so Warrant
v0.2 ships with Authentik session + 1Password-managed TOTP as the step-up.
Invariant 4 amended accordingly; the WebAuthn/hardware upgrade path is
preserved structurally (decisions gate on an authentik flow slug, so
hardware later = authentik config, not Warrant code).
