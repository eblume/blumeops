"""The fragment-hook-wired invariant: CI runs prek, and towncrier repos wire the
changelog-fragment hook.

A comment mentioning prek does not count as running it.
"""

from __future__ import annotations

import pathlib
import re
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


def _workflow_lines(root: pathlib.Path) -> list[str]:
    workflows = root / ".forgejo" / "workflows"
    if not workflows.is_dir():
        return []
    files = [*workflows.glob("*.yaml"), *workflows.glob("*.yml")]
    return [
        line
        for path in files
        for line in (_code(raw) for raw in path.read_text().splitlines())
        if line
    ]


def _code(line: str) -> str:
    # A YAML comment starts at a `#` preceded by whitespace (or at column 0).
    return re.split(r"(?:^|\s)#", line, maxsplit=1)[0].strip()


def _ci_runs_prek(root: pathlib.Path) -> bool:
    return any("prek run" in line for line in _workflow_lines(root))


def _ci_runs_fragment_check(root: pathlib.Path) -> bool:
    # prek run --all-files skips pre-push hooks, so the fragment check needs its
    # own CI line: the hook at its stage, or the shared check called directly.
    return any(
        (
            "prek run" in line
            and "changelog-fragment" in line
            and re.search(r"--stage[= ]pre-push", line)
        )
        or ("changelog-check" in line and "--branch" in line)
        for line in _workflow_lines(root)
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
    if _is_towncrier(root):
        if not _has_changelog_fragment_hook(root):
            violations.append(
                "towncrier repo does not wire the changelog-fragment hook in prek.toml"
            )
        if not _ci_runs_fragment_check(root):
            violations.append(
                "towncrier repo has no CI job running the fragment check: no "
                "workflow line runs `prek run ... changelog-fragment ... pre-push` "
                "or `changelog-check --branch`"
            )
    return violations
