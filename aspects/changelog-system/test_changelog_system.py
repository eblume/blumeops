"""The changelog-system invariant: every managed repo has a changelog system.

Accepted: root towncrier.toml, a [tool.towncrier] table in pyproject.toml, or a
release-notes/ directory (talos and horkos).
"""

from __future__ import annotations

import pathlib
import tomllib

KIND = "invariant"


def _has_towncrier_table(root: pathlib.Path) -> bool:
    pyproject = root / "pyproject.toml"
    if not pyproject.is_file():
        return False
    try:
        data = tomllib.loads(pyproject.read_text())
    except tomllib.TOMLDecodeError:
        return False
    return "towncrier" in data.get("tool", {})


def check(root: pathlib.Path) -> list[str]:
    if (root / "towncrier.toml").is_file() or (root / "release-notes").is_dir():
        return []
    if _has_towncrier_table(root):
        return []
    return [
        (
            "no changelog system: expected towncrier.toml, a [tool.towncrier] table in "
            "pyproject.toml, or a release-notes/ directory"
        )
    ]
