"""Shared loading of `mise-tasks/request-run` for the repo-tooling suite.

Run via `mise run horkos-test`. (The service's own suite moved to the
eblume/horkos repo with the extraction; only the client tooling is tested
here.) Exposed as a fixture rather than an importable helper — a habit kept
from the two-conftest era, and still the collision-proof shape.
"""

import importlib.machinery
import importlib.util
import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent


@pytest.fixture(scope="session")
def request_run():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "request_run", str(ROOT / "mise-tasks" / "request-run")
    )
    spec = importlib.util.spec_from_loader("request_run", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class _NoFetchPopen(subprocess.Popen):
    def __init__(self, args, *a, **kw):
        if _is_git_fetch(args):
            raise AssertionError(f"tests must stub the fetch: {args!r}")
        super().__init__(args, *a, **kw)


def _is_git_fetch(args) -> bool:
    return (
        isinstance(args, (list, tuple))
        and bool(args)
        and args[0] == "git"
        and "fetch" in args
    )


@pytest.fixture(autouse=True)
def _forbid_real_git_fetch(monkeypatch):
    """Fail any test that issues a real `git fetch` instead of stubbing it."""
    monkeypatch.setattr(subprocess, "Popen", _NoFetchPopen)
