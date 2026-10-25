"""spork-create: the mirror-sync job must target a declared, ungated runner label.

The rendered workflow's `runs-on` is a literal label. A label no registered
runner advertises queues the daily sync forever; a label gated by
forge-reconcile's privileged-label policy is refused for every spork repo.
"""

import importlib.machinery
import importlib.util
import json
import pathlib

import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load(name, path):
    """mise tasks are extensionless, so name the loader explicitly."""
    loader = importlib.machinery.SourceFileLoader(name, str(ROOT / "mise-tasks" / path))
    spec = importlib.util.spec_from_loader(name, loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


sc = _load("spork_create", "spork-create")
ara = _load("agent_repo_access", "forge-reconcile")


def test_mirror_sync_runs_on_a_declared_ungated_label():
    runners = json.loads((ROOT / "forge" / "runners.json").read_text())["runners"]
    workflow = yaml.safe_load(sc.mirror_sync_workflow("main", "example"))
    label = workflow["jobs"]["sync"]["runs-on"]

    assert any(label in r["labels"] for r in runners), (
        f"no runner in forge/runners.json advertises {label!r}"
    )
    gated = ara.derive_privileged_label_policy(runners)
    assert label.partition(":")[0] not in gated, (
        f"{label!r} is repo-gated; a spork repo would be refused by forge-reconcile"
    )
