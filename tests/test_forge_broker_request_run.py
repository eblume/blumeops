"""Broker mode of `mise-tasks/request-run` (eblume/blumeops#2513).

With TALOS_BROKER_URL and TALOS_BROKER_TOKEN both set, the READ path goes to
the talos broker with a Bearer header: forge reads under `<url>/api/v1`, the
runner preflight under `<url>/grafana/...`. Neither FORGEJO_TOKEN nor `op` is
needed for that. The PR-comment write and the horkos warrant filing are
unchanged. With either env var unset, the direct path is unchanged.
"""

import time

import httpx
import pytest
import typer
from typer.testing import CliRunner

BROKER = "http://127.0.0.1:9999"
TOKEN = "testtok"
SHA = "a" * 40
REPO_PATH = "/api/v1/repos/eblume/blumeops"
GRAFANA_PATH = "/api/datasources/proxy/uid/prometheus/api/v1/query"
GRAFANA_DIRECT = "https://grafana.ops.eblu.me" + GRAFANA_PATH
WORKFLOW = "jobs:\n  a:\n    runs-on: one\n    steps: []\n"
POLICY = (
    "actions:\n"
    "  build.yaml:\n"
    "    class: warrant\n"
    "    binds_sha: ref\n"
    "    inputs:\n"
    "      ref:\n"
    "        required: true\n"
    "        pattern: '[0-9a-f]{40}'\n"
)
PR = {
    "number": 7,
    "title": "t",
    "body": "",
    "head": {"sha": SHA},
    "base": {"repo": {"full_name": "eblume/blumeops"}},
}
ARGS = ["build.yaml", SHA, "--pr", "7", "-i", f"ref={SHA}", "--why", "x"]


def _route(request: httpx.Request, now: float) -> httpx.Response:
    p = request.url.path
    if request.method == "POST" and p.endswith("/issues/7/comments"):
        return httpx.Response(201, json={"html_url": "https://x/c/1"})
    if p.endswith("/api/v1/query"):
        if "info" in request.url.params.get("query", ""):
            rows = [{"metric": {"runner": "r1", "labels": "one"}, "value": [0, ""]}]
        else:
            rows = [{"metric": {"runner": "r1"}, "value": [0, str(now)]}]
        return httpx.Response(200, json={"status": "success", "data": {"result": rows}})
    if p.endswith("/raw/main/.forgejo/workflows/build.yaml"):
        return httpx.Response(200, text=WORKFLOW)
    if p.endswith("/raw/main/warrant-policy.yaml"):
        return httpx.Response(200, text=POLICY)
    if p.endswith("/pulls/7/files"):
        return httpx.Response(200, json=[])
    if p.endswith("/pulls/7"):
        return httpx.Response(200, json=PR)
    if p.endswith("/users/eblume"):
        return httpx.Response(200, json={"id": 1})
    if p.endswith("/repos/eblume/blumeops"):
        return httpx.Response(200, json={"id": 42})
    return httpx.Response(404, text=f"unrouted {p}")


@pytest.fixture
def env_clean(monkeypatch):
    for var in (
        "TALOS_BROKER_URL",
        "TALOS_BROKER_TOKEN",
        "FORGEJO_TOKEN",
        "OP_SERVICE_ACCOUNT_TOKEN",
        "ALL_PROXY",
    ):
        monkeypatch.delenv(var, raising=False)
    return monkeypatch


@pytest.fixture
def wire(monkeypatch):
    """Every httpx.Client gets a MockTransport. Returns the list of requests
    seen, and the `now` used for runner last-online samples. Any subprocess
    call (incl. `op`) raises, so a read path that shells out fails loudly."""
    seen: list[httpx.Request] = []
    now = [time.time()]
    real_client = httpx.Client

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return _route(request, now[0])

    def fake_client(*args, **kwargs):
        kwargs.pop("proxy", None)
        kwargs["transport"] = httpx.MockTransport(handler)
        return real_client(*args, **kwargs)

    def no_subprocess(*args, **kwargs):
        raise AssertionError(f"subprocess must not run: {args[0] if args else kwargs}")

    monkeypatch.setattr(httpx, "Client", fake_client)
    monkeypatch.setattr("subprocess.run", no_subprocess)
    return seen, now


def _invoke(module, args):
    app = typer.Typer()
    app.command()(module.main)
    return CliRunner().invoke(app, args)


def _stub_filing(monkeypatch, module):
    """The warrant mirror and heph task are the unchanged filing path (they
    need op/heph); stub them so `main` can run end to end."""
    monkeypatch.setattr(module, "mirror_to_warrant", lambda *a, **k: None)
    monkeypatch.setattr(module, "file_heph_task", lambda *a, **k: None)


def test_broker_helpers(env_clean, request_run):
    assert request_run.broker() is None
    env_clean.setenv("TALOS_BROKER_URL", BROKER + "/")
    assert request_run.broker() is None  # half-configured stays direct
    env_clean.setenv("TALOS_BROKER_TOKEN", TOKEN)
    assert request_run.broker() == (BROKER + "/", TOKEN)
    assert request_run.forge_api_base() == BROKER + "/api/v1"
    assert request_run.blumeops_api() == BROKER + REPO_PATH


def test_unset_keeps_direct_bases(env_clean, request_run):
    assert request_run.forge_api_base() == "https://forge.ops.eblu.me/api/v1"
    assert request_run.blumeops_api() == request_run.REPO_API
    assert (
        request_run.REPO_API == "https://forge.ops.eblu.me/api/v1/repos/eblume/blumeops"
    )


def test_broker_forge_reads_go_to_broker_with_bearer(
    env_clean, request_run, wire, monkeypatch
):
    seen, _ = wire
    env_clean.setenv("TALOS_BROKER_URL", BROKER)
    env_clean.setenv("TALOS_BROKER_TOKEN", TOKEN)
    _stub_filing(monkeypatch, request_run)
    pat_calls: list[int] = []
    monkeypatch.setattr(
        request_run, "forge_token", lambda: pat_calls.append(1) or "pat"
    )
    result = _invoke(request_run, ARGS)
    assert result.exit_code == 0, result.output
    # Only the PR-comment write needs the PAT; every read ran without it.
    assert pat_calls == [1]

    reads = [r for r in seen if r.method == "GET" and r.url.path.startswith("/api/v1/")]
    assert reads
    for req in reads:
        assert str(req.url).startswith(BROKER + "/api/v1/"), str(req.url)
        assert req.headers["authorization"] == f"Bearer {TOKEN}"
    paths = {r.url.path for r in reads}
    assert REPO_PATH + "/raw/main/.forgejo/workflows/build.yaml" in paths
    assert REPO_PATH + "/raw/main/warrant-policy.yaml" in paths
    assert REPO_PATH + "/pulls/7" in paths
    assert REPO_PATH + "/pulls/7/files" in paths
    assert "/api/v1/users/eblume" in {r.url.path for r in reads}


def test_broker_mode_write_is_direct_pat(env_clean, request_run, wire, monkeypatch):
    seen, _ = wire
    env_clean.setenv("TALOS_BROKER_URL", BROKER)
    env_clean.setenv("TALOS_BROKER_TOKEN", TOKEN)
    env_clean.setenv("FORGEJO_TOKEN", "pat")
    _stub_filing(monkeypatch, request_run)
    result = _invoke(request_run, ARGS)
    assert result.exit_code == 0, result.output
    posts = [r for r in seen if r.method == "POST"]
    assert len(posts) == 1
    assert (
        str(posts[0].url)
        == "https://forge.ops.eblu.me/api/v1/repos/eblume/blumeops/issues/7/comments"
    )
    assert posts[0].headers["authorization"] == "token pat"


def test_broker_preflight_reads_grafana_via_broker_no_op(
    env_clean, request_run, wire, monkeypatch
):
    seen, _ = wire
    env_clean.setenv("TALOS_BROKER_URL", BROKER)
    env_clean.setenv("TALOS_BROKER_TOKEN", TOKEN)

    def no_warrant(c):
        raise AssertionError("_warrant_bearer must not run on the broker preflight")

    monkeypatch.setattr(request_run, "_warrant_bearer", no_warrant)
    with httpx.Client() as c:
        request_run.preflight_runner_served(
            c, None, WORKFLOW, "build.yaml", now=time.time()
        )
    grafana = [r for r in seen if r.url.path.endswith(GRAFANA_PATH)]
    assert len(grafana) == 2
    for req in grafana:
        assert str(req.url).startswith(BROKER + "/grafana/"), str(req.url)
        assert req.headers["authorization"] == f"Bearer {TOKEN}"
        assert "x-jwt-assertion" not in req.headers


def test_broker_preflight_fail_closed(env_clean, request_run, monkeypatch):
    env_clean.setenv("TALOS_BROKER_URL", BROKER)
    env_clean.setenv("TALOS_BROKER_TOKEN", TOKEN)

    def unreachable(*a, **k):
        raise httpx.ConnectError("broker down")

    monkeypatch.setattr(httpx.Client, "get", unreachable)
    with httpx.Client() as c, pytest.raises(request_run.PreflightUnreachable):
        request_run.preflight_runner_served(c, None, WORKFLOW, "build.yaml", now=0)


def test_direct_mode_unchanged(env_clean, request_run, wire, monkeypatch):
    seen, _ = wire
    env_clean.setenv("FORGEJO_TOKEN", "pat")
    minted: list[int] = []

    def fake_mint(c):
        minted.append(1)
        return "minted"

    monkeypatch.setattr(request_run, "_warrant_bearer", fake_mint)
    _stub_filing(monkeypatch, request_run)
    result = _invoke(request_run, ARGS)
    assert result.exit_code == 0, result.output
    assert minted == [1]

    forge = [r for r in seen if r.url.host == "forge.ops.eblu.me"]
    assert forge
    for req in forge:
        assert str(req.url).startswith("https://forge.ops.eblu.me/api/v1/")
        # The preflight's _api_id lookups (repo/user ids) use the unauthenticated
        # ops client in direct mode, as before; everything else carries the PAT.
        if req.url.path in (REPO_PATH, "/api/v1/users/eblume"):
            assert "authorization" not in req.headers
        else:
            assert req.headers["authorization"] == "token pat"
    grafana = [r for r in seen if r.url.path.endswith(GRAFANA_PATH)]
    assert len(grafana) == 2
    for req in grafana:
        assert str(req.url).startswith(GRAFANA_DIRECT)
        assert req.headers["x-jwt-assertion"] == "minted"
        assert "authorization" not in req.headers
