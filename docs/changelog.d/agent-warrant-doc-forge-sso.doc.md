Correct the Warrant doc's claim that Forgejo login is local and unprotected by
Authentik MFA. The forge has been behind Authentik SSO with TOTP enforced since
2026-02-20 (PR #228), so Phase 0's "enable WebAuthn on the forge account" item
was satisfied before it was written, and dispatch-as-approval met invariant 4
from the start.
