"""horkos-forge-provision: the minted PAT's scope list is the boundary.

A narrowing here fails only live, at the first settlement comment (forge
scopes the issue routes to the issue token category, so `write:issue` is
load-bearing) — pin the constant in CI.
"""

import importlib.machinery
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "horkos_forge_provision", str(ROOT / "mise-tasks" / "horkos-forge-provision")
    )
    spec = importlib.util.spec_from_loader("horkos_forge_provision", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


hfp = _load()


def test_token_scopes_cover_dispatch_and_issue_comments():
    assert hfp.TOKEN_SCOPES == ["write:repository", "write:issue"]
