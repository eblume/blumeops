---
title: Retire a Repo
modified: 2026-11-15
last-reviewed: 2026-11-15
tags:
  - how-to
  - operations
  - ai
---

# Retire a Repo

How to take a repo out of the bot's reach when you archive it, delete it, or
fold it into another repo. For the repo classes, see [[freestanding-repos]].
For the access model, see [[principals]]. Adding a repo is in
[[add-a-freestanding-repo]].

The source of truth is `forge/repos.json`. Reconcile is authoritative: do not
hand-click grants, hooks or collaborators in the forge UI. Each step names its
actor.

## Which case are you in?

| Case | `forge/repos.json` before | Blumeops PR |
|---|---|---|
| Archive a repo already in `excluded` | `excluded` | None. Keep the entry. |
| Archive a managed repo | `repos` | Move it to `excluded`, merge, then archive. |
| Delete a repo | `repos` or `excluded` | Move it to `excluded` first if it is managed. Pruning the name is optional. |
| Fold one repo into another | Either | Use the source's row above, plus the fold checklist. |

## Archiving a repo already in `excluded`

Nothing to change in blumeops. Keep the `excluded` entry. Removing it makes
`forge-reconcile --check` fail, because the repo is an eblume non-fork repo in
neither list.

Observed: `eblume/tow-game` was archived on 2026-11-14 while in `excluded`. The
nightly Forge Reconcile run that night was green, and the bot's collaborator
grant on it read as 404.

## Archiving a managed repo

Order matters. On merge, reconcile revokes grants and deletes hooks on the
repo. Whether Forgejo accepts those writes on an archived repo is **untested**.
So the order below makes sure nothing writes to the repo after it is archived.

1. **(Agent)** Blumeops PR: move the repo's entry from `repos` to top-level
   `excluded`. Drop its per-repo `horkos_forge`, `release_hook` and `principals`
   fields with it. Keep the name in `excluded`, so the coverage check still
   passes.
2. **(Erich)** Merge the PR. Forge Reconcile runs on merge to `main` and:
   - revokes the `talos` collaborator grant, the `horkos-forge` grant, and any
     per-repo principal grant such as `cli-agent`;
   - deletes the forge → talos and forge → horkos webhooks;
   - leaves the `talos/<repo>` fork and the `talos` label alone. Reconcile
     never deletes forks or labels.

   Check that the merge-commit run is green. Erich can also run
   `mise run forge-reconcile --check` from gilbert, which should be clean.
3. **(Erich)** Archive the repo in the forge. Once the repo has left `repos`,
   reconcile no longer writes to it.
4. **(Erich, optional)** Decide the fork. Reconcile does not touch
   `talos/<repo>`. Once the repo is out of `repos`, the pool stops cloning it,
   so a leftover fork is inert. Delete it by hand if you want it gone.

The pool drops the repo on the next pod start: the `repos.json` ConfigMap
changes and the pods roll. Checkouts already on a pod's PVC are kept. Delete
them by hand if the intent is to take the code away (see the **Revoking**
paragraph in [[principals]]).

## Deleting a repo

1. If the repo is managed, do the first two steps of the archive case so it
   sits in `excluded` before the delete. A managed name whose repo is gone
   makes reconcile exit 1 before it plans anything, so it blocks every repo's
   reconcile, not just that one.
2. **(Erich)** Delete the repo in the forge.
3. Leave the stale name in `excluded`. Reconcile does not check that excluded
   names exist on the forge, and its coverage check only looks at live repos,
   so the stale name is tolerated. Prune it in a later blumeops PR if you want
   the list tidy.

   *Untested:* a live reconcile run after deleting an excluded repo. The
   tolerance comes from reading `mise-tasks/forge-reconcile`, not from running
   it.

## Folding one repo into another

1. Move the content into the destination repo (for example `tow-game/` into
   `eblume/gamedev`).
2. Retire the source: an archive case above, depending on whether it is
   managed.
3. If the source is listed in `fly/git-mirror/repos`, remove it. That file is
   the public mirror allowlist (see `fly/git-mirror/README.md`).
4. Remove your local clones of the source on workstations. In pods, the pool
   stops refreshing the source; delete any kept checkout as in the archive
   case.
5. No new `repos.json` entry is needed. The pod pool clones only managed
   repos, so the content reaches pods only through the destination repo, which
   must already be managed and must hold the moved content.
6. Update links that name the source (docs, `AGENTS.md`), in the same PR as
   step 2 or after it.

## See also

- [[freestanding-repos]] — what the class is
- [[add-a-freestanding-repo]] — the creation procedure
- [[principals]] — the reconciler and the engagement model
