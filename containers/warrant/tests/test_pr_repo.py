"""The attached PR can live outside blumeops.

`request-run --repo` files a request whose PR is, say, the eblume/talos PR
whose change the bound blumeops commit carries. Until 0.4.1 the queue stored
only the PR's #N and linked it against blumeops — so an approver reading
request "PR #12" was pointed at a different change entirely.
"""

import pytest

import main

SHA = "8c05eb4c9e2f0a1b3d5e7f9012345678abcdef01"
ME = "agent-ringtail"


@pytest.fixture(autouse=True)
def as_agent(monkeypatch):
    """The routes verify the Bearer JWT against JWKS; the field plumbing is
    what is under test, not the token parsing."""
    monkeypatch.setattr(main, "verify_agent", lambda authorization: ME)


def _create(pr: int | None = None, pr_repo: str | None = None) -> int:
    resp = main.create_request(
        main.RunRequest(
            action="build-container.yaml",
            sha=SHA,
            inputs={},
            why="test",
            pr=pr,
            pr_repo=pr_repo,
        ),
        authorization=None,
    )
    return resp["id"]


def _row(req_id: int):
    with main.db() as conn:
        return conn.execute("SELECT * FROM requests WHERE id = ?", (req_id,)).fetchone()


def test_create_stores_pr_repo():
    rid = _create(pr=12, pr_repo="eblume/talos")
    assert _row(rid)["pr_repo"] == "eblume/talos"
    listed = next(r for r in main.list_requests() if r["id"] == rid)
    assert listed["pr_repo"] == "eblume/talos"


def test_create_without_pr_repo_stays_null():
    """Pre-0.4.1 clients omit the field; NULL must read as blumeops, not fail."""
    rid = _create(pr=525)
    assert _row(rid)["pr_repo"] is None


def test_supersede_returns_the_stored_pr_repo():
    """request-run annotates the retired request's own PR comment; a
    cross-repo request retired into a blumeops PR would mis-annotate exactly
    like the original filing bug."""
    old = _create(pr=12, pr_repo="eblume/talos")
    new = _create(pr=12, pr_repo="eblume/talos")
    result = main.supersede(old, main.Supersede(by=new))
    assert result["pr"] == 12
    assert result["pr_repo"] == "eblume/talos"


def test_pr_links_target_the_prs_own_repo():
    html = main._pr_links(12, SHA, "eblume/talos")
    assert "https://forge.eblu.me/eblume/talos/pulls/12" in html
    assert "https://forge.eblu.me/eblume/talos/pulls/12/files" in html


def test_pr_links_default_to_blumeops():
    assert main._pr_links(525, SHA) == main._pr_links(525, SHA, None)
    assert "eblume/blumeops/pulls/525" in main._pr_links(525, SHA)
