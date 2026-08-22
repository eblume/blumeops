CI secrets migrated to job-time `op read` of `blumeops-ci` vault items
([[blumeops-ci-item-migration]]): `argocd-deploy`, `build-container`,
`deploy-fly`, `build-blumeops` and `cv-deploy` now fetch their credentials
with `BLUMEOPS_CI_OP_TOKEN` at runtime instead of per-secret Actions
secrets, `_1password-cli` joins both ringtail runner sandboxes, and the
`forgejo_actions_secrets` role stops syncing the migrated secrets (talos
and horkos release CI get `BLUMEOPS_CI_OP_TOKEN` instead of the raw zot
key, per the one-CI-trust-tier decision).
