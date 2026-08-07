"""Shared loading of `mise-tasks/request-run` for the repo-tooling suite.

Exposed as a fixture rather than an importable helper on purpose: `mise run
warrant-test` runs this directory alongside `containers/warrant/tests`, which
has a conftest of its own, so both dirs land on `sys.path` and a plain
`from conftest import …` would resolve to whichever came first. Fixtures are
scoped per directory by pytest and cannot collide that way.
"""

import importlib.machinery
import importlib.util
import pathlib

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
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module
