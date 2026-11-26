"""Broker mode of `mise-tasks/agent-health` and `mise-tasks/agent-metrics`.

With TALOS_BROKER_URL and TALOS_BROKER_TOKEN both set, the request goes to the
broker with a Bearer header and neither `op` nor Authentik is touched. With
either unset, the direct path (mint_token + X-JWT-Assertion) is used as before.
"""

import importlib.machinery
import importlib.util
import json
import pathlib

import httpx
import pytest
import typer
from typer.testing import CliRunner

ROOT = pathlib.Path(__file__).resolve().parent.parent
BROKER = "http://127.0.0.1:9999"
RULES_PATH = "/grafana/api/prometheus/grafana/api/v1/rules"
QUERY_PATH = "/grafana/api/datasources/proxy/uid/prometheus/api/v1/query"
EMPTY_RULES = {"status": "success", "data": {"groups": []}}
EMPTY_QUERY = {"status": "success", "data": {"result": []}}


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
def health():
    return _load("agent-health")


@pytest.fixture
def metrics():
    return _load("agent-metrics")


@pytest.fixture
def broker_transport(monkeypatch):
    """Every httpx.Client gets a MockTransport that requires the Bearer header
    and records requests. Returns (requests, body) where `body` is the JSON the
    mock answers with. `op` raising proves broker mode never reads the vault."""
    requests: list[httpx.Request] = []
    state = {"body": EMPTY_RULES}
    real_client = httpx.Client

    def handler(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        if request.headers.get("authorization") != "Bearer testtok":
            return httpx.Response(401, text="nope")
        return httpx.Response(200, json=state["body"])

    def fake_client(*args, **kwargs):
        kwargs.pop("proxy", None)
        kwargs["transport"] = httpx.MockTransport(handler)
        return real_client(*args, **kwargs)

    def no_op(*args, **kwargs):
        raise AssertionError("op must not run in broker mode")

    monkeypatch.setattr(httpx, "Client", fake_client)
    monkeypatch.setattr("subprocess.run", no_op)
    return requests, state


def _clear_broker(monkeypatch):
    monkeypatch.delenv("TALOS_BROKER_URL", raising=False)
    monkeypatch.delenv("TALOS_BROKER_TOKEN", raising=False)


def _invoke(module, args):
    app = typer.Typer()
    app.command()(module.main)
    return CliRunner().invoke(app, args)


def test_health_broker_mode(monkeypatch, health, broker_transport):
    requests, _ = broker_transport
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER + "/")
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    result = _invoke(health, [])
    assert result.exit_code == 0, result.output
    (req,) = requests
    assert str(req.url) == BROKER + RULES_PATH
    assert req.headers["authorization"] == "Bearer testtok"
    assert "x-jwt-assertion" not in req.headers


def test_health_direct_mode_mints(monkeypatch, health):
    _clear_broker(monkeypatch)
    seen_headers: list[httpx.Headers] = []
    minted: list[int] = []

    def fake_client_for(url):
        def handler(request: httpx.Request) -> httpx.Response:
            seen_headers.append(request.headers)
            return httpx.Response(200, json=EMPTY_RULES)

        return httpx.Client(transport=httpx.MockTransport(handler))

    monkeypatch.setattr(health, "mint_token", lambda: minted.append(1) or "minted")
    monkeypatch.setattr(health, "client_for", fake_client_for)
    result = _invoke(health, [])
    assert result.exit_code == 0, result.output
    assert minted == [1]
    assert seen_headers[0]["x-jwt-assertion"] == "minted"
    assert "authorization" not in seen_headers[0]


def test_half_configured_broker_is_direct(monkeypatch, health, metrics):
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.delenv("TALOS_BROKER_TOKEN", raising=False)
    assert health.broker() is None
    assert metrics.broker() is None
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "   ")
    assert health.broker() is None

    # Half-configured broker must also take the direct (minting) path end to end.
    monkeypatch.delenv("TALOS_BROKER_TOKEN", raising=False)
    seen_headers: list[httpx.Headers] = []
    minted: list[int] = []

    def fake_client_for(url):
        def handler(request: httpx.Request) -> httpx.Response:
            seen_headers.append(request.headers)
            return httpx.Response(200, json=EMPTY_RULES)

        return httpx.Client(transport=httpx.MockTransport(handler))

    monkeypatch.setattr(health, "mint_token", lambda: minted.append(1) or "minted")
    monkeypatch.setattr(health, "client_for", fake_client_for)
    result = _invoke(health, [])
    assert result.exit_code == 0, result.output
    assert minted == [1]
    assert seen_headers[0]["x-jwt-assertion"] == "minted"
    assert "authorization" not in seen_headers[0]


def test_metrics_direct_mode_mints(monkeypatch, metrics):
    _clear_broker(monkeypatch)
    seen_headers: list[httpx.Headers] = []
    minted: list[int] = []

    def fake_client_for(url):
        def handler(request: httpx.Request) -> httpx.Response:
            seen_headers.append(request.headers)
            return httpx.Response(200, json=EMPTY_QUERY)

        return httpx.Client(transport=httpx.MockTransport(handler))

    monkeypatch.setattr(metrics, "mint_token", lambda: minted.append(1) or "minted")
    monkeypatch.setattr(metrics, "client_for", fake_client_for)
    # Metrics exits 1 on empty results by design.
    result = _invoke(metrics, ["up"])
    assert result.exit_code == 1, result.output
    assert minted == [1]
    assert seen_headers[0]["x-jwt-assertion"] == "minted"
    assert "authorization" not in seen_headers[0]


def test_broker_client_ignores_proxy_env(monkeypatch, health):
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    real_client = httpx.Client
    captured: list[dict] = []

    def recording_client(*args, **kwargs):
        captured.append(kwargs)
        kwargs["transport"] = httpx.MockTransport(
            lambda request: httpx.Response(200, json=EMPTY_RULES)
        )
        return real_client(*args, **kwargs)

    monkeypatch.setattr(httpx, "Client", recording_client)
    result = _invoke(health, [])
    assert result.exit_code == 0, result.output
    assert captured, "broker client was never constructed"
    assert any(kw.get("trust_env") is False for kw in captured)


def test_metrics_broker_mode(monkeypatch, metrics, broker_transport):
    requests, state = broker_transport
    state["body"] = {
        "status": "success",
        "data": {"result": [{"metric": {}, "value": [0, "1"]}]},
    }
    monkeypatch.setenv("TALOS_BROKER_URL", BROKER)
    monkeypatch.setenv("TALOS_BROKER_TOKEN", "testtok")
    result = _invoke(metrics, ["up", "--json"])
    assert result.exit_code == 0, result.output
    assert json.loads(result.stdout) == [{"metric": {}, "value": [0, "1"]}]
    (req,) = requests
    assert req.url.path == QUERY_PATH
    assert req.url.params["query"] == "up"
    assert req.headers["authorization"] == "Bearer testtok"
    assert "x-jwt-assertion" not in req.headers
