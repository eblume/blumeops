"""--repo: the request lands on the PR in the repo that PR actually lives in.

The bug: a change in eblume/talos that needs the talos image rebuilt is
requested against a *blumeops* commit, but its PR is in eblume/talos.
`request-run --pr 12` commented on blumeops PR #12 — a different change
entirely — and Warrant's queue linked the approver to it too. The workflow,
policy, SHA and dispatch all stay blumeops; only the attached PR moves, which
is why its #N is ambiguous and must name its repo in the heph title.
"""

import json
import subprocess

import pytest

SHA = "8c05eb4c9e2f0a1b3d5e7f9012345678abcdef01"
BLUMEOPS = "eblume/blumeops"
TALOS = "eblume/talos"
TITLE_DEFAULT = "Approve: build-container.yaml @ 8c05eb4 (PR #525)"
TITLE_REPO = "Approve: build-container.yaml @ 8c05eb4 (PR #12 (eblume/talos))"


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


def test_title_is_unchanged_for_blumeops(request_run):
    assert (
        request_run.tracking_task_title("build-container.yaml", SHA, 525)
        == TITLE_DEFAULT
    )
    assert (
        request_run.tracking_task_title("build-container.yaml", SHA, 525, BLUMEOPS)
        == TITLE_DEFAULT
    )


def test_title_names_the_repo_when_it_is_not_blumeops(request_run):
    assert (
        request_run.tracking_task_title("build-container.yaml", SHA, 12, TALOS)
        == TITLE_REPO
    )


def test_closes_the_task_for_a_cross_repo_request(request_run, heph):
    old = {"action": "build-container.yaml", "sha": SHA, "pr": 12, "pr_repo": TALOS}
    fake = heph(
        [{"node_id": "01A", "title": TITLE_REPO}],
        {"01A": "Privileged run request…\nWarrant request: #21"},
    )
    assert request_run.close_tracking_task(old, 21, 22) == "01A"
    assert fake.done == ["01A"]


def test_cross_repo_request_does_not_close_a_blumeops_task(request_run, heph):
    """Same #12 in a different repo is a different PR — the title suffix is
    what tells them apart, and the stamp confirms it."""
    old = {"action": "build-container.yaml", "sha": SHA, "pr": 12, "pr_repo": TALOS}
    fake = heph(
        [
            {
                "node_id": "01A",
                "title": "Approve: build-container.yaml @ 8c05eb4 (PR #12)",
            }
        ],
        {"01A": "Warrant request: #21"},
    )
    assert request_run.close_tracking_task(old, 21, 22) is None
    assert fake.done == []
