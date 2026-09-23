"""horkos-forge-provision: the minted PAT's scope list is the boundary.

A narrowing here fails only live, at the first settlement comment (forge
scopes the issue routes to the issue token category, so `write:issue` is
load-bearing) — pin the constant in CI.
"""

import importlib.machinery
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "horkos_forge_provision", str(ROOT / "mise-tasks" / "horkos-forge-provision")
    )
    spec = importlib.util.spec_from_loader("horkos_forge_provision", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


hfp = _load()


def test_token_scopes_cover_dispatch_and_issue_comments():
    assert hfp.TOKEN_SCOPES == ["write:repository", "write:issue"]


# --- the new-PAT proof ------------------------------------------------------
#
# A fake forge that enforces scopes the way Forgejo does: `/user` wants
# read:user, which the dispatch PAT never carries. The proof must pass
# against it with exactly TOKEN_SCOPES.

import httpx

PAT, OTHER = "newpat", "otherpat"
REPO = "/api/v1/repos/eblume/blumeops"


def _forge(owned_ids=(7,), push=True):
    tokens = {PAT: set(hfp.TOKEN_SCOPES), OTHER: set(hfp.TOKEN_SCOPES)}

    def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path.endswith(f"/users/{hfp.BOT_USER}/tokens"):
            if request.headers.get("authorization", "").startswith("Basic "):
                page = int(request.url.params.get("page", "1"))
                body = (
                    [{"id": i, "name": f"horkos-forge-{i}"} for i in owned_ids]
                    if page == 1
                    else []
                )
                return httpx.Response(200, json=body)
            return httpx.Response(401)
        auth = request.headers.get("authorization", "")
        scopes = tokens.get(auth.removeprefix("token "))
        if scopes is None:
            return httpx.Response(401)
        if path.endswith("/user"):
            return httpx.Response(200 if "read:user" in scopes else 403)
        if path == REPO:
            return httpx.Response(
                200, json={"permissions": {"pull": True, "push": push}}
            )
        return httpx.Response(404)

    transport = httpx.MockTransport(handler)
    return httpx.Client(transport=transport), httpx.Client(
        transport=transport, auth=(hfp.BOT_USER, "pw")
    )


def _verify(token_id=7, pat=PAT, **forge):
    client, basic = _forge(**forge)
    return hfp.verify_new_pat(client, basic, pat, token_id, "eblume", "blumeops")


def test_fake_forge_rejects_get_user_for_dispatch_scopes():
    client, _ = _forge()
    assert (
        client.get(
            "https://f/api/v1/user", headers={"Authorization": f"token {PAT}"}
        ).status_code
        == 403
    )


def test_proof_passes_with_exactly_token_scopes(monkeypatch):
    monkeypatch.setattr(hfp, "FORGE_API", "https://f/api/v1")
    assert _verify() is None


def test_proof_fails_when_id_not_owned(monkeypatch):
    monkeypatch.setattr(hfp, "FORGE_API", "https://f/api/v1")
    assert "not in" in _verify(token_id=99)


def test_proof_fails_on_bad_token(monkeypatch):
    monkeypatch.setattr(hfp, "FORGE_API", "https://f/api/v1")
    assert "(401)" in _verify(pat="bogus")


def test_proof_fails_without_push(monkeypatch):
    monkeypatch.setattr(hfp, "FORGE_API", "https://f/api/v1")
    assert "without push" in _verify(push=False)
