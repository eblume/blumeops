Flipped the private forge's identity to the tailnet name: `forgejo_domain` (and
therefore `DOMAIN`/`ROOT_URL`) is now `forge.ops.eblu.me`, so the instance's
canonical URL — and the OAuth callback it advertises to Authentik — is the ops
name. The public `forge.eblu.me` relay keeps working in the meantime (verified
against the v16.0.2 source that nothing rejects a `Host: forge.eblu.me`
request) and swaps to the read-only static mirror at the later cutover stage of
the public/private split. The `build-blumeops` `GITHUB_SERVER_URL` check is
re-armed as a hard failure — it reads the *live* `ROOT_URL`, so the first
manual release dispatch after merge must wait for the `provision-indri
-- --tags forgejo` run to re-render it, or it fails. The Authentik launch URL
moves to ops, and the machine-facing forge links in the docs follow the flip.
(eblume/blumeops#1208.)
