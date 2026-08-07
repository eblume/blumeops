"""Superseding retires a request and can only ever reduce.

The queue's failure mode without this: a PR takes review feedback, the agent
files a second request at the new head SHA, and the first one sits pending
next to it — two near-identical entries, one of them dead, and the approver
left to work out which. Warrant #21/#22 on PR #525 is the case that filed the
ticket.

The load-bearing test here is `test_superseded_request_cannot_be_approved`.
Supersede is the only write an agent identity may make to an existing request
(invariant 4), so what matters is not that it sets a label but that the label
takes the request *out* of the approvable set — no warrant, no dispatch, no
path back to pending.
"""

import json
import time

import pytest
from fastapi import HTTPException

import main

SHA = "8c05eb4c9e2f0a1b3d5e7f9012345678abcdef01"
NEW_SHA = "bcb2b55a1c3e5079bdf2468ace13579bdf024680"
ME = "agent-ringtail"


@pytest.fixture(autouse=True)
def as_agent(monkeypatch):
    """Every test here calls the route directly, so stand in for the JWKS
    verification with a fixed identity — the scoping rules are what's under
    test, not the token parsing."""
    monkeypatch.setattr(main, "verify_agent", lambda authorization: ME)


def _request(requester: str = ME, status: str = "pending", sha: str = SHA) -> int:
    with main.db() as conn:
        cur = conn.execute(
            "INSERT INTO requests (created_at, requester, action, sha, inputs, why,"
            " pr, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (time.time(), requester, "build-container.yaml", sha,
             json.dumps({"container": "agent-ws"}), "test", 525, status),
        )
        return cur.lastrowid


def _row(req_id: int):
    with main.db() as conn:
        return conn.execute(
            "SELECT * FROM requests WHERE id = ?", (req_id,)
        ).fetchone()


def test_supersede_retires_the_old_request_and_names_its_replacement():
    old, new = _request(), _request(sha=NEW_SHA)
    result = main.supersede(old, main.Supersede(by=new))
    assert result["status"] == "superseded"
    assert result["superseded_by"] == new
    row = _row(old)
    assert row["status"] == "superseded"
    assert row["superseded_by"] == new


def test_supersede_returns_the_old_requests_coordinates():
    """request-run annotates the old PR comment and closes the heph task it
    filed; both need the retired request's own action/sha/pr, not the new
    one's."""
    old, new = _request(), _request(sha=NEW_SHA)
    result = main.supersede(old, main.Supersede(by=new))
    assert (result["action"], result["sha"], result["pr"]) == (
        "build-container.yaml", SHA, 525,
    )


def test_superseded_request_cannot_be_approved():
    old, new = _request(), _request(sha=NEW_SHA)
    main.supersede(old, main.Supersede(by=new))
    with pytest.raises(HTTPException) as exc:
        main._decide(old, "approve", "", {"username": "erich"})
    assert exc.value.status_code == 409
    with main.db() as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM warrants WHERE request_id = ?", (old,)
        ).fetchone()[0] == 0


def test_cannot_supersede_another_identitys_request():
    theirs, mine = _request(requester="someone-else"), _request()
    with pytest.raises(HTTPException) as exc:
        main.supersede(theirs, main.Supersede(by=mine))
    assert exc.value.status_code == 403
    assert _row(theirs)["status"] == "pending"


def test_cannot_supersede_a_decided_request():
    """A human decision is not an agent's to undo — approved, denied and
    dispatched are all terminal here."""
    decided, new = _request(status="approved"), _request(sha=NEW_SHA)
    with pytest.raises(HTTPException) as exc:
        main.supersede(decided, main.Supersede(by=new))
    assert exc.value.status_code == 409
    assert _row(decided)["status"] == "approved"


def test_successor_must_exist():
    old = _request()
    with pytest.raises(HTTPException) as exc:
        main.supersede(old, main.Supersede(by=old + 10_000))
    assert exc.value.status_code == 400
    assert _row(old)["status"] == "pending"


def test_request_cannot_supersede_itself():
    old = _request()
    with pytest.raises(HTTPException) as exc:
        main.supersede(old, main.Supersede(by=old))
    assert exc.value.status_code == 400
    assert _row(old)["status"] == "pending"


def test_unknown_request_is_a_404():
    with pytest.raises(HTTPException) as exc:
        main.supersede(9_999_999, main.Supersede(by=_request()))
    assert exc.value.status_code == 404
