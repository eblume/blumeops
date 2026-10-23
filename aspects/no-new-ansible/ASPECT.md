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

**Scope.** `APPLIES_TO = ["eblume/blumeops"]`: the baseline describes
blumeops' `ansible/` tree, so the check applies only there — V5-33 can
widen it with per-repo baselines. The fixture trees live under `aspects/`,
outside the scanned `ansible/`, so the repo scan never sees this aspect's
own fixtures.

The pilot's original plan inventoried three shapes (role dirs, task files,
`files/` content); the agreed definition is the stricter whole-tree ratchet
above. `ansible-lint` lints `ansible/` in prek but never blocks *new*
ansible — this aspect adds that dimension.
