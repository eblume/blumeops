"""The fragment-hook-wired invariant: CI runs prek, and towncrier repos wire the
changelog-fragment hook.

A comment line mentioning prek does not count as running it.
"""

from __future__ import annotations

import pathlib
import tomllib

KIND = "invariant"


def _is_towncrier(root: pathlib.Path) -> bool:
    if (root / "towncrier.toml").is_file():
        return True
    pyproject = root / "pyproject.toml"
    if not pyproject.is_file():
        return False
    try:
        data = tomllib.loads(pyproject.read_text())
    except tomllib.TOMLDecodeError:
        return False
    return "towncrier" in data.get("tool", {})


def _ci_runs_prek(root: pathlib.Path) -> bool:
    workflows = root / ".forgejo" / "workflows"
    if not workflows.is_dir():
        return False
    files = [*workflows.glob("*.yaml"), *workflows.glob("*.yml")]
    return any(
        "prek run" in line and not line.strip().startswith("#")
        for path in files
        for line in path.read_text().splitlines()
    )


def _has_changelog_fragment_hook(root: pathlib.Path) -> bool:
    path = root / "prek.toml"
    if not path.is_file():
        return False
    try:
        data = tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError:
        return False
    return any(
        hook.get("id") == "changelog-fragment"
        for repo in data.get("repos", [])
        for hook in repo.get("hooks", [])
    )


def check(root: pathlib.Path) -> list[str]:
    violations = []
    if not _ci_runs_prek(root):
        violations.append(
            "CI does not run prek: no .forgejo/workflows/*.yaml|yml has an "
            "uncommented `prek run` line"
        )
    if _is_towncrier(root) and not _has_changelog_fragment_hook(root):
        violations.append(
            "towncrier repo does not wire the changelog-fragment hook in prek.toml"
        )
    return violations
