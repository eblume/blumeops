"""Parser and classifier tests for aspects/_forgejo/workflows.py.

Fixtures are inline YAML written to tmp_path. The sibling-pool survey test
is skipped when the pool worktrees are absent.
"""

import pathlib

import pytest

from aspects._forgejo.workflows import (
    DISPATCH,
    NEEDS_SINK,
    PR,
    WorkflowParseError,
    classify,
    load_workflows,
    parse_workflow,
)

POOL = pathlib.Path("/home/talos/sessions/01a17b15-ff34-790b-8c6c-f1d5a0f3718b")
POOL_REPOS = [
    "RexWorks",
    "agents",
    "cv",
    "gamedev",
    "hephaestus",
    "hephaestus.nvim",
    "horkos",
    "myeve",
    "project-template",
    "release-kit",
    "research",
    "talos",
    "timberborn-parsimony",
]


def _wf(text: str):
    return parse_workflow(text, pathlib.PurePosixPath("x.yaml"))


def _write(root: pathlib.Path, name: str, text: str) -> None:
    d = root / ".forgejo" / "workflows"
    d.mkdir(parents=True, exist_ok=True)
    (d / name).write_text(text)


# --- `on:` shapes -----------------------------------------------------------


def test_on_key_parses_as_true_under_yaml11():
    # Bare `on:` is the boolean True in YAML 1.1; the parser must still see it.
    wf = _wf("name: a\non:\n  pull_request:\njobs: {}\n")
    assert wf.triggers == {"pull_request"}


@pytest.mark.parametrize(
    "text, expected",
    [
        ('"on": pull_request\n', PR),
        ("on:\njobs: {}\n", NEEDS_SINK),
    ],
)
def test_on_spellings_classify(text, expected):
    assert classify(_wf(text)) == expected


def test_both_on_spellings_rejected(tmp_path):
    _write(tmp_path, "dual.yaml", 'on: push\n"on": pull_request\n')
    with pytest.raises(WorkflowParseError, match="dual.yaml"):
        load_workflows(tmp_path)


def test_on_as_string():
    assert _wf("on: push\n").triggers == {"push"}


def test_on_as_list():
    assert _wf("on: [push, pull_request]\n").triggers == {"push", "pull_request"}


def test_on_as_mapping_with_null_and_config_values():
    wf = _wf("on:\n  workflow_dispatch:\n  push:\n    branches: [main]\n")
    assert wf.triggers == {"workflow_dispatch", "push"}


def test_schedule_list_yields_crons():
    wf = _wf("on:\n  schedule:\n    - cron: '0 3 * * *'\n    - cron: '5 4 * * 1'\n")
    assert wf.triggers == {"schedule"}
    assert wf.schedules == ("0 3 * * *", "5 4 * * 1")


def test_missing_on_gives_empty_triggers():
    wf = _wf("name: nothing\njobs: {}\n")
    assert wf.triggers == frozenset()
    assert classify(wf) == NEEDS_SINK


def test_empty_document_is_tolerated():
    wf = _wf("")
    assert wf.triggers == frozenset() and wf.jobs == {}
    assert wf.name == "x"


def test_missing_jobs_gives_empty_jobs():
    assert _wf("on: push\n").jobs == {}


def test_unparseable_yaml_names_the_file(tmp_path):
    _write(tmp_path, "broken.yaml", "on: [push\n")
    with pytest.raises(WorkflowParseError, match="broken.yaml"):
        load_workflows(tmp_path)


def test_non_mapping_top_level_rejected():
    with pytest.raises(WorkflowParseError):
        _wf("- just\n- a list\n")


# --- classify ---------------------------------------------------------------


@pytest.mark.parametrize(
    "text, expected",
    [
        ("on: pull_request\n", PR),
        ("on:\n  pull_request:\n  workflow_dispatch:\n", PR),
        ("on: workflow_dispatch\n", DISPATCH),
        ("on:\n  workflow_dispatch:\n", DISPATCH),
        ("on:\n  pull_request:\n  schedule:\n    - cron: '0 0 * * *'\n", NEEDS_SINK),
        ("on: push\n", NEEDS_SINK),
        ("on:\n  release:\n    types: [published]\n", NEEDS_SINK),
        ("on:\n  workflow_run:\n    workflows: [ci]\n", NEEDS_SINK),
        ("on: workflow_call\n", NEEDS_SINK),
        ("on: pull_request_target\n", NEEDS_SINK),
        ("on: [pull_request, push]\n", NEEDS_SINK),
    ],
)
def test_classify(text, expected):
    assert classify(_wf(text)) == expected


def test_classify_mixed_pr_and_schedule_is_needs_sink():
    wf = _wf("on:\n  pull_request:\n  schedule:\n    - cron: '0 0 * * *'\n")
    assert classify(wf) == NEEDS_SINK


# --- jobs, steps, if:, uses: ------------------------------------------------

JOBS = """\
name: Report
on:
  pull_request:
jobs:
  build:
    if: github.event_name == 'pull_request'
    needs: [lint, test]
    steps:
      - name: build
        run: make build
      - name: guarded
        if: failure()
        uses: ./.forgejo/actions/report-failure
        with:
          title: build
  call:
    uses: ./.forgejo/workflows/inner.yaml
    needs: lint
"""


def test_jobs_steps_and_uses_extracted():
    wf = _wf(JOBS)
    assert wf.name == "Report"
    assert set(wf.jobs) == {"build", "call"}
    build = wf.jobs["build"]
    assert build.if_ == "github.event_name == 'pull_request'"
    assert build.needs == ["lint", "test"]
    assert build.uses is None
    assert [s.name for s in build.steps] == ["build", "guarded"]
    assert build.steps[0].run == "make build"
    assert build.steps[0].uses is None
    assert build.steps[0].if_ is None


def test_step_if_and_uses_are_reported_not_judged():
    guarded = _wf(JOBS).jobs["build"].steps[1]
    assert guarded.if_ == "failure()"
    assert guarded.uses == "./.forgejo/actions/report-failure"
    assert guarded.with_ == {"title": "build"}
    assert guarded.run is None


def test_reusable_job_call_and_needs_string():
    call = _wf(JOBS).jobs["call"]
    assert call.uses == "./.forgejo/workflows/inner.yaml"
    assert call.needs == ["lint"]
    assert call.steps == []


def test_workflow_name_defaults_to_stem(tmp_path):
    _write(tmp_path, "zeta.yml", "on: push\n")
    _write(tmp_path, "alpha.yaml", "name: Named\non: pull_request\n")
    _write(tmp_path, "ignored.txt", "on: push\n")
    loaded = load_workflows(tmp_path)
    assert [w.path.as_posix() for w in loaded] == [
        ".forgejo/workflows/alpha.yaml",
        ".forgejo/workflows/zeta.yml",
    ]
    assert [w.name for w in loaded] == ["Named", "zeta"]


def test_load_workflows_without_directory(tmp_path):
    assert load_workflows(tmp_path) == []


# --- survey over sibling pool worktrees (skipped when absent) ---------------


@pytest.mark.skipif(not POOL.is_dir(), reason="sibling pool worktrees not present")
def test_pool_survey_loads_every_present_repo():
    checked = 0
    unreadable = []
    for repo in POOL_REPOS:
        root = POOL / repo
        if not (root / ".forgejo" / "workflows").is_dir():
            continue
        try:
            load_workflows(root)
        except PermissionError:
            unreadable.append(repo)
            continue
        checked += 1
    if checked == 0:
        pytest.skip(f"no readable sibling pool worktrees (unreadable: {unreadable})")
