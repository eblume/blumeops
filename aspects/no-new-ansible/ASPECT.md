# no-new-ansible

Ratchet: no new Ansible. Ansible is being retired (V5-83 removes it), so the
`ansible/` tree may only shrink — this aspect fails on *any* new file under
`ansible/` until a human decides otherwise.

Every file under `ansible/` is a violation; `baseline.json` is today's tree
(50 files), so edits to existing files pass and only new files fail — a new
playbook, a new role, or new templates, handlers, defaults, vars or `files/`
content bolted onto an existing role. As V5-83 removes ansible, its lines are
deleted from the baseline; the runner fails on stale entries, so the list may
only shrink. The green fixture is the end-state of the retirement: a
baseline-shaped `ansible/` tree — playbooks and inventory glue, no roles.

**Scope.** The aspect runs in every managed repo (no `APPLIES_TO`). The baseline is per repo: `baseline.json` maps `owner/name` to that repo's `ansible/` tree — blumeops is today's tree (50 files); every other repo has an empty baseline, so any file under its `ansible/` is a violation. The fixture trees live under `aspects/`,
outside the scanned `ansible/`, so the repo scan never sees this aspect's
own fixtures.

## Authoring-time cross-repo run

Before merge, a new or changed aspect is run once against every managed repo from gilbert, and the result is recorded here.

Result: not yet recorded. Run from gilbert against every managed repo before the aspect's first merge.

Command, once per managed repo in `forge/repos.json`:

```bash
mise run aspects --repo <checkout-of-repo> --repo-name <owner/name> -- -k test_aspect_on_target_repo
```

The pilot's original plan inventoried three shapes (role dirs, task files,
`files/` content); the agreed definition is the stricter whole-tree ratchet
above. `ansible-lint` lints `ansible/` in prek but never blocks *new*
ansible — this aspect adds that dimension.
