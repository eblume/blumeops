"""No workflow may fail silently: a needs-sink workflow needs a failure sink.

Rules, matcher and registry: see ASPECT.md. Parser and trigger classifier are
the shared ones in aspects/_forgejo/workflows.py.

Identity. The repo label on the alert metric and the registry key are the
canonical `owner/name`: the `upstream` remote when configured (a talos fork
checkout of blumeops is `eblume/blumeops` upstream), else `origin`. A
non-git root has no identity, so no exemption or alert can match it and it
fails closed. A case under fixtures/ is its own mini repo with identity
`fixture/<case>`.
"""

from __future__ import annotations

import os
import pathlib
import re
import subprocess
from typing import Any, NamedTuple

import pytest
import yaml

from aspects._forgejo.workflows import (
    NEEDS_SINK,
    Workflow,
    classify,
    load_workflows,
    parse_workflow,
)
from aspects.runner import parse_repo_identity

KIND = "ratchet"
APPLIES_TO = ["eblume/blumeops"]

ASPECT_DIR = pathlib.Path(__file__).resolve().parent
REGISTRY_PATH = ASPECT_DIR / "sinks.yaml"
FIXTURES_DIR = ASPECT_DIR / "fixtures"
METRIC = "forgejo_actions_last_success_timestamp_seconds"
_REGISTRY_KEYS = frozenset({"reporters", "exemptions", "evidence"})
_SINK_TYPES = ("reporter", "alert")

# --- registry ---------------------------------------------------------------


# NamedTuple, not @dataclass: the runner execs test modules without a
# sys.modules entry, which dataclass() needs.
class Exemption(NamedTuple):
    repo: str
    workflow: str
    reason: str


class Registry(NamedTuple):
    reporters: frozenset[str]
    exemptions: tuple[Exemption, ...]


def load_registry(path: pathlib.Path) -> Registry:
    try:
        data = yaml.safe_load(path.read_text()) or {}
    except yaml.YAMLError as exc:
        raise ValueError(f"{path}: unparseable registry: {exc}") from exc
    if not isinstance(data, dict):
        raise TypeError(f"{path}: top level must be a mapping")
    if set(data) - _REGISTRY_KEYS:
        raise ValueError(
            f"{path}: unknown registry keys {sorted(set(data) - _REGISTRY_KEYS)}"
        )

    reporters = data.get("reporters") or []
    if not isinstance(reporters, list) or not all(
        isinstance(r, str) and r for r in reporters
    ):
        raise ValueError(f"{path}: reporters must be a list of action names")

    raw = data.get("exemptions") or []
    if not isinstance(raw, list):
        raise TypeError(f"{path}: exemptions must be a list")
    exemptions = []
    for i, entry in enumerate(raw):
        if not isinstance(entry, dict) or set(entry) != {"repo", "workflow", "reason"}:
            raise ValueError(
                f"{path}: exemptions[{i}] must have exactly repo, workflow, reason"
            )
        if not all(isinstance(v, str) and v.strip() for v in entry.values()):
            raise ValueError(
                f"{path}: exemptions[{i}] fields must be non-empty strings"
            )
        if "\n" in entry["reason"]:
            raise ValueError(f"{path}: exemptions[{i}] reason must be one line")
        exemptions.append(Exemption(entry["repo"], entry["workflow"], entry["reason"]))

    evidence = data.get("evidence")
    if not isinstance(evidence, dict) or set(evidence) != set(_SINK_TYPES):
        raise ValueError(f"{path}: evidence must have exactly {list(_SINK_TYPES)}")
    for sink_type in _SINK_TYPES:
        item = evidence[sink_type]
        if not isinstance(item, dict) or set(item) != {"date", "link"}:
            raise ValueError(f"{path}: evidence.{sink_type} must have date and link")

    return Registry(frozenset(reporters), tuple(exemptions))


def _is_fixture(root: pathlib.Path) -> bool:
    return root.is_relative_to(FIXTURES_DIR)


def _registry_path(root: pathlib.Path) -> pathlib.Path:
    local = root / "sinks.yaml"
    if _is_fixture(root) and local.is_file():
        return local
    return REGISTRY_PATH


# --- identity and alert source ----------------------------------------------


def _remote(root: pathlib.Path, name: str) -> str | None:
    result = subprocess.run(
        ["git", "config", "--get", f"remote.{name}.url"],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    url = result.stdout.strip()
    return url or None


def _identity(root: pathlib.Path) -> str:
    if _is_fixture(root):
        return f"fixture/{root.name}"
    # Without .git, `git config` would walk up from a fixture-like dir into blumeops.
    if not (root / ".git").exists():
        return ""
    url = _remote(root, "upstream") or _remote(root, "origin")
    if url is None:
        return ""
    try:
        return parse_repo_identity(url)
    except ValueError:
        return ""


def _alert_root(root: pathlib.Path, identity: str) -> pathlib.Path | None:
    if _is_fixture(root):
        return root
    env = os.environ.get("BLUMEOPS_ROOT")
    if env:
        return pathlib.Path(env).expanduser()
    if identity == "eblume/blumeops":
        return root
    return None


# --- sink matchers ----------------------------------------------------------

_FAILURE_CALL = re.compile(r"(?<!\w)failure\(\)")
_NEGATED_FAILURE = re.compile(r"!\s*failure\(\)")
_OUTCOME_FAILED = re.compile(
    r"(?:steps\.[\w-]+\.outcome|needs\.[\w-]+\.result)\s*==\s*['\"]failure['\"]"
)
_LOCAL_ACTION = re.compile(r"\./\.forgejo/actions/([\w.-]+)")
_CROSS_ACTION = re.compile(r"eblume/blumeops/\.forgejo/actions/([\w.-]+)(?:@[\w./-]+)?")


def runs_on_failure(condition: str | None) -> bool:
    """True for `failure()` (not negated), or `always()` with a failed-outcome check."""
    if not condition or _NEGATED_FAILURE.search(condition):
        return False
    if _FAILURE_CALL.search(condition):
        return True
    return "always()" in condition and _OUTCOME_FAILED.search(condition) is not None


def reporter_name(uses: str) -> str | None:
    """The action name for a local or eblume/blumeops `uses:` reference, else None."""
    match = _LOCAL_ACTION.fullmatch(uses.strip()) or _CROSS_ACTION.fullmatch(
        uses.strip()
    )
    return match.group(1) if match else None


def has_sink(workflow: Workflow, reporters: frozenset[str]) -> bool:
    """A failure()-gated step using a registered reporter, not gated on pull_request."""
    for job in workflow.jobs.values():
        if job.if_ and "pull_request" in job.if_:
            continue
        if job.needs and not (
            runs_on_failure(job.if_) or "always()" in (job.if_ or "")
        ):
            continue
        for step in job.steps:
            if not step.uses or not runs_on_failure(step.if_):
                continue
            if "pull_request" in (step.if_ or ""):
                continue
            if reporter_name(step.uses) in reporters:
                return True
    return False


_SELECTOR = re.compile(
    r"(?<![\w:])" + METRIC + r"(?![\w:])"
    r"(?:\{((?:[^{}\"]|\"(?:[^\"\\]|\\.)*\")*)\})?"
)
_MATCHER = re.compile(r'(\w+)\s*(=~|!~|!=|=)\s*"((?:[^"\\]|\\.)*)"')

Matcher = tuple[str, str, str]


def selectors(expr: str) -> list[list[Matcher]]:
    """Label matchers of each metric selector in a PromQL expression.

    A bare metric with no braces yields an empty matcher list (selects all).
    """
    return [_MATCHER.findall(m.group(1) or "") for m in _SELECTOR.finditer(expr)]


def selects_series(matchers: list[Matcher], series: dict[str, str]) -> bool:
    """PromQL semantics for one series. Labels the series does not carry are not matched."""
    for label, op, value in matchers:
        if label not in series:
            continue
        actual = series[label]
        if op == "=":
            ok = actual == value
        elif op == "!=":
            ok = actual != value
        elif op == "=~":
            ok = re.fullmatch(value, actual) is not None
        else:  # !~
            ok = re.fullmatch(value, actual) is None
        if not ok:
            return False
    return True


def names_workflow(matchers: list[Matcher]) -> bool:
    """True if a positive workflow matcher cannot match the empty string (`.*` does not count)."""
    return any(
        label == "workflow"
        and op in ("=", "=~")
        and value
        and re.fullmatch(value, "") is None
        for label, op, value in matchers
    )


def _alert_selectors(alert_root: pathlib.Path | None) -> list[list[Matcher]]:
    found: list[list[Matcher]] = []
    if alert_root is None:
        return found
    for path in sorted(alert_root.glob("argocd/manifests/grafana-*/alerting.yaml")):
        data = yaml.safe_load(path.read_text()) or {}
        for group in _items(data, "groups"):
            for rule in _items(group, "rules"):
                if rule.get("isPaused"):
                    continue
                for datum in _items(rule, "data"):
                    model = datum.get("model")
                    expr = model.get("expr") if isinstance(model, dict) else None
                    if isinstance(expr, str):
                        found.extend(selectors(expr))
    return found


def _items(container: Any, key: str) -> list[dict[str, Any]]:
    value = container.get(key) if isinstance(container, dict) else None
    if not isinstance(value, list):
        return []
    return [v for v in value if isinstance(v, dict)]


# --- check ------------------------------------------------------------------


def check(root: pathlib.Path) -> list[str]:
    root = root.resolve()
    identity = _identity(root)
    registry = load_registry(_registry_path(root))
    alerts: list[list[Matcher]] | None = None
    violations: list[str] = []
    for workflow in load_workflows(root):
        if classify(workflow) != NEEDS_SINK:
            continue
        stem = workflow.path.stem
        if has_sink(workflow, registry.reporters):
            continue
        if any(e.repo == identity and e.workflow == stem for e in registry.exemptions):
            continue
        if identity:
            if alerts is None:
                alerts = _alert_selectors(_alert_root(root, identity))
            series = {"repo": identity, "workflow": stem}
            if any(names_workflow(m) and selects_series(m, series) for m in alerts):
                continue
        violations.append(workflow.path.as_posix())
    return violations


# --- unit tests -------------------------------------------------------------
# These exercise the matchers and registry rules directly; the fixtures above
# cover the end-to-end verdicts.


def _wf(body: str) -> Workflow:
    return parse_workflow(body, pathlib.PurePosixPath("w.yaml"))


_STEP_HEAD = "on: schedule\njobs:\n  j:\n    steps:\n"


def _sink_wf(if_line: str, uses: str) -> Workflow:
    return _wf(_STEP_HEAD + f"      - if: {if_line}\n        uses: {uses}\n")


@pytest.mark.parametrize(
    "cond, expected",
    [
        ("failure()", True),
        ("${{ failure() }}", True),
        ("always() && steps.sync.outcome == 'failure'", True),
        ('always() && needs.build.result == "failure"', True),
        ("always()", False),
        ("!failure()", False),
        ("! failure()", False),
        ("success()", False),
        ("failure() && github.event_name == 'pull_request'", True),
        (None, False),
    ],
)
def test_runs_on_failure(cond, expected):
    assert runs_on_failure(cond) is expected


@pytest.mark.parametrize(
    "uses, name",
    [
        ("./.forgejo/actions/report-run-failure", "report-run-failure"),
        (
            "eblume/blumeops/.forgejo/actions/report-run-failure@main",
            "report-run-failure",
        ),
        ("eblume/blumeops/.forgejo/actions/report-run-failure", "report-run-failure"),
        ("./.forgejo/actions/report-failure", "report-failure"),
        ("other/repo/.forgejo/actions/report-run-failure", None),
        ("actions/checkout@v4", None),
        ("./.forgejo/actions/x/y", None),
    ],
)
def test_reporter_name(uses, name):
    assert reporter_name(uses) == name


def test_registered_reporter_on_failure_is_a_sink():
    wf = _sink_wf("failure()", "./.forgejo/actions/report-run-failure")
    assert has_sink(wf, frozenset({"report-run-failure"}))


def test_unregistered_reporter_is_not_a_sink():
    wf = _sink_wf("failure()", "./.forgejo/actions/report-failure")
    assert not has_sink(wf, frozenset({"report-run-failure"}))


def test_inline_curl_filer_is_not_a_sink():
    wf = _wf(_STEP_HEAD + "      - if: failure()\n        run: curl -X POST ntfy\n")
    assert not has_sink(wf, frozenset({"report-run-failure"}))


def test_job_needs_requires_job_level_failure_gate():
    body = (
        "on: schedule\njobs:\n  build:\n    steps:\n      - run: make\n"
        "  j:\n{job_if}    needs: [build]\n    steps:\n"
        "      - if: failure()\n        uses: ./.forgejo/actions/report-run-failure\n"
    )
    reporters = frozenset({"report-run-failure"})
    assert not has_sink(_wf(body.format(job_if="")), reporters)
    assert has_sink(_wf(body.format(job_if="    if: always()\n")), reporters)
    no_needs = body.format(job_if="").replace("    needs: [build]\n", "")
    assert has_sink(_wf(no_needs), reporters)


def test_pr_gated_sink_does_not_count():
    wf = _sink_wf(
        "failure() && github.event_name == 'pull_request'",
        "./.forgejo/actions/report-run-failure",
    )
    assert not has_sink(wf, frozenset({"report-run-failure"}))


def test_job_level_pr_gate_does_not_count():
    wf = _wf(
        "on: schedule\njobs:\n  j:\n    if: github.event_name == 'pull_request'\n"
        "    steps:\n      - if: failure()\n        uses: ./.forgejo/actions/report-run-failure\n"
    )
    assert not has_sink(wf, frozenset({"report-run-failure"}))


def test_selector_exact_and_regex_matchers():
    expr = (
        'time() - forgejo_actions_last_success_timestamp_seconds{repo="eblume/blumeops",'
        'workflow=~"forge-.*|tests"}'
    )
    [matchers] = selectors(expr)
    assert selects_series(matchers, {"repo": "eblume/blumeops", "workflow": "tests"})
    assert selects_series(
        matchers, {"repo": "eblume/blumeops", "workflow": "forge-reconcile"}
    )
    assert not selects_series(matchers, {"repo": "eblume/blumeops", "workflow": "lint"})
    assert not selects_series(matchers, {"repo": "eblume/other", "workflow": "tests"})


def test_selector_negative_matchers():
    [matchers] = selectors(
        'forgejo_actions_last_success_timestamp_seconds{workflow!="lint",workflow!~"x.*"}'
    )
    assert not selects_series(matchers, {"workflow": "lint"})
    assert not selects_series(matchers, {"workflow": "xray"})
    assert selects_series(matchers, {"workflow": "tests"})


def test_selector_without_workflow_matcher_names_no_workflow():
    series = {"repo": "eblume/blumeops", "workflow": "nightly"}
    [repo_only] = selectors(
        'forgejo_actions_last_success_timestamp_seconds{repo="eblume/blumeops"}'
    )
    assert selects_series(repo_only, series)
    assert not names_workflow(repo_only)
    [match_all] = selectors(
        'forgejo_actions_last_success_timestamp_seconds{workflow=~".*"}'
    )
    assert names_workflow(match_all) is False
    [empty] = selectors('forgejo_actions_last_success_timestamp_seconds{workflow=""}')
    assert names_workflow(empty) is False
    [exact] = selectors(
        'forgejo_actions_last_success_timestamp_seconds{repo="eblume/blumeops",workflow="nightly"}'
    )
    assert names_workflow(exact)


def test_bare_metric_selects_all_series():
    [matchers] = selectors("time() - forgejo_actions_last_success_timestamp_seconds")
    assert matchers == []
    assert selects_series(matchers, {"repo": "a/b", "workflow": "c"})


def test_other_metric_names_are_not_selectors():
    assert (
        selectors(
            'time() - forgejo_actions_last_success_timestamp_seconds_extra{workflow="x"}'
        )
        == []
    )
    assert selectors('time() - forgejo_ci_jobs_total{workflow="x"}') == []


def test_registry_rejects_bad_shapes(tmp_path):
    base = "reporters: []\nevidence:\n  reporter: {date: null, link: null}\n  alert: {date: null, link: null}\n"
    path = tmp_path / "sinks.yaml"
    path.write_text(base + "exemptions:\n  - repo: a/b\n    workflow: w\n")
    with pytest.raises(ValueError, match="exactly repo, workflow, reason"):
        load_registry(path)
    path.write_text(
        base
        + 'exemptions:\n  - repo: a/b\n    workflow: w\n    reason: "two\\nlines"\n'
    )
    with pytest.raises(ValueError, match="one line"):
        load_registry(path)
    path.write_text(base + "exemptions: []\nbogus: 1\n")
    with pytest.raises(ValueError, match="unknown registry keys"):
        load_registry(path)


def test_registry_loads_real_file():
    reg = load_registry(REGISTRY_PATH)
    assert "report-run-failure" in reg.reporters
    assert reg.exemptions == ()


def test_non_git_root_has_no_identity(tmp_path):
    assert _identity(tmp_path) == ""


def test_identity_prefers_upstream_remote(tmp_path):
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    for name, url in (
        ("origin", "https://forge.ops.eblu.me/talos/blumeops.git"),
        ("upstream", "https://forge.ops.eblu.me/eblume/blumeops.git"),
    ):
        subprocess.run(
            ["git", "-C", str(tmp_path), "remote", "add", name, url], check=True
        )
    assert _identity(tmp_path) == "eblume/blumeops"
