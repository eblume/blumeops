"""Parse Forgejo workflows and classify their triggers.

``load_workflows(repo_root)`` reads ``<repo_root>/.forgejo/workflows/*.y*ml``
(sorted). ``classify(workflow)`` buckets a workflow by its trigger set:

- ``"dispatch"``: the only trigger is ``workflow_dispatch``.
- ``"pr"``: ``pull_request`` is present and every other trigger is
  ``workflow_dispatch`` (i.e. the set is a subset of
  ``{pull_request, workflow_dispatch}`` containing ``pull_request``).
- ``"needs-sink"``: anything else, including no triggers at all. Fail closed:
  a workflow that is not provably PR- or dispatch-only needs a failure sink.

Run as ``python -m aspects._forgejo.workflows REPO [REPO...]`` for a
per-repo classifier survey.
"""

from __future__ import annotations

import pathlib
import sys
from collections import Counter
from dataclasses import dataclass, field
from typing import Any

import yaml

WORKFLOWS_DIR = pathlib.PurePosixPath(".forgejo/workflows")

PR = "pr"
DISPATCH = "dispatch"
NEEDS_SINK = "needs-sink"
CLASSES = (PR, DISPATCH, NEEDS_SINK)

PULL_REQUEST = "pull_request"
WORKFLOW_DISPATCH = "workflow_dispatch"


class WorkflowParseError(ValueError):
    """A workflow file that cannot be read as YAML or has an unusable shape."""


@dataclass(frozen=True)
class Step:
    name: str | None
    if_: str | None
    uses: str | None
    run: str | None
    with_: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class Job:
    id: str
    if_: str | None
    needs: list[str]
    uses: str | None
    steps: list[Step]


@dataclass(frozen=True)
class Workflow:
    path: pathlib.PurePosixPath
    name: str
    triggers: frozenset[str]
    schedules: tuple[str, ...]
    jobs: dict[str, Job]


def _text(value: Any) -> str | None:
    return None if value is None else str(value)


def _mapping(value: Any, where: str, path: pathlib.PurePath) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise WorkflowParseError(
            f"{path}: {where} must be a mapping, got {type(value).__name__}"
        )
    return value


def _triggers(
    raw: Any, path: pathlib.PurePath
) -> tuple[frozenset[str], tuple[str, ...]]:
    # PyYAML is YAML 1.1, where a bare `on:` key is the boolean True.
    if raw is None:
        return frozenset(), ()
    if isinstance(raw, str):
        return frozenset({raw}), ()
    if isinstance(raw, list):
        names = raw
    elif isinstance(raw, dict):
        names = list(raw)
    else:
        raise WorkflowParseError(f"{path}: `on` must be a string, list or mapping")
    if not all(isinstance(n, str) for n in names):
        raise WorkflowParseError(f"{path}: `on` event names must be strings")
    schedules: tuple[str, ...] = ()
    if isinstance(raw, dict) and isinstance(raw.get("schedule"), list):
        schedules = tuple(
            str(entry["cron"])
            for entry in raw["schedule"]
            if isinstance(entry, dict) and "cron" in entry
        )
    return frozenset(names), schedules


def _steps(raw: Any, job_id: str, path: pathlib.PurePath) -> list[Step]:
    if raw is None:
        return []
    if not isinstance(raw, list) or not all(isinstance(s, dict) for s in raw):
        raise WorkflowParseError(
            f"{path}: job {job_id!r} steps must be a list of mappings"
        )
    return [
        Step(
            name=_text(s.get("name")),
            if_=_text(s.get("if")),
            uses=_text(s.get("uses")),
            run=_text(s.get("run")),
            with_=_mapping(s.get("with"), f"job {job_id!r} step `with`", path),
        )
        for s in raw
    ]


def _needs(raw: Any, job_id: str, path: pathlib.PurePath) -> list[str]:
    if raw is None:
        return []
    if isinstance(raw, str):
        return [raw]
    if isinstance(raw, list) and all(isinstance(n, str) for n in raw):
        return list(raw)
    raise WorkflowParseError(
        f"{path}: job {job_id!r} needs must be a string or a list of strings"
    )


def parse_workflow(
    text: str, path: pathlib.PurePosixPath, abs_path: pathlib.Path | None = None
) -> Workflow:
    """Parse one workflow document. ``path`` is recorded as-is; ``abs_path`` only labels errors."""
    where = abs_path if abs_path is not None else path
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        raise WorkflowParseError(f"{where}: unparseable YAML: {exc}") from exc
    if data is None:
        data = {}
    if not isinstance(data, dict):
        raise WorkflowParseError(
            f"{where}: top level must be a mapping, got {type(data).__name__}"
        )

    if "on" in data and True in data:
        raise WorkflowParseError(f'{where}: both `on` and `"on"`/true keys present')
    raw_on = data.get("on", data.get(True))
    triggers, schedules = _triggers(raw_on, where)

    jobs: dict[str, Job] = {}
    for job_id, body in _mapping(data.get("jobs"), "`jobs`", where).items():
        job_id = str(job_id)
        body = _mapping(body, f"job {job_id!r}", where)
        jobs[job_id] = Job(
            id=job_id,
            if_=_text(body.get("if")),
            needs=_needs(body.get("needs"), job_id, where),
            uses=_text(body.get("uses")),
            steps=_steps(body.get("steps"), job_id, where),
        )

    name = data.get("name")
    return Workflow(
        path=path,
        name=str(name) if isinstance(name, str) else path.stem,
        triggers=triggers,
        schedules=schedules,
        jobs=jobs,
    )


def load_workflows(repo_root: pathlib.Path) -> list[Workflow]:
    """All workflows under ``repo_root/.forgejo/workflows``, sorted by file name."""
    directory = repo_root / WORKFLOWS_DIR
    if not directory.is_dir():
        return []
    workflows = []
    for file in sorted(
        p for p in directory.iterdir() if p.is_file() and p.suffix in (".yml", ".yaml")
    ):
        rel = pathlib.PurePosixPath(file.relative_to(repo_root).as_posix())
        workflows.append(parse_workflow(file.read_text(), rel, file))
    return workflows


def classify(workflow: Workflow) -> str:
    """Return ``"pr"``, ``"dispatch"`` or ``"needs-sink"`` per the module rule."""
    triggers = workflow.triggers
    if triggers == {WORKFLOW_DISPATCH}:
        return DISPATCH
    if PULL_REQUEST in triggers and triggers <= {PULL_REQUEST, WORKFLOW_DISPATCH}:
        return PR
    return NEEDS_SINK


def _survey(roots: list[pathlib.Path]) -> int:
    print(f"{'repo':<24}{'files':>6}{'pr':>5}{'dispatch':>10}{'needs-sink':>12}")
    status = 0
    for root in roots:
        try:
            workflows = load_workflows(root)
        except (WorkflowParseError, OSError) as exc:
            print(f"{root.name:<24}error: {exc}", file=sys.stderr)
            status = 1
            continue
        counts = Counter(classify(w) for w in workflows)
        print(
            f"{root.name:<24}{len(workflows):>6}{counts[PR]:>5}"
            f"{counts[DISPATCH]:>10}{counts[NEEDS_SINK]:>12}"
        )
    return status


if __name__ == "__main__":
    sys.exit(_survey([pathlib.Path(p).resolve() for p in sys.argv[1:]]))
