"""Fixture-based tests for the authentik blueprint-state exporter.

Replays the API fixtures shipped with the container
(``containers/authentik-blueprint-exporter/fixtures/`` — synthetic
responses in authentik's real pagination shape, see the README there)
through the exporter's own snapshot logic and asserts the metric
semantics the alert rules rely on:

* ``authentik_blueprint_status{status="error"}`` keyed on ``path``
  survives the hourly delete/re-create cycle (delete, re-create with a
  new pk) instead of resetting — eblume/blumeops#1444, plan change 1.
* A 200 response with zero instances (an RBAC role that never bound)
  maps to ``collector_up = 0`` while the previous snapshot and its error
  states stay in place — plan change 2.
* The poll asks ``?page_size=500``, follows ``pagination.next`` as
  ``?page=N`` (keeping page_size) until it is 0, and reports the full
  instance count.

Run via ``mise run exporter-self-test``.
"""

import importlib.util
import json
import pathlib

import pytest

EXPORTER = pathlib.Path(__file__).parent
FIXTURES = EXPORTER / "fixtures"


def _exporter():
    spec = importlib.util.spec_from_file_location(
        "authentik_blueprint_exporter", EXPORTER / "exporter.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _load_pages(name):
    data = json.loads((FIXTURES / name).read_text())
    return data["pages"]


def _metric(rendered, family, labels=""):
    needle = f"{family}{labels}"
    for line in rendered.splitlines():
        if line.startswith(needle):
            return line
    return None


def test_error_state_survives_delete_and_recreate():
    exp = _exporter()
    snap = exp.BlueprintState()

    # Poll 1: the error instance is present (pk 99).
    inst, count = exp.load_snapshot(_load_pages("poll-applied.json"))
    snap.record_poll(inst, count, now=1000)
    out = snap.render()
    assert _metric(
        out,
        'authentik_blueprint_status{name="stale-builtin",path="system/stale.md",status="error"}',
    )
    assert (
        _metric(out, "authentik_blueprint_collector_up")
        == "authentik_blueprint_collector_up 1.0"
    )

    # Poll 2: clear_failed_blueprints deleted it; discovery has not
    # re-created it yet. The path must STAY in error state.
    inst, count = exp.load_snapshot(_load_pages("poll-deleted.json"))
    snap.record_poll(inst, count, now=2000)
    out = snap.render()
    assert _metric(
        out,
        'authentik_blueprint_status{name="",path="system/stale.md",status="error"}',
    )

    # Poll 3: re-created under a new pk, still error.
    inst, count = exp.load_snapshot(_load_pages("poll-recreated.json"))
    snap.record_poll(inst, count, now=3000)
    out = snap.render()
    assert _metric(
        out,
        'authentik_blueprint_status{name="stale-builtin",path="system/stale.md",status="error"}',
    )
    # Exactly one series for the path (no stale pk/old-name ghost).
    stale = [
        l
        for l in out.splitlines()
        if l.startswith("authentik_blueprint_status") and 'path="system/stale.md"' in l
    ]
    assert len(stale) == 1


def test_empty_list_is_a_failed_poll():
    exp = _exporter()
    snap = exp.BlueprintState()

    # Establish a real snapshot containing an error path first.
    inst, count = exp.load_snapshot(_load_pages("poll-applied.json"))
    snap.record_poll(inst, count, now=1000)
    assert count == 29  # 28 healthy + 1 error

    # A 200 with zero results (RBAC role never bound) must not read as
    # "healthy empty": collector_up drops to 0, the previous snapshot
    # and its error state survive, and the count floor metric reflects
    # the last *successful* poll.
    inst, count = exp.load_snapshot(_load_pages("poll-empty.json"))
    snap.record_poll(inst, count, now=2000)
    out = snap.render()
    assert (
        _metric(out, "authentik_blueprint_collector_up")
        == "authentik_blueprint_collector_up 0.0"
    )
    assert _metric(
        out,
        'authentik_blueprint_status{name="stale-builtin",path="system/stale.md",status="error"}',
    )
    assert (
        _metric(out, "authentik_blueprint_instances")
        == "authentik_blueprint_instances 29.0"
    )  # floor metric keeps last successful poll


def test_snapshot_aggregates_all_pages():
    exp = _exporter()
    pages = _load_pages("poll-applied.json")
    assert len(pages) > 1, "fixture must span more than one page"
    inst, count = exp.load_snapshot(pages)
    # The API count (first page) and the aggregated instance count agree.
    assert count == len(pages[0]["results"]) + len(pages[1]["results"])
    snap = exp.BlueprintState()
    snap.record_poll(inst, count, now=1000)
    assert (
        _metric(snap.render(), "authentik_blueprint_instances")
        == f"authentik_blueprint_instances {count}.0"
    )


def test_healthy_recovery_exits_error_state():
    exp = _exporter()
    snap = exp.BlueprintState()

    # In error, then recovered (re-created healthy, new pk).
    inst, count = exp.load_snapshot(_load_pages("poll-applied.json"))
    snap.record_poll(inst, count, now=1000)
    inst, count = exp.load_snapshot(_load_pages("poll-recovered.json"))
    snap.record_poll(inst, count, now=2000)
    out = snap.render()
    stale = [
        l
        for l in out.splitlines()
        if l.startswith("authentik_blueprint_status") and 'path="system/stale.md"' in l
    ]
    assert len(stale) == 1, stale
    assert 'status="successful"' in stale[0]
    # No name="" ghost for the recovered path.
    assert 'name="",path="system/stale.md"' not in out


def test_absent_error_carry_expires():
    """A path absent for more than ERROR_CARRY_SECONDS stops alerting.

    A permanently removed failing blueprint must not render status=error
    forever: the carry is bounded to the alert's 2h recency window.
    """
    exp = _exporter()
    snap = exp.BlueprintState()

    inst, count = exp.load_snapshot(_load_pages("poll-applied.json"))
    snap.record_poll(inst, count, now=1000)
    # Deleted at 1000; still carried well inside the window.
    inst, count = exp.load_snapshot(_load_pages("poll-deleted.json"))
    snap.record_poll(inst, count, now=1000 + 3600)
    assert _metric(
        snap.render(),
        'authentik_blueprint_status{name="",path="system/stale.md",status="error"}',
    )
    # Absent past the carry window: gone.
    snap.record_poll(inst, count, now=1000 + 3600 + exp.ERROR_CARRY_SECONDS + 1)
    out = snap.render()
    stale = [
        l
        for l in out.splitlines()
        if l.startswith("authentik_blueprint_status") and 'path="system/stale.md"' in l
    ]
    assert not stale


def test_fetch_all_builds_page_urls_and_sends_bearer():
    """fetch_all against a stub urlopen that serves ?page=N.

    authentik's pagination.next is a *page number* (0 on the last page),
    not a URL, so this pins the URL-building: ?page_size=500 first, then
    ?page=N&page_size=500 until next is 0.
    """
    exp = _exporter()
    pages = _load_pages("poll-applied.json")
    root = "http://rec/api/v3/managed/blueprints/"
    by_page = {"1": pages[0], "2": pages[1]}

    class _Resp:
        def __init__(self, page):
            self._page = page

        def read(self):
            return json.dumps(self._page).encode("utf-8")

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    seen = []

    def fake_urlopen(req, timeout=None, context=None):
        # Route the stub by the ?page=N parameter: the first request
        # (with ?page_size=500, no page param) is page 1, follow-ups are
        # ?page=N.
        parts = req.full_url.split("?")
        query = (
            dict(q.split("=") for q in parts[1].split("&")) if len(parts) > 1 else {}
        )
        page = query.get("page", "1")
        assert req.full_url.startswith(root), req.full_url
        assert page in by_page, f"unexpected request {req.full_url}"
        seen.append((req.full_url, req.headers.get("Authorization")))
        return _Resp(by_page[page])

    got = exp.fetch_all("http://rec", "tok", urlopen=fake_urlopen)
    assert [g["pagination"]["current"] for g in got] == [1, 2]
    # Bearer scheme (the Token scheme 401s against authentik).
    assert all(auth == "Bearer tok" for _, auth in seen)
    # The first request asks for the large page; page 2 is built from
    # pagination.next as ?page=N and keeps page_size (dropping it would
    # make the server default page size kick in on page 2).
    assert seen[0][0] == root + "?page_size=500"
    assert seen[1][0] == root + "?page=2&page_size=500"
    _, count = exp.load_snapshot(got)
    assert count == 29


def test_fetch_all_fails_fast_on_stale_next():
    """A pagination.next that does not advance past current is a loop."""
    exp = _exporter()
    stale = {
        "pagination": {
            "next": 2,
            "previous": 1,
            "count": 29,
            "current": 2,
            "total_pages": 2,
            "start_index": 1,
            "end_index": 20,
        },
        "results": [],
        "autocomplete": {},
    }
    resp = json.dumps(stale).encode("utf-8")

    class _R:
        def read(self):
            return resp

        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

    def fake_urlopen(req, timeout=None, context=None):
        return _R()

    with pytest.raises(RuntimeError, match="did not advance"):
        exp.fetch_all("http://rec", "tok", urlopen=fake_urlopen)
