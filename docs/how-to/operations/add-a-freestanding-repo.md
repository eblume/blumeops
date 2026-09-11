---
title: Add a Freestanding Repo to the Pool
modified: 2026-09-10
last-reviewed: 2026-09-10
tags:
  - how-to
  - operations
  - ai
---

# Add a Freestanding Repo to the Pool

End-to-end procedure for bringing a freestanding repo into the pool. For
what the class is, see [[freestanding-repos]]. Each step names its actor.

1. **(Erich)** Create the forge repo from `project-template` — use forge's
   "use template". The agents bot's PAT cannot create repos.
2. **(talos)** Open a blumeops PR adding one line to
   `argocd/manifests/talos/repos.json`:

   ```json
   { "name": "<repo>", "access": "write", "pool": "canonical" }
   ```

   No `release_hook`. talos authors via its fork (`agents/blumeops`) and
   opens a cross-repo PR to `eblume/blumeops`.
3. **(Erich)** Review and merge the blumeops PR. On merge, the Agent Repo
   Access CI reconciles the collaborator grant and the talos pods roll —
   the `repos.json` ConfigMap name is hash-suffixed, so a policy merge
   replaces pods — and the next pod start clones the repo. The CI run
   itself is expected to go red (the webhook half cannot run in CI);
   that is not a regression — it clears once step 4 lands.
4. **(Erich, from gilbert)** `mise run agent-repo-access` — creates the
   forge → talos webhook (needs the shared signing secret from the blumeops
   1Password vault) and seeds the `agents` engagement label (needs a token
   with label write; the CI token 403s even on label reads). Without
   this step the webhook and label halves are missing and issue activity in
   the new repo will not engage talos.
5. **(talos)** Work in the new repo: CI is cut from `project-template` — as
   of 2026-09-10 the template's release workflow is `workflow_dispatch`
   only, and auto-release-on-merge is being added as part of
   [eblume/blumeops#978](https://forge.eblu.me/eblume/blumeops/issues/978) —
   plus any repo-local mise install task for local installation.

## Failure modes

- Absence from `repos.json` revokes the collaboration — reconcile is
  authoritative, so do not hand-click grants in the forge UI.
- A pooled repo missing its grant answers 404 (not 403), and the clone loop
  is non-fatal — the only symptom of a bad entry is a directory that never
  appears.

## See also

- [[freestanding-repos]] — what the class is
- [[agents-forgejo-bot]] §"Sharing a repo with the bot" — the reconciler and
  the engagement model
