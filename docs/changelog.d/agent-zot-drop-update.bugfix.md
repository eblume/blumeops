Drop `update` from the per-repo zot release identities, so tags are immutable for every non-admin identity. Release re-runs skip the push when the tag already holds the same digest.
