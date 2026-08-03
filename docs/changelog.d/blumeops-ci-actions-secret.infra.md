Wire the `blumeops-ci` vault tier into CI: the read-only
`blumeops-ci-reader` service-account token provisions into Forgejo Actions
as `BLUMEOPS_CI_OP_TOKEN` ([[warrant-approval-gated-runs]] Phase 2).
The vault starts empty; items migrate via per-workflow audit.
