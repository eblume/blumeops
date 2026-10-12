"""Runner-availability preflight of request-run (eblume/blumeops#1515)."""

import httpx
import pytest
import typer

NOW = 1_800_000_000.0
ONLINE = NOW - 60
OFFLINE = NOW - 3600


def info_row(runner, labels, scope=None):
    row = {"runner": runner, "labels": labels}
    if scope is not None:
        row["scope"] = scope
    return row


def last_row(runner, ts):
    return {"runner": runner, "__value__": ts}


def _prom_response(rows):
    """Prometheus instant-query JSON. The sample value comes from each row's
    `__value__` key ('' when absent — info rows don't carry one)."""
    return {
        "status": "success",
        "data": {
            "result": [
                {
                    "metric": {k: v for k, v in row.items() if k != "__value__"},
                    "value": [0, str(row.get("__value__", ""))],
                }
                for row in rows
            ]
        },
    }


class _R:
    def __init__(self, status_code=200, text="", payload=None):
        self.status_code = status_code
        self.text = text
        self._payload = payload

    def json(self):
        return self._payload or {}

    def raise_for_status(self):
        pass


class FakeClient:
    """Stands in for httpx.Client on the preflight's two paths."""

    def __init__(self, info_rows=None, last_rows=None, body=None, query_error=None):
        self.info_rows = info_rows or []
        self.last_rows = last_rows or []
        self.body = body
        self.query_error = query_error
        self.posts = []

    def get(self, url, params=None, headers=None):
        if url.endswith("/api/v1/query"):
            if self.query_error is not None:
                raise self.query_error
            q = (params or {}).get("query", "")
            rows = self.info_rows if "info" in q else self.last_rows
            return _R(payload=_prom_response(rows))
        if "/raw/main/.forgejo/workflows/" in url:
            if self.body is None:
                return _R(status_code=404)
            return _R(text=self.body)
        return _R()

    def post(self, url, data=None, headers=None, json=None, timeout=None):
        self.posts.append({"url": url, "headers": headers})
        return _R(payload={"access_token": "fake-bearer"})


class _ErrRecorder:
    """Stands in for request_run.err — collect what would be printed to
    stderr. Rich binds its stream at construction, so a capsys assert would
    read the wrong file for a session-scoped import; replacing the module
    global is the shape the rest of the suite uses for `console`."""

    def __init__(self):
        self.lines = []

    def print(self, *args, **kwargs):
        self.lines.append(" ".join(str(a) for a in args))


@pytest.fixture
def recorded_err(request_run, monkeypatch):
    rec = _ErrRecorder()
    monkeypatch.setattr(request_run, "err", rec)
    return rec


def _stderr(rec):
    return "\n".join(rec.lines)


WORKFLOW_BODY = (
    "jobs:\n"
    "  a:\n"
    "    runs-on: one\n"
    "    steps: []\n"
    "  b:\n"
    "    runs-on: [one, two]\n"
    "    steps: []\n"
    "  c:\n"
    "    steps: []\n"
)


def body_for(labels):
    if isinstance(labels, str):
        labels = [labels]
    return (
        "jobs:\n  j:\n    runs-on: "
        + (labels[0] if len(labels) == 1 else "[" + ", ".join(labels) + "]")
        + "\n    steps: []\n"
    )


def test_parse_runs_on_union_in_order(request_run):
    assert request_run._parse_runs_on(WORKFLOW_BODY) == ["one", "two"]


def test_parse_runs_on_no_jobs(request_run):
    assert request_run._parse_runs_on("jobs: {}\n") == []


def test_workflow_on_main_404_is_none(request_run):
    assert request_run.workflow_on_main(FakeClient(body=None), "x.yaml") is None


def test_workflow_on_main_returns_body(request_run):
    assert (
        request_run.workflow_on_main(FakeClient(body="jobs: {}\n"), "x.yaml")
        == "jobs: {}\n"
    )


def test_no_runner_advertises_label(request_run, recorded_err):
    client = FakeClient(
        info_rows=[info_row("r1", "self-hosted,linux")],
        last_rows=[last_row("r1", ONLINE)],
    )
    with pytest.raises(typer.Exit):
        request_run.preflight_runner_served(
            client, "fake-bearer", body_for("missing"), "w.yaml", now=NOW
        )
    out = _stderr(recorded_err)
    assert "no runner advertises this label at all" in out
    assert "missing" in out


def test_offline_serving_runner_is_refused(request_run, recorded_err):
    client = FakeClient(
        info_rows=[info_row("r1", "self-hosted,linux")],
        last_rows=[last_row("r1", OFFLINE)],
    )
    with pytest.raises(typer.Exit):
        request_run.preflight_runner_served(
            client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
        )
    out = _stderr(recorded_err)
    assert "r1" in out
    assert "offline" in out


def test_absent_last_online_counts_as_offline(request_run, recorded_err):
    client = FakeClient(
        info_rows=[info_row("r1", "self-hosted,linux")],
        last_rows=[],
    )
    with pytest.raises(typer.Exit):
        request_run.preflight_runner_served(
            client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
        )
    out = _stderr(recorded_err)
    assert "no last-online sample" in out
    assert "offline" in out


def test_scope_aware_runner_scoped_elsewhere_refused(request_run, recorded_err):
    client = FakeClient(
        info_rows=[info_row("r1", "linux", scope="eblume/talos")],
        last_rows=[last_row("r1", ONLINE)],
    )
    with pytest.raises(typer.Exit):
        request_run.preflight_runner_served(
            client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
        )
    out = _stderr(recorded_err)
    assert "scoped to another repo" in out
    assert "eblume/talos" in out


def test_scope_aware_runner_scoped_to_blumeops_ok(request_run):
    client = FakeClient(
        info_rows=[info_row("r1", "linux", scope="eblume/blumeops")],
        last_rows=[last_row("r1", ONLINE)],
    )
    request_run.preflight_runner_served(
        client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
    )


def test_scope_aware_runner_instance_scope_ok(request_run):
    # #1530: an unscoped runner is exported as scope="instance" — it serves
    # every repo, so it must not be vetoed as scoped elsewhere.
    client = FakeClient(
        info_rows=[info_row("r1", "linux", scope="instance")],
        last_rows=[last_row("r1", ONLINE)],
    )
    request_run.preflight_runner_served(
        client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
    )


def test_scope_aware_runner_owner_scope_ok(request_run):
    # #1530: scope="eblume" (owner-scoped) covers this repo's owner, so it serves.
    client = FakeClient(
        info_rows=[info_row("r1", "linux", scope="eblume")],
        last_rows=[last_row("r1", ONLINE)],
    )
    request_run.preflight_runner_served(
        client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
    )


def test_scope_aware_runner_sibling_repo_refused(request_run, recorded_err):
    # #1530: scope="eblume/other-repo" is a different repo — it does not serve.
    client = FakeClient(
        info_rows=[info_row("r1", "linux", scope="eblume/other-repo")],
        last_rows=[last_row("r1", ONLINE)],
    )
    with pytest.raises(typer.Exit):
        request_run.preflight_runner_served(
            client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
        )
    out = _stderr(recorded_err)
    assert "scoped to another repo" in out
    assert "eblume/other-repo" in out


def test_scope_aware_mixed_instance_and_sibling(request_run):
    # An instance-wide and a sibling-repo runner share the label; the
    # instance runner makes it served, the sibling must not veto it.
    client = FakeClient(
        info_rows=[
            info_row("r1", "linux", scope="instance"),
            info_row("r2", "linux", scope="eblume/other-repo"),
        ],
        last_rows=[last_row("r1", ONLINE), last_row("r2", ONLINE)],
    )
    request_run.preflight_runner_served(
        client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
    )


def test_mixed_fleet_eligible_runner_passes(request_run):
    client = FakeClient(
        info_rows=[
            info_row("r1", "linux", scope="eblume/blumeops"),
            info_row("r2", "linux", scope="eblume/talos"),
        ],
        last_rows=[last_row("r1", ONLINE), last_row("r2", ONLINE)],
    )
    request_run.preflight_runner_served(
        client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
    )


def test_scope_aware_fleet_unscoped_runner_ok(request_run):
    client = FakeClient(
        info_rows=[
            info_row("r1", "linux"),
            info_row("r2", "windows", scope="eblume/talos"),
        ],
        last_rows=[last_row("r1", ONLINE)],
    )
    request_run.preflight_runner_served(
        client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
    )


def test_no_scope_keys_legacy_fallback_ok(request_run):
    client = FakeClient(
        info_rows=[info_row("r1", "linux")],
        last_rows=[last_row("r1", ONLINE)],
    )
    request_run.preflight_runner_served(
        client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
    )


def test_only_unserved_label_reported(request_run, recorded_err):
    client = FakeClient(
        info_rows=[info_row("r1", "linux")],
        last_rows=[last_row("r1", ONLINE)],
    )
    with pytest.raises(typer.Exit):
        request_run.preflight_runner_served(
            client, "fake-bearer", body_for(["linux", "missing"]), "w.yaml", now=NOW
        )
    out = _stderr(recorded_err)
    assert out.count("no runner advertises this label at all") == 1
    assert "missing" in out


def test_metrics_query_failure_raises_preflight_unreachable(request_run):
    client = FakeClient(
        query_error=httpx.ConnectError(
            "boom", request=httpx.Request("GET", "https://grafana.ops.eblu.me")
        )
    )
    with pytest.raises(request_run.PreflightUnreachable):
        request_run.preflight_runner_served(
            client, "fake-bearer", body_for("linux"), "w.yaml", now=NOW
        )
