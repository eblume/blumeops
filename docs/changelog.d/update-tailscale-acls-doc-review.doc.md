Fix drift in the [[update-tailscale-acls]] card from doc review. The
examples still used the legacy top-level `acls` key with `*:*` port
syntax; the policy actually uses the modern `grants` schema with `ip`
port lists, so the examples, prerequisites (pulumi is mise-managed, not a
brew install), and the stale credential-expiry advice are corrected.
Notes the `tests`/`sshTests` invariant sections and the
full-overwrite semantics of `tailscale.Acl`.
