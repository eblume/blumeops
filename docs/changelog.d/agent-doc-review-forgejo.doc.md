First review of docs/reference/services/forgejo.md (was never reviewed):
fixed the runner table for the Phase 2 host split — the
`ringtail-priv-runner` (`priv` label, sandboxed DynamicUser) is the third
runner and hosts the warrant-gated dispatch workflows; replaced the
two-entry workflow list with the current twelve in `.forgejo/workflows/`;
Secrets section — `runner_k8s_uuid`/`runner_k8s_token` are gone (the k8s
runner was retired with minikube) and `runner_reg` is the instance-global
registration token for the two ringtail runners, with per-runner identity
secrets now linked to the forgejo-runner card; rewrote Forgejo Actions
Secrets for the blumeops-ci item migration (the role no longer syncs
ARGOCD_AUTH_TOKEN et al. — workflows read blumeops-ci items at job time
with BLUMEOPS_CI_OP_TOKEN; it now syncs FORGE_REPO_WRITE_TOKEN /
BLUMEOPS_CI_OP_TOKEN / RELEASE_FORGE_TOKEN); corrected the API-token PAT
scope to all-scopes admin (CI carries the scoped FORGE_REPO_WRITE_TOKEN
since 2026-08-22); restructured the Repositories table — eblume/alloy and
eblume/tesla_auth are pull mirrors under mirrors/, not eblume repos.
Stamped last-reviewed: 2026-08-29.
