`argocd-deploy.yaml` — the first approval-gated privileged workflow
([[warrant-approval-gated-runs]] Phase 1): a human-dispatched `app set
--revision <sha>` + sync + wait-healthy, with SHA/app validation and
env-indirected inputs. Introduces the `priv` runner label (advertised by the
indri runner until the dedicated Phase-2 runner exists). Makes the
"deploy from branch/merge" step agent-requestable via
`mise run request-run`.
