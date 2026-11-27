"""Broker mode of `mise-tasks/pr-comments` and `mise-tasks/runner-logs`.

With TALOS_BROKER_URL and TALOS_BROKER_TOKEN both set, forge reads go to the
broker's /api/v1 base with a Bearer header, and neither `op` nor any token
mint runs. Unset (or half-set) keeps the direct base and FORGEJO_TOKEN path.
"""

import importlib.machinery
import importlib.util
import pathlib

import httpx
import pytest
import typer
from typer.testing import CliRunner

ROOT = pathlib.Path(__file__).resolve().parent.parent
BROKER = "http://127.0.0.1:9999"
DIRECT_API = "https://forge.ops.eblu.me/api/v1"
REPO = "eblume/blumeops"
PR_PATH = f"/api/v1/repos/{REPO}/pulls/645"
RUN_ID = 1325
TASKS_PATH = f"/api/v1/repos/{REPO}/actions/tasks"
RUNS_PATH = f"/api/v1/repos/{REPO}/actions/runs"
JOBS_PATH = f"/api/v1/repos/{REPO}/actions/runs/{RUN_ID}/jobs"
LOGS_PATH = f"/api/v1/repos/{REPO}/actions/jobs/7/logs"


def _load(name: str):
    loader = importlib.machinery.SourceFileLoader(
        name.replace("-", "_"), str(ROOT / "mise-tasks" / name)
    )
    spec = importlib.util.spec_from_loader(loader.name, loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


@pytest.fixture
def pr_comments():
    return _load("pr-comments")


@pytest.fixture
def runner_logs():
    return _load("runner-logs")


def _clear_broker(monkeypatch):
    monkeypatch.delenv("TALOS_BROKER_URL", raising=False)
    monkeypatch.delenv("TALOS_BROKER_TOKEN", raising=False)


def _no_op(*args, **kwargs):
    raise AssertionError("op/subprocess must not run in broker mode")


def _route(request: httpx.Request) -> httpx.Response:
    """Canned forge answers; the Bearer requirement is enforced here."""
    path = request.url.path
    if path == PR_PATH:
        return httpx.Response(200, json={"number": 645, "title": "t", "state": "open"})
    if path.endswith(("/comments", "/reviews")):
        return httpx.Response(200, json=[])
    if path == TASKS_PATH:
        return httpx.Response(200, json={"workflow_runs": []})
    if path == RUNS_PATH:
        return httpx.Response(
            200,
            json={"workflow_runs": [{"id": RUN_ID, "index_in_repo": 474}]},
        )
    if path == JOBS_PATH:
        return httpx.Response(
            200, json=[{"id": 7, "name": "build", "status": "success", "attempt": 1}]
        )
    if path == LOGS_PATH:
        return httpx.Response(200, text="log line\n")
    return httpx.Response(404, text="unexpected " + path)


@pytest.fixture
def recorded(monkeypatch):
    """Every httpx.Client gets the canned MockTransport. Records the requests
    and the constructor kwargs so tests can check trust_env and the base."""
    requests: list[httpx.Request] = []
    kwargs_seen: list[dict] = []
    real_client = httpx.Client

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return _route(request)

    def fake_client(*args, **kwargs):
        kwargs_seen.append(kwargs)
        kwargs["transport"] = httpx.MockTransport(handler)
        return real_client(*args, **kwargs)

    monkeypatch.setattr(httpx, "Client", fake_client)

    def fake_get(url, **kwargs):
        with real_client(transport=httpx.MockTransport(handler)) as c:
            return c.get(url, **kwargs)

    monkeypatch.setattr(httpx, "get", fake_get)
    monkeypatch.setattr("subprocess.run", _no_op)
    return requests, kwargs_seen


def _invoke(module, args):
    app = typer.Typer()
    app.command()(module.main)
    return CliRunner().invoke(app, args)


# --- pr-comments -----------------------------------------------------------


def test_pr_comments_broker_mode(monkeypatch, pr_comments, recorded):
    requests, kwargs_seen = recorded
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER + "/")
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    monkeypatch.setenv("FORGEJO_TOKEN", "should-not-be-used")
    result = _invoke(pr_comments, ["645", "--json", "--repo", REPO])
    assert result.exit_code == 0, result.output
    assert requests, "no request reached the transport"
    for req in requests:
        assert req.method == "GET"
        assert str(req.url).startswith(BROKER + "/api/v1/")
        assert req.headers["authorization"] == "Bearer testtok"
    assert any(kw.get("trust_env") is False for kw in kwargs_seen)


def test_pr_comments_broker_mode_never_reads_op(monkeypatch, pr_comments, recorded):
    _requests, _ = recorded
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    monkeypatch.delenv("FORGEJO_TOKEN", raising=False)
    result = _invoke(pr_comments, ["645", "--json", "--repo", REPO])
    assert result.exit_code == 0, result.output


def test_pr_comments_direct_base_when_unset(monkeypatch, pr_comments, recorded):
    requests, kwargs_seen = recorded
    _clear_broker(monkeypatch)
    monkeypatch.setenv("FORGEJO_TOKEN", "direct-tok")
    result = _invoke(pr_comments, ["645", "--json", "--repo", REPO])
    assert result.exit_code == 0, result.output
    assert requests
    for req in requests:
        assert str(req.url).startswith(DIRECT_API + "/")
        assert req.headers["authorization"] == "token direct-tok"
    # Direct clients keep httpx's default (trust_env=True), so proxy env applies.
    assert all(kw.get("trust_env", True) is True for kw in kwargs_seen)


def test_pr_comments_half_configured_is_direct(monkeypatch, pr_comments):
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "  ")
    assert pr_comments.broker() is None


# --- runner-logs -----------------------------------------------------------


def test_runner_logs_broker_mode_lists_jobs(monkeypatch, runner_logs, recorded):
    requests, kwargs_seen = recorded
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER + "/")
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    result = _invoke(runner_logs, ["474", "--repo", REPO])
    assert result.exit_code == 0, result.output
    assert requests, "no request reached the transport"
    for req in requests:
        assert str(req.url).startswith(BROKER + "/api/v1/")
        assert req.headers["authorization"] == "Bearer testtok"
    assert any(kw.get("trust_env") is False for kw in kwargs_seen)


def test_runner_logs_broker_mode_fetches_log_without_op(
    monkeypatch, runner_logs, recorded
):
    requests, _ = recorded
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    monkeypatch.delenv("FORGEJO_TOKEN", raising=False)
    result = _invoke(runner_logs, ["474", "-j", "0", "--repo", REPO])
    assert result.exit_code == 0, result.output
    assert "log line" in result.stdout
    assert any(str(r.url).startswith(BROKER + LOGS_PATH) for r in requests)


def test_runner_logs_direct_base_when_unset(monkeypatch, runner_logs, recorded):
    requests, kwargs_seen = recorded
    _clear_broker(monkeypatch)
    monkeypatch.setenv("FORGEJO_TOKEN", "direct-tok")
    result = _invoke(runner_logs, ["474", "--repo", REPO])
    assert result.exit_code == 0, result.output
    assert requests
    for req in requests:
        assert str(req.url).startswith(DIRECT_API + "/")
        assert req.headers["authorization"] == "token direct-tok"
    # Direct clients keep httpx's default (trust_env=True), so proxy env applies.
    assert all(kw.get("trust_env", True) is True for kw in kwargs_seen)


def test_runner_logs_explicit_token_stays_direct(monkeypatch, runner_logs, recorded):
    requests, _ = recorded
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    result = _invoke(runner_logs, ["474", "--repo", REPO, "--token", "human-tok"])
    assert result.exit_code == 0, result.output
    for req in requests:
        assert str(req.url).startswith(DIRECT_API + "/")
        assert req.headers["authorization"] == "token human-tok"


def test_runner_logs_broker_mode_never_reads_op(monkeypatch, runner_logs, recorded):
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    monkeypatch.delenv("FORGEJO_TOKEN", raising=False)
    # _no_op (via the recorded fixture) would fail the run if op were invoked.
    result = _invoke(runner_logs, ["--repo", REPO, "-n", "1"])
    assert result.exit_code == 0, result.output
