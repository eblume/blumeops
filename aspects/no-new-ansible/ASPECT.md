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

**Scope.** No `APPLIES_TO`: the check scans `<root>/ansible/`, so it applies
to every repo — a repo without one reports no violations. The stale-entry
guard compares against this blumeops baseline, so a repo that never had
`ansible/` fails the scan on the full baseline; the V5-33 sweep must scope
ratchet baselines per repo before running it on other repos. The fixture
trees live under `aspects/`, outside the scanned `ansible/`, so the repo
scan never sees this aspect's own fixtures.

The pilot's original plan inventoried three shapes (role dirs, task files,
`files/` content); the agreed definition is the stricter whole-tree ratchet
above. `ansible-lint` lints `ansible/` in prek but never blocks *new*
ansible — this aspect adds that dimension.
