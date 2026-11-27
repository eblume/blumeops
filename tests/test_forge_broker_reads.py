"""Broker mode of the forge REST reads in `verify-runs`, `pending-deploys` and
`lint-auto-apply` (eblume/blumeops#2513).

With TALOS_BROKER_URL and TALOS_BROKER_TOKEN both set, forge GETs go to
<broker>/api/v1/... with a Bearer header, never run `op read`, and do not
need FORGEJO_TOKEN. With either unset, the direct path is unchanged.
"""

import importlib.machinery
import importlib.util
import pathlib
import subprocess
import sys

import httpx
import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
BROKER = "http://127.0.0.1:9999"
API = BROKER + "/api/v1"
REPO_PATH = "/api/v1/repos/eblume/blumeops"
DIRECT_BASE = "https://forge.ops.eblu.me/api/v1"


def _load(name: str):
    loader = importlib.machinery.SourceFileLoader(
        name.replace("-", "_"), str(ROOT / "mise-tasks" / name)
    )
    spec = importlib.util.spec_from_loader(loader.name, loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    # Register before exec: @dataclass looks the module up in sys.modules.
    sys.modules[loader.name] = module
    loader.exec_module(module)
    return module


@pytest.fixture
def verify_runs():
    return _load("verify-runs")


@pytest.fixture
def pending_deploys():
    return _load("pending-deploys")


@pytest.fixture
def lint_auto_apply():
    return _load("lint-auto-apply")


def _clear(monkeypatch):
    for var in ("TALOS_BROKER_URL", "TALOS_BROKER_TOKEN", "FORGEJO_TOKEN"):
        monkeypatch.delenv(var, raising=False)


@pytest.fixture
def recorder(monkeypatch):
    """Intercept every httpx.Client: record the requests and the constructor
    kwargs, answer with a canned body, and make `op` / subprocess.run fail."""
    requests: list[httpx.Request] = []
    kwargs_seen: list[dict] = []
    state = {"body": []}
    real_client = httpx.Client

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if "/pulls" in request.url.path:
            return httpx.Response(200, json=state["body"])
        if "/actions/tasks" in request.url.path:
            return httpx.Response(200, json={"workflow_runs": []})
        return httpx.Response(200, json={"encoding": "base64", "content": ""})

    def fake_client(*args, **kwargs):
        kwargs_seen.append(dict(kwargs))
        kwargs.pop("proxy", None)
        kwargs["transport"] = httpx.MockTransport(handler)
        return real_client(*args, **kwargs)

    def no_subprocess(*args, **kwargs):
        raise AssertionError(f"subprocess must not run in broker mode: {args[0]}")

    monkeypatch.setattr(httpx, "Client", fake_client)
    monkeypatch.setattr(subprocess, "run", no_subprocess)
    return requests, kwargs_seen, state


def _broker_env(monkeypatch):
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER + "/")
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")


# --- verify-runs -----------------------------------------------------------


def test_verify_runs_broker_reads_tasks_and_policy(monkeypatch, verify_runs, recorder):
    requests, kwargs_seen, _ = recorder
    _clear(monkeypatch)
    _broker_env(monkeypatch)
    with verify_runs.forge_client() as client:
        verify_runs.recent_runs(client)
        verify_runs.sha_policy(client)
    urls = [str(r.url) for r in requests]
    assert urls[0].startswith(API + "/repos/eblume/blumeops/actions/tasks")
    assert urls[1] == API + "/repos/eblume/blumeops/raw/main/warrant-policy.yaml"
    assert all(r.headers["authorization"] == "Bearer testtok" for r in requests)
    assert kwargs_seen[0]["trust_env"] is False


def test_verify_runs_broker_needs_no_forgejo_token(monkeypatch, verify_runs, recorder):
    _clear(monkeypatch)
    _broker_env(monkeypatch)

    def no_token():
        raise AssertionError("forge_token must not run in broker mode")

    monkeypatch.setattr(verify_runs, "forge_token", no_token)
    with verify_runs.forge_client():
        pass
    assert verify_runs.forge_api_base() == API


def test_verify_runs_direct_mode_unchanged(monkeypatch, verify_runs, recorder):
    requests, kwargs_seen, _ = recorder
    _clear(monkeypatch)
    monkeypatch.setenv("FORGEJO_TOKEN", "directtok")
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)  # URL alone is not broker mode
    assert verify_runs.forge_api_base() == DIRECT_BASE
    with verify_runs.forge_client() as client:
        verify_runs.recent_runs(client)
    (req,) = requests
    assert str(req.url).startswith(DIRECT_BASE + "/repos/eblume/blumeops/actions/tasks")
    assert req.headers["authorization"] == "token directtok"
    assert "trust_env" not in kwargs_seen[0]


# --- pending-deploys -------------------------------------------------------


def test_pending_deploys_broker_fetches_pulls(monkeypatch, pending_deploys, recorder):
    requests, kwargs_seen, state = recorder
    _clear(monkeypatch)
    _broker_env(monkeypatch)
    state["body"] = [
        {"number": 7, "head": {"ref": "ringtail-release-v1.2.3"}},
    ]
    with pending_deploys.forge_client(None) as client:
        prs = pending_deploys.fetch_open_prs(client)
    (req,) = requests
    assert str(req.url).startswith(API + "/repos/eblume/blumeops/pulls")
    assert req.headers["authorization"] == "Bearer testtok"
    assert kwargs_seen[0]["trust_env"] is False
    assert prs["ringtail"][0]["number"] == 7


def test_pending_deploys_direct_mode_unchanged(monkeypatch, pending_deploys, recorder):
    requests, kwargs_seen, state = recorder
    _clear(monkeypatch)
    state["body"] = []
    assert pending_deploys.forge_api_base() == DIRECT_BASE
    with pending_deploys.forge_client("directtok") as client:
        pending_deploys.fetch_open_prs(client)
    (req,) = requests
    assert str(req.url).startswith(DIRECT_BASE + "/repos/eblume/blumeops/pulls")
    assert req.headers["authorization"] == "token directtok"
    assert "trust_env" not in kwargs_seen[0]


# --- lint-auto-apply -------------------------------------------------------


def test_lint_auto_apply_broker_fetches_contents(
    monkeypatch, lint_auto_apply, recorder
):
    requests, kwargs_seen, _ = recorder
    _clear(monkeypatch)
    _broker_env(monkeypatch)
    with lint_auto_apply.api_client() as client:
        lint_auto_apply.fetch_file(client, "warrant-policy.yaml", "main")
    (req,) = requests
    assert (
        str(req.url)
        == API + "/repos/eblume/blumeops/contents/warrant-policy.yaml?ref=main"
    )
    assert req.headers["authorization"] == "Bearer testtok"
    assert kwargs_seen[0]["trust_env"] is False


def test_lint_auto_apply_broker_needs_no_forgejo_token(
    monkeypatch, lint_auto_apply, recorder
):
    _clear(monkeypatch)
    _broker_env(monkeypatch)

    def no_token():
        raise AssertionError("forge_token must not run in broker mode")

    monkeypatch.setattr(lint_auto_apply, "forge_token", no_token)
    with lint_auto_apply.api_client():
        pass


def test_lint_auto_apply_direct_mode_unchanged(monkeypatch, lint_auto_apply, recorder):
    requests, kwargs_seen, _ = recorder
    _clear(monkeypatch)
    monkeypatch.setenv("FORGEJO_TOKEN", "directtok")
    with lint_auto_apply.api_client() as client:
        lint_auto_apply.fetch_file(client, "warrant-policy.yaml", "main")
    (req,) = requests
    assert str(req.url).startswith(DIRECT_BASE + "/repos/eblume/blumeops/contents/")
    assert req.headers["authorization"] == "token directtok"
    assert "trust_env" not in kwargs_seen[0]


def test_verify_runs_warrant_requests_skipped_in_broker_mode(monkeypatch):
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "tok")

    def no_subprocess(*a, **k):
        raise AssertionError("broker mode must not run op")

    monkeypatch.setattr(subprocess, "run", no_subprocess)
    vr = _load("verify-runs")
    assert vr.warrant_requests() == {}
