"""Run attribution: which CI run a warrant is allowed to name.

Attribution comes from the forge's own answer to our dispatch POST and from
nowhere else. The defect this replaced (warrants #5 and #7 naming runs Erich
never authorized) came from inferring the run out of the workflow's run list,
where "the run we caused" and "the newest run there is" are indistinguishable.
So the cases below pin two things: that we ask for the run info, and that
every answer short of the forge naming a run produces no link at all.

See [[warrant-approval-gated-runs]] invariant 5.
"""

import json

import httpx
import pytest

import main


class FakeResponse:
    """Just enough httpx.Response for attribution: a status and a body."""

    def __init__(self, status_code: int, payload=None, text: str = ""):
        self.status_code = status_code
        self._payload = payload
        self.text = text

    def json(self):
        if self._payload is None:
            raise json.JSONDecodeError("no body", "", 0)
        return self._payload


@pytest.fixture(autouse=True)
def no_run_list(monkeypatch):
    """Attribution reads the dispatch response and nothing else. Any GET at
    all means we are back to inferring the run from a listing."""

    def forbidden(*args, **kwargs):
        raise AssertionError("attribution must not consult the forge's run list")

    monkeypatch.setattr(main.httpx, "get", forbidden)


def test_the_dispatch_asks_for_the_run_info(monkeypatch):
    """The whole fix is one request field. Drop it and the forge answers 204
    with no body, which is silent: dispatch still succeeds, links just stop."""
    sent = {}

    def fake_post(url, **kwargs):
        sent.update(kwargs["json"])
        return FakeResponse(201, {"id": 1232, "run_number": 724, "jobs": ["deploy"]})

    monkeypatch.setattr(main.httpx, "post", fake_post)

    main._dispatch("build-container.yaml", {"container": "warrant"})

    assert sent["return_run_info"] is True
    assert sent["inputs"] == {"container": "warrant"}
    assert sent["ref"] == "main"


def test_the_forge_names_the_run_it_created():
    """201 with a run number — the only case that may produce a link."""
    resp = FakeResponse(201, {"id": 1232, "run_number": 724, "jobs": ["build"]})

    number, url = main._run_from_dispatch(resp, "build-container.yaml")

    assert number == 724
    assert url.endswith("/actions/runs/724")


def test_a_bodyless_204_declines_to_link():
    """A forge that does not honour `return_run_info` still dispatches. The
    run is real and unidentifiable, and the warrant must say so."""
    resp = FakeResponse(204)

    number, url = main._run_from_dispatch(resp, "build-container.yaml")

    assert number is None
    assert url.endswith("actions?workflow=build-container.yaml")


def test_a_body_without_a_run_number_declines_to_link():
    resp = FakeResponse(201, {"id": 1232, "jobs": ["build"]})

    number, url = main._run_from_dispatch(resp, "build-container.yaml")

    assert number is None
    assert "actions?workflow=" in url


def test_a_null_run_number_declines_to_link():
    """Present but empty is not an answer."""
    resp = FakeResponse(201, {"id": 1232, "run_number": None})

    number, _ = main._run_from_dispatch(resp, "build-container.yaml")

    assert number is None


def test_an_unparseable_body_declines_to_link():
    """An HTML error page from a proxy, say. Never fails the dispatch."""
    resp = FakeResponse(201, None, text="<html>502</html>")

    number, url = main._run_from_dispatch(resp, "argocd-deploy.yaml")

    assert number is None
    assert url.endswith("actions?workflow=argocd-deploy.yaml")


def test_a_dispatch_that_never_answered_is_not_a_link(monkeypatch):
    """Transport failure: no response, so nothing to attribute."""

    def fake_post(url, **kwargs):
        raise httpx.ConnectError("boom")

    monkeypatch.setattr(main.httpx, "post", fake_post)

    with pytest.raises(httpx.HTTPError):
        main._dispatch("build-container.yaml", {})
