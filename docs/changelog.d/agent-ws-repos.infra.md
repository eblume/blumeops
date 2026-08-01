Which repos the `agents` bot may touch is now **declared, not clicked**.
`containers/agent-ws/repos.json` is one file driving both halves of "share a
repo with the agent": the forge collaborator grant (reconciled by
`mise run agent-repo-access`, wired to the new **Agent Repo Access** workflow)
and the pod's clone loop (`default.nix` reads the same file via
`builtins.fromJSON`). `myeve` and `timberborn-parsimony` join the pool.

Those were previously two independent manual steps, and skipping the grant fails
invisibly: Forgejo answers **404, not 403**, for a private repo the caller cannot
see, and the clone loop is deliberately non-fatal (one unreachable repo must not
crashloop the workspace) — so a missing grant is indistinguishable from a typo,
and the only symptom is a directory that never appears. `timberborn-parsimony`
was documented as a sibling checkout for three weeks while being absent for
exactly this reason.

Reconcile is authoritative: a repo absent from the file has its collaboration
removed, and the workflow's PR job runs `--check` so revocations are visible in
review before the merge that applies them. `blumeops` and `agents` are pinned
read-only by an invariant in the reconciler that the data file cannot override —
their read-only-on-canonical status is what keeps blumeops CI and its
deploy-credentialed Actions secrets out of agent reach, and a fence like that
should not be flippable by a one-line edit to a config file.

The reconciler's admin credential reaches CI the established way — declared in
the `forgejo_actions_secrets` ansible role and pushed by a human with
`mise run provision-indri -- --tags forgejo_actions_secrets`, reusing the
`eblume` PAT that role already authenticates with. That human step is the point:
the `agents` vault is the agent's, the blumeops vault is privileged, and Forgejo
Actions secrets are the curated subset a human deliberately moves across.

Image toolchain version 0.9.0 → 0.10.0.
