"""Every local prek hook and PR-gating CI job needs a red fixture.

A guard's red fixture lives at tests/guards/red/<guard-id>/ (at least one
regular file, recursively). Guard ids: the local hook id, or
<workflow-stem>.<job-id> for a job in a pull_request-triggered workflow.
Violations: unfixtured guards not in baseline.json (by id) and orphan entries
under tests/guards/red/ (by path). Rules and exclusions: see ASPECT.md.
"""

from __future__ import annotations

import pathlib
import tomllib

from aspects._forgejo.workflows import PULL_REQUEST, load_workflows

KIND = "ratchet"
APPLIES_TO = ["eblume/blumeops"]

RED_DIR = pathlib.PurePosixPath("tests/guards/red")

# Guard id -> one-line reason it is not a guard. Changing this is consent-touching.
NOT_GUARDS: dict[str, str] = {
    "aspects.aspects": "the suite's own job; aspects/test_meta.py rejects every aspect's red fixture that its check accepts",
    "build-container.detect": "classifier: emits outputs for downstream jobs and runs no policy; its only failure is an infrastructure error",
    "build-container.container-test": "test-runner job: runs exporter test suites whose individual tests are the evidence",
    "tests.horkos-test": "test-runner job: the job is the horkos test suite; its individual tests are the evidence",
}


def _local_hook_ids(root: pathlib.Path) -> set[str]:
    prek = root / "prek.toml"
    if not prek.is_file():
        return set()
    data = tomllib.loads(prek.read_text())
    return {
        hook["id"]
        for repo in data.get("repos", [])
        if repo.get("repo") == "local"
        for hook in repo.get("hooks", [])
    }


def _pr_job_ids(root: pathlib.Path) -> set[str]:
    return {
        f"{wf.path.stem}.{job_id}"
        for wf in load_workflows(root)
        if PULL_REQUEST in wf.triggers
        for job_id in wf.jobs
    }


def check(root: pathlib.Path) -> list[str]:
    in_scope = (_local_hook_ids(root) | _pr_job_ids(root)) - set(NOT_GUARDS)
    red_root = root / RED_DIR

    def has_fixture(guard_id: str) -> bool:
        directory = red_root / guard_id
        return directory.is_dir() and any(p.is_file() for p in directory.rglob("*"))

    violations = [g for g in in_scope if not has_fixture(g)]
    if red_root.is_dir():
        violations += [
            f"orphan red fixture: {RED_DIR}/{entry.name}"
            for entry in red_root.iterdir()
            if not (entry.is_dir() and entry.name in in_scope)
        ]
    return sorted(set(violations))


def test_remote_prek_hook_is_out_of_scope(tmp_path: pathlib.Path) -> None:
    # Not a fixture: a remote hook in a nested prek.toml would make prek clone it.
    (tmp_path / "prek.toml").write_text(
        '[[repos]]\nrepo = "https://github.com/example/x"\n'
        'rev = "0000000000000000000000000000000000000000"\n'
        'hooks = [{ id = "x-lint" }]\n'
    )
    assert check(tmp_path) == []
