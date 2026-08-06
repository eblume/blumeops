"""/api/requests serializes the recorded run attribution.

`verify-runs` closes approval tasks from what warrant *recorded* at dispatch
— the forge naming the run via ``return_run_info`` — never by inferring runs
from the forge's run list (test_run_attribution has the history of why
inference is banned). That only works if the list endpoint actually exposes
the recorded link: until 0.3.4 it selected from ``requests`` alone, so
``run_number`` lived in the database and nowhere else.
"""

import json
import time

import main

SHA = "2558d0bb6944edf216ad3897b25e9dbb92f7e04e"


def _request(conn, status: str = "dispatched") -> int:
    cur = conn.execute(
        "INSERT INTO requests (created_at, requester, action, sha, inputs, why, pr, status)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        (time.time(), "agent-ringtail", "deploy-fly.yaml", SHA,
         json.dumps({"revision": SHA}), "test", 509, status),
    )
    return cur.lastrowid


def _warrant(conn, request_id: int, run_number: int | None) -> None:
    conn.execute(
        "INSERT INTO warrants (request_id, decision, decided_by, decided_at, action,"
        " sha, inputs, expires_at, consumed, run_number, run_url, dispatched_at)"
        " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (request_id, "approve", "erich", time.time(), "deploy-fly.yaml", SHA,
         json.dumps({"revision": SHA}), time.time() + 3600, 1, run_number,
         f"https://forge.eblu.me/eblume/blumeops/actions/runs/{run_number}"
         if run_number else None,
         time.time()),
    )


def _row(rows: list[dict], request_id: int) -> dict:
    return next(r for r in rows if r["id"] == request_id)


def test_dispatched_request_carries_its_run():
    with main.db() as conn:
        rid = _request(conn)
        _warrant(conn, rid, run_number=739)
    row = _row(main.list_requests(), rid)
    assert row["run_number"] == 739
    assert row["run_url"].endswith("/runs/739")
    assert row["decided_by"] == "erich"


def test_undecided_request_has_null_attribution():
    with main.db() as conn:
        rid = _request(conn, status="pending")
    row = _row(main.list_requests(), rid)
    assert row["run_number"] is None
    assert row["decision"] is None


def test_latest_warrant_wins():
    """A re-decided request reports its newest warrant, not its first."""
    with main.db() as conn:
        rid = _request(conn)
        _warrant(conn, rid, run_number=None)
        _warrant(conn, rid, run_number=740)
    row = _row(main.list_requests(), rid)
    assert row["run_number"] == 740


def test_status_filter_still_applies():
    with main.db() as conn:
        rid = _request(conn, status="pending")
    ids = {r["id"] for r in main.list_requests(status="pending")}
    assert rid in ids
    assert all(r["status"] == "pending" for r in main.list_requests(status="pending"))
