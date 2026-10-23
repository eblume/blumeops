# no-new-ansible

Ratchet: no new Ansible. Ansible is being retired (V5-83 removes it), so the
`ansible/` tree may only shrink — this aspect counts *new* ansible on every
PR and fails the check until a human decides otherwise.

It inventories three shapes under `ansible/`: role directories
(`ansible/roles/<role>/`), task files (`ansible/roles/<role>/tasks/*`), and
content files (any file directly inside a `files/` directory under
`ansible/`). Each inventoried path is a violation; `baseline.json` is
today's tree, so edits to existing files pass and only new roles, task
files and files/ content fail. As V5-83 removes ansible, its lines are
deleted from the baseline — the list may only shrink. The green fixture is
the end-state of the retirement: an `ansible/` tree with playbooks and
inventory glue but no roles, task files or files/ content.

**Scope.** No `APPLIES_TO`: the check scans `<root>/ansible/`, so it is a
no-op in every repo without one and applies to all of them. The fixture
trees live under `aspects/`, outside the scanned `ansible/`, so the repo
scan never sees this aspect's own fixtures.

**Alternatives rejected.** A whole-tree ratchet (every file under
`ansible/` in the baseline) was considered; the approved plan inventories
the three ansible shapes, and new non-inventoried content (templates,
defaults, handlers) stays review-visible like any other file. `ansible-lint`
lints `ansible/` in prek but never blocks *new* ansible — this aspect adds
that dimension.
