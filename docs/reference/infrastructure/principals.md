---
title: Principals
modified: 2026-10-16
last-reviewed: 2026-10-15
tags:
  - reference
  - infrastructure
  - ai
---

# Principals

Every non-human identity that **acts** in this infrastructure is named by
**who authorized the action**, not by which system it touches. This card is
the reference: the scheme, the live inventory, and the one documented
exception. Decided 2026-09-12 from the security review of eblume/talos#172;
the grandfathered names were retired one at a time in the eblume/blumeops#1039
series, which closed with this reference.

## The scheme

| prefix | meaning | examples |
|---|---|---|
| `talos-` | the agent decided on its own | session-readable credentials, the read-only-on-canonical forge bot |
| `horkos-` | a human approved this specific act, via a warrant | the dispatch identity, the pin-PR author |
| `ci-` | a human approved it by merging to main | release pipelines, ArgoCD's deploy account, the registry push keys |
| `cli-` | a human authorized it through a live, supervised CLI session | `cli-agent` ([[cli-agent-forgejo-principal]]) |

The `cli-` tier was added after the series (2026-10-13 incident, see the
cli-agent card): it names acts authorized by Erich's direct, biometric-gated
consent on the host he is at — a live human, not a merge and not a warrant.

Format: `<tier>-[qualifier]` — tier first, because the tier is what a reader
needs before touching a credential. The prefix says which gate created the
identity: a `talos-` credential any agent session can read, a `horkos-` one
because a human approved the specific act it performs, a `ci-` one because a
human merged the pipeline that uses it.

CI stays its own tier rather than folding into horkos: horkos is per-act
approval with a policy check; a merge is a coarser gate, and CI's credentials
sit on the far side of a fence horkos itself must not cross. Calling both
"horkos" would make one word mean two gates.

**What is not a principal:**

- **Warrant the artifact.** `warrant-policy.yaml`, the `Warrant request: #N`
  PR stamp, and the word for the minted approval (a *warrant*) keep their
  names — they are the record a human signs, not an identity that acts. The
  service's old name is likewise not a principal: it was renamed to Horkos in
  2026-08 ([[horkos]]).
- **Vault names** (`agents`, `blumeops`, `blumeops-ci`) name storage, not
  actors, and are out of scope — but `agents` is to be read as "the talos
  vault". Same for repo names (the `agents` repo carries the base agent
  instructions).
- **Blueprint object ids and field names** are internal keys, not identities:
  what matters is the `identifiers:` they pin (username, client_id, app slug).

- **Item names that name the artifact, not the principal.**
  `blumeops-ci/horkos-dispatch` (the CI mirror of the `horkos-forge`
  PAT) deliberately keeps its artifact name — the 2026-10-15 ruling is
  leave-as-is, with the pointer to `horkos-forge` in the item's notes
  ([[blumeops-ci-item-migration]]).

## Live inventory

| principal | where it lives | tier | credential |
|---|---|---|---|
| `talos` | forge user; owns the `talos/*` fork namespace and the `talos` engagement label | talos | `op://agents/talos-forgejo-token` |
| `cli-agent` | forge user for interactive CLI sessions; own `cli-agent/` fork namespace ([[cli-agent-forgejo-principal]]) | cli | biometric-gated; see that card |
| `horkos-forge` | forge user, write on `eblume/blumeops` only — the Horkos dispatch identity ([[horkos]]) | horkos | `op://blumeops/horkos-forge-token`, mirrored to `op://blumeops-ci/horkos-dispatch` |
| `ci-argocd` | ArgoCD account; CI/CD automation ([[argocd]]) | ci | `op://blumeops-ci/ci-argocd` |
| `talos-argocd-readonly` | ArgoCD account; lets the agent pod inspect deployment state ([[argocd]]) | talos | `op://agents/talos-argocd-readonly` |
| `ci-zot` | Authentik user; base CI zot push identity ([[zot]]) | ci | `Forgejo Secrets` field `ci-zot-api` (blumeops vault); `op://blumeops-ci/ci-zot` |
| `ci-zot-talos`, `ci-zot-horkos` | Authentik users; per-repo release-CI push keys ([[zot]]) | ci | `ci-zot-talos-api` / `ci-zot-horkos-api` fields → `ZOT_PUSH_API_KEY` on eblume/talos, eblume/horkos |
| `horkos-zot` | Authentik user; the horkos publisher's zot push identity ([[zot]]) | horkos | `Forgejo Secrets` field `horkos-zot-api` |
| `ci-authentik-blueprints` | Authentik user; applies the Authentik blueprints | ci | `ci-authentik-blueprints-token` (blumeops vault) |
| `talos-m2m` | Authentik `client_credentials` client + `talos-sa` group; consumed by talos and horkos OIDC | talos | `Authentik (blumeops)` fields `talos-m2m-client-secret` / `talos-m2m-app-password` (blumeops vault, ESO-mounted) |
| `talos-ringtail` | Authentik user in `talos-sa`; the ringtail agent workspace | talos | `op://agents/talos-ringtail` |
| `talos-heph` | Authentik user + group; the agent heph spoke | talos | `op://agents/heph-spoke-token` |
| `tag:talos` | Tailscale tag; the egress-gateway pod's identity ([[tailscale]]) | talos | — |
| `tag:ci-gateway` | Tailscale tag; ephemeral CI containers pushing to the registry ([[tailscale]]) | ci | — |

Every principal above follows the scheme, including the post-series `cli-`
tier. If a future account is needed for the issue-writer discussion in
eblume/talos#172, it is `talos-forge-issues`.

**Live `argocd-cm` / `argocd-secret` can carry more than the table.** The bootstrap's old `kubectl` field manager still owns keys the repo manifests no longer declare, and ArgoCD's sync never prunes them — a "Synced" app can hold orphaned account and token records. Check the live objects, not just the manifests; the mechanism is in [[argocd]] §"Bootstrap-owned fields survive sync".

## Exception: `FORGE_REPO_WRITE_TOKEN`

CI acting as eblume. Collaborator management needs repo admin, which only the
owner holds on user-owned repos, so it cannot become a `ci-forge` account
without an org move. Documented deliberately as a known exception rather than
left implicit: an `eblume` PAT scoped `write:repository,read:user`, declared
in `forge/actions-secrets.json` and consumed by `mise run forge-reconcile`
(see §"Sharing a repo with the bot" below).

## The talos forge bot

The Forgejo identity that [[agent-workspaces]] use to push work. Agents commit
and push **branches**; branch protection on `main` and human PR review are the
gate before anything deploys.

### Identity

- **Forgejo user:** `talos`
- **SSH key:** retired (Oct 2026, eblume/blumeops#1635). The bot authenticates
  to the forge over HTTPS with a token; no SSH key is seated on ringtail.

### Access policy

- **Write** (push branches, open PRs) to the repos talos works in:
  `hephaestus.nvim`, `research`, `myeve`, `timberborn-parsimony`,
  `gamedev`. Access is per-repo **collaborator** grants, not an org-wide role —
  the bot sees nothing it was not explicitly added to.
- **`blumeops`: read-only, author via fork.** The bot has **read** on the
  canonical `eblume/blumeops` and pushes to its own fork **`talos/blumeops`**,
  opening cross-repo PRs. Read (not write) is load-bearing: `workflow_dispatch`
  is write-gated, so a read-only bot **cannot trigger blumeops' CI** and thus
  cannot reach its Actions secrets — the deploy-credentialed ones migrated to
  job-time `op read`s of `blumeops-ci` items behind `BLUMEOPS_CI_OP_TOKEN`
  ([[blumeops-ci-item-migration]]), with `FORGE_REPO_WRITE_TOKEN` the other
  repo-wide secret — see [[agent-workspaces]] §Isolation. `main` is
  additionally branch-protected (push + merge whitelisted to `eblume`).
  **The same recipe applies to every `pool: fork` repo** — today `agents`, `horkos`,
  `talos`, `cv`, and `hephaestus` as well. Each has a `talos/<repo>` fork on the forge, and the pod's
  pool checkout already has `origin` = the fork and `upstream` = canonical, so
  read-only-on-canonical is never a reason to hand a change back to a human:
  branch off `upstream/main`, push to `origin`, then
  `tea pr create --repo eblume/<repo> --base main --head talos:<branch>`.
- **Not an admin.** No org/settings/runner access. No deploy credentials.

### Credentials

The bot has one in use, in the **agents** vault, bounded to its own
collaborations:

- `talos-forgejo-token` — a Forgejo PAT, scopes `write:repository` +
  `write:issue` (tea's `pr create` needs the issue scope — PRs are issues in
  Forgejo), **minted as the `talos` user** so it can't exceed the bot's own
  repo access.
  Read by the workspace launcher via the op shim for `tea pr create` /
  `FORGEJO_TOKEN`. Rotated by `mise run forge-bot-pat-rotate`
  ([[rotate-talos-forgejo-pat]]). The bot's login password (what the mint
  rides) belongs at `op://blumeops-ci/talos-forgejo-bot/password`, out
  of the session-readable agents vault (one-time migration in the how-to,
  post-#1166). A PAT minted this way is self-bounding — the ownership is the
  guardrail, not the scope list.

### Sharing a repo with the bot

Most of Erich's repos are **private**, and the bot is a plain Forgejo user — it
gets no access by owning nothing. Both halves — the forge grant and the
workspace checkout — are declared in **one** file:

**`repos.json`** (`argocd/manifests/talos/`)

One of the repo's [[declared-state-files]]: one owner task, a `--check` that
runs weekly and on PRs, metadata only.

```json
{ "name": "myeve", "access": "write", "pool": "canonical" }
```

- `access` (`write` | `read` | `none`) is reconciled onto the forge as a
  collaborator grant by `mise run forge-reconcile`, which the
  **Forge Reconcile** workflow runs on merge to `main`.
- `pool` (`canonical` | `fork` | `none`) drives the pod's clone loop: the
  talos entrypoint (default.nix in the eblume/talos repo) fetches this file
  from blumeops `main` at pod start — a pool change reaches pods on restart,
  no image rebuild needed.
- Every pool repo also gets the forge → talos **webhook** and the **`talos`
  engagement label**, reconciled by the same task. The label is the *secondary*
  engagement edge: an issue **opened by an allowlisted creator** — Erich
  (talos' `ISSUE_CREATOR_ALLOWLIST`) or the bot itself, for cron-filed briefs —
  starts a cycle on its own, no label or assignment (verified on talos main,
  2026-09-06). The **`talos` label present + a label update** engages any
  other issue and re-engages an engaged one; on the read-only repos
  (`blumeops`, `agents`, `horkos`, `talos`) it is the only UI engagement
  path, because Forgejo's assignee dropdown only offers *write*
  collaborators and **assignment** to the bot works only where the bot has
  write (talos' `FORGE_BOT_LABEL` defaults to the bot login). A **comment**
  by anyone but the bot re-triggers a cycle on an engaged or
  allowlisted-created issue — reopening alone spawns nothing, the next
  comment does. The `no-agents` label suppresses every edge while present,
  and closed issues spawn nothing. A pool repo with the hook but without the
  label looks wired-up yet cannot be engaged from the UI by anyone but an
  allowlisted creator — that gap is how `horkos#4` sat inert until 2026-08-25.
  Labels are create-if-missing and never deleted (deleting a label strips it
  from closed issues), and label API calls need the *issue* scope the CI PAT
  lacks, so in CI the label half skips with a warning and is applied by a
  local run from gilbert — same follow-up as hook creation.
- `release_hook` (`true` | absent): release repos (`talos`, `horkos`,
  `blumeops`, `cv`) additionally get the forge → horkos **release webhook**
  (push + tag-create + pull_request) at `https://horkos.ops.eblu.me/api/webhooks/forge`,
  reconciled by the same task — the horkos publisher acts on tag creation
  today, push deliveries are accepted but inert, and pull_request deliveries
  drive the void-on-unmerged-PR-close handler (eblume/horkos#17, eblume/horkos#35).
  All release repos share **one** signing secret, the `horkos forge webhook`
  item in the blumeops vault: resolved from 1Password at creation (or
  `$HORKOS_FORGE_HOOK_SECRET`), and ESO-mounted on the horkos pod
  (`argocd/manifests/horkos/external-secret-forge-hook.yaml`). Hook creation
  is a local run from gilbert, like the talos hooks.
- `horkos_forge` (`true` | absent): flagged repos also get the
  **`horkos-forge`** bot as a **write** collaborator — the identity horkos
  dispatches approved runs as needs write on the request's origin issue to
  post the settlement comment (eblume/horkos#40). Reconciled by the same
  task (and exempt from the `PINNED_READ_ONLY` fence above: write on
  blumeops is the whole point), and `forge-reconcile --check` (run weekly
  and on same-repo PRs) asserts horkos-forge holds write on exactly the
  flagged set, is not a site admin, and keeps blumeops `main` whitelisted
  to eblume alone.

So adding a repo is: edit the file, open a PR, merge. No clicking in the forge
UI — and nothing to forget, which is the point. See [[agent-containerization]]
§"The repo pool" for what the `pool` values mean.

> **Reconcile is authoritative.** A repo *absent* from `repos.json` has its
> `talos` collaboration **removed**. The PR job runs `--check`, so any
> revocation shows up in review before the merge that applies it. Grants made
> by hand in the forge UI will be reverted on the next run.

> **Four repos are pinned read-only in code, not data.** `blumeops`, `agents`,
> `horkos`, and `talos` cannot be granted `write` no matter what `repos.json` says — the reconciler
> refuses and exits non-zero (`PINNED_READ_ONLY` in `mise-tasks/forge-reconcile`).
> Their read-only-on-canonical status is what keeps blumeops CI, and its
> deploy-credentialed Actions secrets, out of agent reach; that fence should not
> be flippable by a one-line edit to a data file in a routine-looking PR.
>
> **The reconciler also refuses write on any repo carrying Actions secrets**
> (`access: write` on a repo with a non-empty `actions/secrets` list exits
> non-zero in both `--check` and apply mode) — write on a repo means read of
> its Actions secrets, so the grant would hand the bot that repo's CI keys.

#### Why a missing grant is hard to diagnose

Forgejo returns **404, not 403**, for a private repo the caller cannot see. So a
missing collaboration is indistinguishable from a misspelled repo name: the
pod's clone loop (deliberately non-fatal, so one bad repo can't crashloop the
workspace) logs `talos: clone <repo> failed (continuing)` and the repo is
simply absent from `~/code/personal`. `timberborn-parsimony` sat documented as a
sibling checkout for three weeks while being absent for exactly this reason —
which is what motivated collapsing the two steps into one file.

If an agent reports a repo missing, check the grant before debugging the clone.
To see what the bot can currently reach, from an agent session:

```sh
curl -s --socks5-hostname localhost:1055 -H "Authorization: token $FORGEJO_TOKEN" \
  "https://forge.ops.eblu.me/api/v1/repos/search?limit=100" \
  | jq -r '.data[] | "\(.full_name)\t\(.permissions)"'
```

**Revoking** is `"access": "none"`, or deleting the entry outright. It takes
effect for new clones immediately — but the pod's PVC keeps any checkout it
already made, so also delete `~/code/personal/<repo>` in the pod if the intent
is to actually take it away.

The reconciler's *user* needs admin on the target repos — collaborator
management is repo-admin-level, which `eblume` holds as owner. The token
*scope* only needs `write:repository` (verified empirically 2026-08-22; an
older note here claimed such a token 403s, which is no longer true). In CI
that arrives as the `FORGE_REPO_WRITE_TOKEN` Actions secret — an `eblume` PAT
scoped to `write:repository,read:user` (the `read:user` half is for
`forge-reconcile`'s site-admin check; 1Password item
`forge-repo-write-token`, replacing the all-scopes admin PAT that previously
sat in CI) — declared in `forge/actions-secrets.json` and pushed by the
values half of `mise run forge-reconcile`, run by a human from gilbert:

```fish
mise run forge-reconcile
```

Locally the task falls back to `op read` on that same 1Password item.

The reconciler deliberately avoids `/api/v1/user*` (those need the `read:user`
scope, which a repo-scoped PAT may not carry) and enumerates via
`/api/v1/repos/search` instead. It also reads **only** `$FORGE_REPO_WRITE_TOKEN`,
never `$FORGEJO_TOKEN`: the indri runner is host-mode, so jobs inherit
`erichblume`'s LaunchAgent environment, and an earlier version silently picked
up a token the workflow never passed it.

> **Why a Forgejo secret and not `op` in CI.** The vault split is the boundary:
> the `agents` vault is the agent's, the **blumeops** vault is privileged and a
> human is meant to be part of any decision to use it. Forgejo Actions secrets
> are the curated subset that crosses that line, and `provision-indri` — run
> from gilbert under biometric `op` — is the human step that moves them. Giving
> a runner a blumeops-vault service account would erase exactly that gate, since
> 1Password service accounts scope per *vault*, not per item.

### Rotating the key

The live credential is the Forgejo PAT at
`op://agents/talos-forgejo-token/api-token`, rotated by
`mise run forge-bot-pat-rotate` ([[rotate-talos-forgejo-pat]]): mint → prove →
vault write → roll the talos pods → revoke, fail-safe so the old token stays
live until the new one is proven and the pods rolled. The warrant-gated CI
path is the dispatch-only priv workflow `.forgejo/workflows/forge-bot-pat-rotate.yaml`;
the script is the single ceremony both paths use.

There is no host SSH key to rotate — the keypair was retired in Oct 2026
(eblume/blumeops#1635). Its former home, the **`agents-forgejo-bot` secure
note** (fields `private key` / `public key`), was **archived** and can be
recovered; it is not the same item as the live **`talos-forgejo-bot` login**
in the same vault. The bot authenticates over HTTPS with its Forgejo token.

## Related

- [[cli-agent-forgejo-principal]] — the second instance of the fork-model
  pattern (interactive CLI agent sessions)
- [[horkos]] — the service `horkos-forge` dispatches for
- [[agent-workspaces]] — what uses the talos bot identity
- [[bootstrap-agent-workspaces]] — first-time creation steps
- [[warrant-approval-gated-runs]] — the program whose gate this scheme names
- [[forgejo]] — the forge
