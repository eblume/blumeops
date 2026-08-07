"""Closing the superseded request's tracking task, without closing a stranger's.

`--supersedes` retires a request in Warrant, and its heph task has to follow —
an open "Approve: …" task for a request nobody can approve is the same stale
signal one layer down. Warrant does not know the task id, so the client finds
it: the task title is derived from the request's own coordinates, and the
`Warrant request: #<id>` line request-run stamps into the context confirms it.

Both halves are load-bearing. Title alone matches every re-request of the same
workflow at the same SHA on the same PR; the stamp alone is only reachable by
reading every task's context. Requiring both means an ambiguous match closes
nothing and says so, which is the right failure: a task left open is noticed,
a task wrongly closed is not.
"""

import json
import subprocess

import pytest

SHA = "8c05eb4c9e2f0a1b3d5e7f9012345678abcdef01"
OLD = {"action": "build-container.yaml", "sha": SHA, "pr": 525}
TITLE = "Approve: build-container.yaml @ 8c05eb4 (PR #525)"


class FakeHeph:
    """Stands in for the heph CLI: a task list, per-task context, and a record
    of what was closed."""

    def __init__(self, tasks: list[dict], contexts: dict[str, str]):
        self.tasks = tasks
        self.contexts = contexts
        self.done: list[str] = []
        self.logged: list[str] = []

    def run(self, cmd, **kwargs):
        match cmd[1]:
            case "list":
                out = json.dumps(self.tasks)
            case "context":
                out = self.contexts.get(cmd[2], "")
            case "log":
                self.logged.append(cmd[2])
                out = ""
            case "done":
                self.done.append(cmd[2])
                out = ""
            case other:  # pragma: no cover - a new call site should be explicit
                raise AssertionError(f"unexpected heph subcommand: {other}")
        return subprocess.CompletedProcess(cmd, 0, stdout=out, stderr="")


@pytest.fixture
def heph(request_run, monkeypatch):
    def install(tasks, contexts):
        fake = FakeHeph(tasks, contexts)
        monkeypatch.setattr(request_run.subprocess, "run", fake.run)
        return fake

    return install


def test_title_is_derived_from_the_requests_own_coordinates(request_run):
    assert request_run.tracking_task_title("build-container.yaml", SHA, 525) == TITLE


def test_closes_the_task_whose_context_names_the_retired_request(request_run, heph):
    fake = heph(
        [{"node_id": "01A", "title": TITLE}],
        {"01A": "Privileged run request…\nWarrant request: #21"},
    )
    assert request_run.close_tracking_task(OLD, 21, 22) == "01A"
    assert fake.done == ["01A"]
    assert fake.logged == ["01A"]


def test_same_title_different_request_is_left_alone(request_run, heph):
    """Re-requesting the same workflow at the same SHA on the same PR produces
    an identical title — the stamp is what tells the two apart."""
    fake = heph(
        [{"node_id": "01A", "title": TITLE}, {"node_id": "01B", "title": TITLE}],
        {
            "01A": "Warrant request: #21",
            "01B": "Warrant request: #22",
        },
    )
    assert request_run.close_tracking_task(OLD, 21, 22) == "01A"
    assert fake.done == ["01A"]


def test_no_match_closes_nothing(request_run, heph):
    fake = heph(
        [{"node_id": "01A", "title": "Approve: deploy-fly.yaml @ 8c05eb4 (PR #525)"}],
        {"01A": "Warrant request: #21"},
    )
    assert request_run.close_tracking_task(OLD, 21, 22) is None
    assert fake.done == []


def test_ambiguous_match_closes_nothing(request_run, heph):
    """Two open tasks stamped with the same request should never have
    happened; guessing between them is worse than saying so."""
    fake = heph(
        [{"node_id": "01A", "title": TITLE}, {"node_id": "01B", "title": TITLE}],
        {"01A": "Warrant request: #21", "01B": "Warrant request: #21"},
    )
    assert request_run.close_tracking_task(OLD, 21, 22) is None
    assert fake.done == []


def test_unreadable_heph_closes_nothing(request_run, monkeypatch):
    def boom(cmd, **kwargs):
        raise OSError("hephd socket is gone")

    monkeypatch.setattr(request_run.subprocess, "run", boom)
    assert request_run.close_tracking_task(OLD, 21, 22) is None
