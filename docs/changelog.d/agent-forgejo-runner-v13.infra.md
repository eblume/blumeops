Bump the indri forgejo-runner pin from v12.13.2 to v13.1.0 (the 13.x
release line). The v13 breaking changes (removed GITEA_ env vars, removed
container network_mode, removed secret-based registry auth) were audited
against the indri runner config template and all pooled repo workflows:
none are used, and the template's config keys all survive v13.1.0's
schema (checked against its config.example.yaml). The source-built
binary on indri is rebuilt at the new tag in a human provision window;
until then provision-indri will fail its version check by design.
Tracked in eblume/blumeops#865.
