"""verify-runs must not close an approval that a run didn't honour.

The audit compares the warrant record against *itself* — the bound `sha` versus
the `inputs` actually dispatched. It deliberately does NOT compare the run's
`head_sha`: a dispatched run's head_sha is main's tip at dispatch time, not the
payload, so that comparison would fail every honest approval filed before main
moved on. That was the bug PR #523 fixed by recording attribution instead of
inferring it, and `match_run` still carries the warning.

test_the_bug_case is the regression that matters: warrant #22, bound to
bcb2b55, dispatched with no `ref` at all, built main, and reported success.
"""

import importlib.machinery
import importlib.util
import json
import pathlib

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
BINDINGS = {"build-container.yaml": "ref", "deploy-fly.yaml": "revision"}
SHA = "bcb2b55" + "0" * 33
MAIN_TIP = "1cb0a61" + "0" * 33


def _load(name: str):
    loader = importlib.machinery.SourceFileLoader(
        name.replace("-", "_"), str(ROOT / "mise-tasks" / name)
    )
    spec = importlib.util.spec_from_loader(name.replace("-", "_"), loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


verify_runs = _load("verify-runs")


def rec(action: str, sha: str, inputs: dict) -> dict:
    """A row as GET /api/requests returns it — `inputs` is the raw JSON text
    of the DB column, not a decoded dict."""
    return {"action": action, "sha": sha, "inputs": json.dumps(inputs)}


def test_the_bug_case_missing_binding_input():
    """warrant #22 / run 742: no `ref`, so CI checked out main and succeeded."""
    why = verify_runs.binding_mismatch(
        rec("build-container.yaml", SHA, {"container": "talos"}), BINDINGS
    )
    assert why is not None
    assert "no 'ref' input" in why


def test_matching_binding_is_clean():
    assert (
        verify_runs.binding_mismatch(
            rec("build-container.yaml", SHA, {"container": "talos", "ref": SHA}),
            BINDINGS,
        )
        is None
    )


def test_wrong_sha_in_binding_input():
    why = verify_runs.binding_mismatch(
        rec("deploy-fly.yaml", SHA, {"revision": MAIN_TIP}), BINDINGS
    )
    assert why is not None and "bcb2b55" in why


def test_head_sha_is_never_consulted():
    """The record alone decides. A run whose head_sha differs from the bound
    SHA is normal — main moves on between filing and dispatch."""
    clean = rec("deploy-fly.yaml", SHA, {"revision": SHA})
    clean["head_sha"] = MAIN_TIP  # what the forge would report for the run
    assert verify_runs.binding_mismatch(clean, BINDINGS) is None


def test_action_with_no_declared_binding_is_clean():
    assert (
        verify_runs.binding_mismatch(rec("some-unpoliced.yaml", SHA, {}), BINDINGS)
        is None
    )


@pytest.mark.parametrize(
    "wrec",
    [
        {"action": "build-container.yaml", "sha": SHA, "inputs": "not json"},
        {"action": "build-container.yaml", "sha": SHA},  # no inputs at all
    ],
)
def test_unreadable_records_are_reported_not_waved_through(wrec):
    """A row the audit cannot parse must not close its task. Closing something
    you failed to check is the failure mode this whole sweep exists to avoid —
    and it must report rather than raise, so one bad row cannot block the
    other tasks behind an exception."""
    why = verify_runs.binding_mismatch(wrec, BINDINGS)
    assert why is not None and "cannot be verified" in why


def test_empty_policy_disables_the_audit():
    """An unreadable warrant-policy degrades to no audit, never to a false
    mismatch on every task."""
    assert (
        verify_runs.binding_mismatch(
            rec("build-container.yaml", SHA, {"container": "talos"}), {}
        )
        is None
    )
