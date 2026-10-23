"""The no-new-ansible ratchet: the ansible/ tree may only shrink.

Ansible is being retired (V5-83 removes it). This aspect counts *new*
ansible on every PR so the tree can only get smaller.

Every file under ``ansible/`` is a violation; ``baseline.json`` holds
today's tree, so edits to existing files pass and any new file — a
playbook, a new role, or new templates, handlers, defaults, vars or
files/ content bolted onto an existing role — fails. As V5-83 removes
ansible, its lines are deleted from the baseline; the runner fails on
stale entries, so the list may only shrink.
"""

from __future__ import annotations

import pathlib

KIND = "ratchet"
APPLIES_TO = ["eblume/blumeops"]


def check(root: pathlib.Path) -> list[str]:
    ansible = root / "ansible"
    if not ansible.is_dir():
        return []
    return [str(p.relative_to(root)) for p in sorted(ansible.rglob("*")) if p.is_file()]
