"""The nix half of the action-trust rule (forge/action-trust.nix).

forge/action-trust.nix and `derive_action_trust_policy` in
mise-tasks/forge-reconcile must derive the same (collaborator, repos) pair
from the shared fixture and the live declared files.
"""

import importlib.machinery
import importlib.util
import json
import os
import pathlib
import shutil
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
FIX = ROOT / "tests" / "fixtures" / "action-trust"
MODULE = ROOT / "forge" / "action-trust.nix"


def _load_ara():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one (mirrors tests/test_forge_reconcile.py)."""
    loader = importlib.machinery.SourceFileLoader(
        "agent_repo_access", str(ROOT / "mise-tasks" / "forge-reconcile")
    )
    spec = importlib.util.spec_from_loader("agent_repo_access", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


def _eval_nix(repos_file, runners_file) -> dict:
    if shutil.which("nix") is None:
        if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS"):
            pytest.fail("nix is not on PATH — the indri-build CI runner provides it")
        pytest.skip("nix is not on PATH")
    expr = (
        f"builtins.toJSON (import {MODULE} "
        f'{{ reposFile = "{repos_file}"; runnersFile = "{runners_file}"; }})'
    )
    proc = subprocess.run(
        ["nix", "eval", "--impure", "--raw", "--expr", expr],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(proc.stdout)


def test_nix_action_trust_fixture_matches_expected():
    assert _eval_nix(FIX / "repos.json", FIX / "runners.json") == json.loads(
        (FIX / "expected.json").read_text()
    )


def test_nix_action_trust_matches_python_on_live_files():
    repos_file = ROOT / "argocd" / "manifests" / "talos" / "repos.json"
    runners_file = ROOT / "forge" / "runners.json"
    actual = _eval_nix(repos_file, runners_file)
    ara = _load_ara()
    expected_collab, expected_repos = ara.derive_action_trust_policy(
        json.loads(repos_file.read_text()),
        json.loads(runners_file.read_text())["runners"],
    )
    assert actual == {
        "collaborator": expected_collab,
        "repos": sorted(expected_repos),
    }
