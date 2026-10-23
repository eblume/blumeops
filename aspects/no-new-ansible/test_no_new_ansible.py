"""The no-new-ansible ratchet: the ansible/ tree may only shrink.

Ansible is being retired (V5-83 removes it role by role). This aspect counts
*new* ansible on every PR so the tree can only get smaller.

Three shapes are inventoried, each an inventoried path:

- role directories: ``ansible/roles/<role>/``
- task files: ``ansible/roles/<role>/tasks/<file>``
- content files: any file directly inside a ``files/`` directory under
  ``ansible/``

Each inventoried path is a violation; ``baseline.json`` holds today's tree,
so edits to existing files pass and only new roles, task files and files/
content fail. As V5-83 removes ansible, its lines are deleted from the
baseline — the list may only shrink.
"""

from __future__ import annotations

import pathlib

KIND = "ratchet"


def check(root: pathlib.Path) -> list[str]:
    ansible = root / "ansible"
    if not ansible.is_dir():
        return []
    violations: list[str] = []
    roles = ansible / "roles"
    if roles.is_dir():
        violations += [
            f"ansible/roles/{p.name}" for p in sorted(roles.iterdir()) if p.is_dir()
        ]
    for p in sorted(ansible.glob("roles/*/tasks/*")):
        if p.is_file():
            violations.append(str(p.relative_to(root)))
    for p in sorted(ansible.glob("**/files/*")):
        if p.is_file():
            violations.append(str(p.relative_to(root)))
    return violations
