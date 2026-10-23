"""The aspect-suite runner contract (docs/explanation/talos-v0.5/aspects.md).

Each ``aspects/<slug>/`` directory is one aspect: a Python package whose
``test_*.py`` module exposes

- ``KIND``: ``"invariant"`` (zero violations in scope) or ``"ratchet"``
  (violations may only be a subset of ``baseline.json``),
- ``check(root: pathlib.Path) -> list[str]``: the violations, as strings,
- optionally ``APPLIES_TO``: ``list[str]`` of ``"owner/name"`` repos;
  absent means every repo.

Fixtures: each immediate subdirectory of ``fixtures/red/`` is a case whose
directory is passed to ``check()`` and must be rejected (non-empty result);
each under ``fixtures/green/`` must be accepted (empty result).

Budgets: 10 s per test (pytest-timeout) and 120 s wall clock per repo run
(mise-tasks/aspects).

Checks scope themselves: fixtures live under aspects/<slug>/ inside the
target repo, so an aspect that applies to blumeops must restrict its scan
to paths outside its own fixture tree (or use APPLIES_TO).
"""

from __future__ import annotations

import importlib.util
import json
import pathlib
import re
import subprocess
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

ASPECTS_DIR = pathlib.Path(__file__).resolve().parent
REPO_ROOT = ASPECTS_DIR.parent
KINDS = ("invariant", "ratchet")


@dataclass(frozen=True)
class Aspect:
    slug: str
    kind: str
    applies_to: tuple[str, ...] | None
    check: Callable[[pathlib.Path], list[str]]
    dir: pathlib.Path
    baseline: tuple[str, ...]


@dataclass(frozen=True)
class Target:
    root: pathlib.Path
    identity: str


def _load_test_modules(slug: str, directory: pathlib.Path) -> list[Any]:
    modules = []
    for path in sorted(directory.glob("test_*.py")):
        spec = importlib.util.spec_from_file_location(
            f"aspects.{slug}.{path.stem}", path
        )
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        modules.append(module)
    return modules


def discover_aspects() -> list[Aspect]:
    aspects: list[Aspect] = []
    for directory in sorted(ASPECTS_DIR.iterdir()):
        if not directory.is_dir() or directory.name.startswith((".", "_")):
            continue
        if not (directory / "ASPECT.md").is_file():
            continue
        if not (directory / "__init__.py").is_file():
            raise ValueError(
                f"aspect {directory.name}: missing __init__.py — aspect dirs are Python packages, so test module "
                "names stay unique under pytest's prepend import mode"
            )
        checking = [
            m
            for m in _load_test_modules(directory.name, directory)
            if callable(getattr(m, "check", None))
        ]
        if len(checking) != 1:
            names = ", ".join(m.__name__ for m in checking) or "none"
            raise ValueError(
                f"aspect {directory.name}: exactly one test_*.py module must define check(root); found: {names}"
            )
        module = checking[0]
        kind = getattr(module, "KIND", None)
        if kind not in KINDS:
            raise ValueError(
                f"aspect {directory.name}: KIND must be one of {KINDS}, got {kind!r}"
            )
        applies_to = getattr(module, "APPLIES_TO", None)
        if applies_to is not None:
            applies_to = tuple(applies_to)
            if not all(
                isinstance(r, str) and re.fullmatch(r"[\w.-]+/[\w.-]+", r)
                for r in applies_to
            ):
                raise ValueError(
                    f"aspect {directory.name}: APPLIES_TO entries must look like 'owner/name'"
                )
        baseline_path = directory / "baseline.json"
        if kind == "ratchet" and not baseline_path.is_file():
            raise ValueError(
                f"aspect {directory.name}: ratchet kind requires baseline.json"
            )
        baseline: tuple[str, ...] = ()
        if kind == "ratchet":
            try:
                loaded = json.loads(baseline_path.read_text())
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"aspect {directory.name}: baseline.json is not valid JSON: {exc}"
                ) from exc
            if not isinstance(loaded, list) or not all(
                isinstance(v, str) for v in loaded
            ):
                raise ValueError(
                    f"aspect {directory.name}: baseline.json must be a JSON list of strings"
                )
            baseline = tuple(loaded)
        aspects.append(
            Aspect(directory.name, kind, applies_to, module.check, directory, baseline)
        )
    return aspects


def repo_identity(root: pathlib.Path, override: str | None = None) -> str:
    if override:
        return override
    try:
        url = subprocess.run(
            ["git", "config", "--get", "remote.origin.url"],
            cwd=root,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (subprocess.CalledProcessError, OSError):
        return root.name
    tail = re.sub(r"^.*[/:]", "", url.removesuffix(".git").removesuffix("/"))
    parts = tail.split("/")
    if len(parts) == 2 and all(parts):
        return "/".join(parts)
    return root.name


def resolve_target(repo: str | None, repo_name: str | None) -> Target:
    root = pathlib.Path(repo).expanduser().resolve() if repo else REPO_ROOT
    if not root.is_dir():
        raise ValueError(f"--repo path is not a directory: {root}")
    return Target(root, repo_identity(root, repo_name))


def applies_to_repo(aspect: Aspect, identity: str) -> bool:
    return aspect.applies_to is None or identity in aspect.applies_to


def violations_for(aspect: Aspect, root: pathlib.Path) -> list[str]:
    violations = aspect.check(root)
    if not isinstance(violations, list) or not all(
        isinstance(v, str) for v in violations
    ):
        raise ValueError(
            f"aspect {aspect.slug}: check() must return list[str], got {type(violations).__name__}"
        )
    return violations


def assert_kind_holds(aspect: Aspect, root: pathlib.Path) -> None:
    violations = violations_for(aspect, root)
    if aspect.kind == "invariant":
        assert not violations, (
            f"{aspect.slug}: invariant violated in {root}:\n" + "\n".join(violations)
        )
        return
    new = [v for v in violations if v not in set(aspect.baseline)]
    assert not new, (
        f"{aspect.slug}: new violations not in baseline.json:\n" + "\n".join(new)
    )


def fixture_cases(aspect: Aspect, color: str) -> list[pathlib.Path]:
    fixtures = aspect.dir / "fixtures" / color
    if not fixtures.is_dir():
        return []
    return sorted(p for p in fixtures.iterdir() if p.is_dir())
