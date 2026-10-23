"""Wiring for the aspect suite: the --repo/--repo-name options and the
aspect/target parametrization. The contract itself is in aspects/runner.py.

Discovery and target resolution are cached in a module-level state (rather
than stored on pytest's Config) so the suite's own type checker sees a
stable shape.
"""

from __future__ import annotations

import pytest

from aspects.runner import Aspect, Target, discover_aspects, resolve_target


class _State:
    aspects: list[Aspect] | None = None
    target: Target | None = None


_STATE = _State()


def _aspects() -> list[Aspect]:
    aspects = _STATE.aspects
    if aspects is None:
        aspects = discover_aspects()
        _STATE.aspects = aspects
    return aspects


def _target(config: pytest.Config) -> Target:
    target = _STATE.target
    if target is None:
        target = resolve_target(
            config.getoption("--repo"), config.getoption("--repo-name")
        )
        _STATE.target = target
    return target


def pytest_addoption(parser: pytest.Parser) -> None:
    group = parser.getgroup("aspects")
    group.addoption(
        "--repo",
        default=None,
        metavar="PATH",
        help="target repo root for the repo scan (default: this blumeops checkout)",
    )
    group.addoption(
        "--repo-name",
        default=None,
        metavar="OWNER/NAME",
        help="override the target repo identity (default: parsed from remote.origin.url)",
    )


def pytest_generate_tests(metafunc: pytest.Metafunc) -> None:
    if "aspect" in metafunc.fixturenames:
        metafunc.parametrize("aspect", _aspects(), ids=lambda a: a.slug)
    if "target" in metafunc.fixturenames:
        target = _target(metafunc.config)
        metafunc.parametrize("target", [target], ids=[target.identity])
