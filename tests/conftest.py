"""Shared loading of `mise-tasks/request-run` for the repo-tooling suite.

Run via `mise run horkos-test`. (The service's own suite moved to the
eblume/horkos repo with the extraction; only the client tooling is tested
here.) Exposed as a fixture rather than an importable helper — a habit kept
from the two-conftest era, and still the collision-proof shape.
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
