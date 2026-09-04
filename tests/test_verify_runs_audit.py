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
    if spec is None:
        raise RuntimeError("could not build an import spec")
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


# --- run attribution: warrant record vs. forge-side inference ---------------
#
# attribution() decides how an open Approve task maps to a forge run. The
# warrant record is authoritative when it exists; inference (match_run) is the
# exclusive fallback for approvals with NO warrant record. The regression that
# matters is eblume/horkos#12: request #54 was approved but never dispatched
# (warrant consumed=0, run_number=null), yet the sweep guessed run 1754 — a
# run that belonged to a different request — and reported it as a failure.
#
# run_number=null is not itself "never dispatched", though: horkos records
# three run-less shapes, and the sweep must tell them apart — status
# "dispatched" (the dispatch ran, the forge answered 204 without naming the
# run: dispatched-norun), status "dispatch_failed" (the dispatch attempt
# failed: the warrant note carries the reason), and every other status
# (approved/denied/superseded: never dispatched, with the warrant note's
# "not dispatched: {reason}" surfaced when horkos recorded one, eblume/horkos#13).

FILED_AT_MS = 1_799_107_200_000  # 2027-01-05T00:00:00Z; match_run divides by 1000


def task_row(
    workflow: str = "build-container.yaml",
    sha: str = SHA,
    pr: str = "707",
    created_at: int = FILED_AT_MS,
) -> dict:
    return {
        "workflow": workflow,
        "sha7": sha[:7],
        "pr": pr,
        "created_at": created_at,
    }


def run_row(
    run_number: int,
    workflow: str = "build-container.yaml",
    head_sha: str = SHA,
    started: str = "2027-01-05T00:30:00+00:00",
) -> dict:
    """A workflow_dispatch run the heuristic would consider: same workflow,
    matching head_sha prefix, started after the request was filed."""
    return {
        "run_number": run_number,
        "workflow_id": workflow,
        "event": "workflow_dispatch",
        "head_sha": head_sha,
        "run_started_at": started,
    }


def test_recorded_run_number_wins_over_any_heuristic():
    """The recorded link beats inference: a newer matching run must not steal
    the approval, whatever the heuristic would have picked."""
    task = task_row()
    wrec = {"status": "approved", "run_number": 1754}
    runs = [
        run_row(1800, started="2027-02-01T00:00:00+00:00"),  # newer: inference bait
        run_row(1754),
    ]
    run, via, state = verify_runs.attribution(task, 54, wrec, runs)
    assert state == "recorded"
    assert via == "recorded: warrant #54"
    assert run is not None and run["run_number"] == 1754


def test_recorded_run_outside_window_is_pending():
    """The record names a run the sweep cannot see (older than the recent-run
    window): stay pending, and never substitute a guessed run."""
    task = task_row()
    wrec = {"status": "approved", "run_number": 2}
    run, _, state = verify_runs.attribution(task, 54, wrec, [run_row(1754)])
    assert state == "recorded"
    assert run is None


def test_pending_warrant_awaits_decision_without_inference():
    """An undecided request is pending even though the heuristic could have
    matched a run — inference must not race the human's decision."""
    task = task_row()
    wrec = {"status": "pending", "run_number": None}
    run, via, state = verify_runs.attribution(task, 54, wrec, [run_row(1754)])
    assert state == "pending"
    assert run is None and via is None


def test_approved_without_run_number_is_never_dispatched():
    """The eblume/horkos#12 regression: an approved warrant with no run number
    was never dispatched — the sweep must refuse the inference (which would
    have guessed run 1754 here, exactly the misattribution audited) and report
    'never dispatched' instead."""
    task = task_row()
    wrec = {"status": "approved", "run_number": None}  # consumed=0, never dispatched
    runs = [run_row(1754)]
    run, via, state = verify_runs.attribution(task, 54, wrec, runs)
    assert state == "never"
    assert run is None and via is None
    # prove the guess was real: the heuristic WOULD have produced run 1754
    assert verify_runs.match_run(task, runs)["run_number"] == 1754


def test_denied_without_run_number_is_never_dispatched_too():
    """Denials close the request and never dispatch; the same refusal applies —
    a denied request must not close against some unrelated run either."""
    task = task_row()
    wrec = {"status": "denied", "run_number": None}
    run, _, state = verify_runs.attribution(task, 54, wrec, [run_row(1754)])
    assert state == "never"
    assert run is None


def test_dispatched_without_run_number_is_dispatched_norun():
    """Status 'dispatched' with no run_number is NOT 'never dispatched': the
    dispatch ran and the forge answered 204 without naming the run (a
    pre-return_run_info forge / deaf forge). Labelling that 'never' inverts
    the truth. Inference stays refused even though a matching run exists — a
    human links or re-dispatches."""
    task = task_row()
    wrec = {"status": "dispatched", "run_number": None}
    runs = [run_row(1754)]
    run, via, state = verify_runs.attribution(task, 54, wrec, runs)
    assert state == "dispatched-norun"
    assert run is None and via is None
    # prove the guess was real: the heuristic WOULD have produced run 1754
    assert verify_runs.match_run(task, runs)["run_number"] == 1754


def test_dispatch_failed_is_reported_not_attributed():
    """A failed dispatch attempt is terminal — the request must not close
    against some later run, and the sweep must say the attempt failed."""
    task = task_row()
    wrec = {"status": "dispatch_failed", "run_number": None}
    run, via, state = verify_runs.attribution(task, 54, wrec, [run_row(1754)])
    assert state == "dispatch_failed"
    assert run is None and via is None


def test_never_dispatched_surfaces_noop_reason_from_note():
    """horkos appends ' | not dispatched: {reason}' to the warrant note on
    every pre-dispatch no-op (eblume/horkos#13) — that reason is exactly the
    information this audit exists to surface."""
    task = task_row()
    wrec = {
        "status": "approved",
        "run_number": None,
        "note": "Approved — go | not dispatched: no forge dispatch token configured",
    }
    run, _, state = verify_runs.attribution(task, 54, wrec, [run_row(1754)])
    assert state == "never"
    assert run is None
    assert (
        verify_runs.not_dispatched_reason(wrec["note"])
        == "no forge dispatch token configured"
    )


def test_never_dispatched_without_reason_stays_plain():
    """A run-less approved warrant whose note records no no-op (pre-#13)
    still reports 'never' — with no reason to surface."""
    task = task_row()
    wrec = {"status": "approved", "run_number": None, "note": ""}
    run, _, state = verify_runs.attribution(task, 54, wrec, [run_row(1754)])
    assert state == "never"
    assert run is None
    assert verify_runs.not_dispatched_reason(wrec["note"]) is None


@pytest.mark.parametrize(
    ("note", "reason"),
    [
        (" | not dispatched: warrant expired", "warrant expired"),
        (
            "approved by erich | not dispatched: no forge dispatch token configured",
            "no forge dispatch token configured",
        ),
        (
            " | not dispatched: disk quota | not dispatched: warrant expired",
            "warrant expired",
        ),
        (" | dispatch FAILED: 500: boom", None),  # the other family, not a no-op
        ("", None),
        (None, None),
    ],
)
def test_not_dispatched_reason_extraction(note, reason):
    assert verify_runs.not_dispatched_reason(note) == reason


@pytest.mark.parametrize(
    ("note", "detail"),
    [
        (
            "approved by erich | dispatch FAILED: 500: Internal Server Error",
            "500: Internal Server Error",
        ),
        (
            " | dispatch FAILED: ConnectError: connection refused",
            "ConnectError: connection refused",
        ),
        (" | not dispatched: dispatch disarmed", None),  # the other family
        ("", None),
        (None, None),
    ],
)
def test_dispatch_failed_detail_extraction(note, detail):
    assert verify_runs.dispatch_failed_detail(note) == detail


def test_no_warrant_record_still_uses_inference():
    """Pre-stamp tasks and warrant outages have no record at all — the
    forge-side heuristic stays, marked as inferred. Unchanged behavior."""
    task = task_row()
    run, via, state = verify_runs.attribution(task, None, None, [run_row(1754)])
    assert state == "inferred"
    assert via == "inferred: newest dispatch after filing"
    assert run is not None and run["run_number"] == 1754


def test_no_warrant_record_and_nothing_matching_is_pending():
    task = task_row(workflow="run-script.yaml", sha=SHA)
    run, via, state = verify_runs.attribution(
        task, None, None, [run_row(1, workflow="build-container.yaml")]
    )
    assert state == "inferred"
    assert run is None
    assert via == "inferred: newest dispatch after filing"


# --- the horkos fetch window and the stamped-but-missing warning -----------
#
# The two changes that close the silent-attribution hole (eblume/horkos#12's
# failure mode recurring quietly): warrant_requests must ask for the API cap
# (500, not 100), and a task whose context stamps a warrant id the (successful)
# fetch did not return must warn instead of sliding into "inferred" as if it
# had never been recorded. Behavior is unchanged — inference still runs — but
# the reversion is visible.


class _FakeProc:
    stdout = "app-pw\n"


class _FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self._payload


class _FakeOpsClient:
    """Records what warrant_requests() asks of horkos."""

    def __init__(self, requests_payload):
        self._requests_payload = requests_payload
        self.get_kwargs = {}

    def post(self, url, **kwargs):
        return _FakeResponse({"access_token": "tok"})

    def get(self, url, **kwargs):
        self.get_kwargs = kwargs
        return _FakeResponse(self._requests_payload)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


def test_warrant_requests_asks_for_the_full_horkos_window(monkeypatch):
    """warrant_requests requests limit=500 — the API cap — not 100. A stamp
    older than the old 100-window silently vanished from the fetch, and its
    task was then inferred as if the approval had never been recorded (#12's
    failure mode recurring)."""
    client = _FakeOpsClient([{"id": 1, "status": "approved"}])
    monkeypatch.setattr(verify_runs.subprocess, "run", lambda *a, **k: _FakeProc())
    monkeypatch.setattr(verify_runs, "_ops_client", lambda: client)

    records = verify_runs.warrant_requests()

    assert records == {1: {"id": 1, "status": "approved"}}
    assert client.get_kwargs["params"] == {"limit": 500}


class _Recorder:
    def __init__(self):
        self.messages = []

    def print(self, *objects, **kwargs):
        self.messages.append(" ".join(str(o) for o in objects))


def test_stamped_warrant_missing_from_fetch_warns_but_still_infers(monkeypatch):
    """The fetch of the 500 newest horkos requests succeeded but returned no
    record for this task's stamped warrant id (an old warrant, or one the API
    pruned): the sweep must warn — a genuinely approved task is being
    attributed by the guesswork the record was supposed to replace — while
    inference still runs (attribution is unchanged)."""
    task = task_row()
    task["node_id"] = "n71"
    monkeypatch.setattr(verify_runs, "open_approve_tasks", lambda: [task])
    monkeypatch.setattr(verify_runs, "forge_token", lambda: "token")
    monkeypatch.setattr(
        verify_runs,
        "recent_runs",
        lambda client: [{**run_row(1754), "status": "success"}],
    )
    monkeypatch.setattr(verify_runs, "sha_policy", lambda client: {})
    monkeypatch.setattr(verify_runs, "warrant_requests", dict)
    monkeypatch.setattr(verify_runs, "warrant_id_for", lambda node_id: 54)
    recorder = _Recorder()
    monkeypatch.setattr(verify_runs, "console", recorder)

    verify_runs.main(dry_run=True)

    warnings = [m for m in recorder.messages if "not among the" in m]
    assert len(warnings) == 1
    assert "warrant #54" in warnings[0]
    assert "500 newest horkos requests" in warnings[0]
    # behavior kept: the heuristic still matched run 1754 and closed the task
    assert any("closed" in m and "1754" in m for m in recorder.messages)
