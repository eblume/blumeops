"""reconcile-authentik-principals: the live-state parse paths are the boundary.

`live_groups` depends on authentik serializer shapes — a binding's `target`
is the concrete subclass pk (UUID string), the group name rides on
`group_obj`, and user-level bindings have a null `group_obj` — that only
fail at runtime against live Authentik. Pin the parse against those exact
shapes here, plus the Grafana exact-login filter and the apply-mode sweep
failure behavior. The task's authenticate/op paths are never touched: every
fixture transport is offline.
"""

import importlib.machinery
import importlib.util
import pathlib
import sys

import httpx
import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: sys.exit(main()) is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "reconcile_authentik_principals",
        str(ROOT / "mise-tasks" / "reconcile-authentik-principals"),
    )
    spec = importlib.util.spec_from_loader("reconcile_authentik_principals", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    # module-level @dataclass needs a sys.modules entry on py3.14
    sys.modules[module.__name__] = module
    loader.exec_module(module)
    return module


rap = _load()

UUID_ZOT = "00000000-0000-0000-0000-000000000001"
UUID_FORGE = "00000000-0000-0000-0000-000000000002"
UUID_ORPHAN = "00000000-0000-0000-0000-000000000003"
UUID_FLOW = (
    "00000000-0000-0000-0000-0000000000ff"  # flow UUID, absent from the apps map
)


def _page(results):
    return {"results": results, "pagination": {"page": 1, "next": 0}}


def _live_groups_client():
    def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path == "/api/v3/core/groups/":
            return httpx.Response(
                200,
                json=_page(
                    [
                        {"pk": UUID_ZOT, "uuid": UUID_ZOT, "name": "g-zot"},
                        {"pk": UUID_FORGE, "uuid": UUID_FORGE, "name": "g-forge"},
                        {"pk": UUID_ORPHAN, "uuid": UUID_ORPHAN, "name": "g-orphan"},
                    ]
                ),
            )
        if path == "/api/v3/core/applications/":
            return httpx.Response(
                200,
                json=_page(
                    [
                        {
                            "pk": UUID_FORGE,
                            "name": "Forgejo",
                            "slug": "forgejo",
                        },
                        {
                            "pk": UUID_ZOT,
                            "name": "Zot Registry",
                            "slug": "zot",
                        },
                    ]
                ),
            )
        if path == "/api/v3/policies/bindings/":
            return httpx.Response(
                200,
                json=_page(
                    [
                        {
                            "pk": "00000000-0000-0000-0000-0000000000b1",
                            "target": UUID_ZOT,
                            "group": "00000000-0000-0000-0000-0000000000b1",
                            "group_obj": {
                                "pk": UUID_ZOT,
                                "num_pk": 1,
                                "name": "g-zot",
                            },
                            "order": 0,
                            "enabled": True,
                        },
                        {
                            "pk": "00000000-0000-0000-0000-0000000000b2",
                            "target": UUID_FORGE,
                            "group": "00000000-0000-0000-0000-0000000000b2",
                            "group_obj": {
                                "pk": UUID_FORGE,
                                "num_pk": 2,
                                "name": "g-forge",
                            },
                            "order": 1,
                            "enabled": True,
                        },
                        # flows/sources carry their own UUIDs: not in the apps map
                        {
                            "pk": "00000000-0000-0000-0000-0000000000b3",
                            "target": UUID_FLOW,
                            "group": "00000000-0000-0000-0000-0000000000b3",
                            "group_obj": {
                                "pk": UUID_FORGE,
                                "num_pk": 2,
                                "name": "g-forge",
                            },
                            "order": 5,
                            "enabled": True,
                        },
                        # user-level bindings have no group_obj
                        {
                            "pk": "00000000-0000-0000-0000-0000000000b4",
                            "target": UUID_ZOT,
                            "group": None,
                            "group_obj": None,
                            "order": 6,
                            "enabled": True,
                        },
                    ]
                ),
            )
        return httpx.Response(404)

    return httpx.Client(
        base_url="https://fake", transport=httpx.MockTransport(handler), timeout=30
    )


def test_live_groups_real_serializer_shapes():
    groups = rap.live_groups(_live_groups_client())
    by_name = {g.name: g for g in groups}
    assert set(by_name) == {"g-zot", "g-forge", "g-orphan"}
    assert by_name["g-zot"].bindings == (("zot", 0),)
    assert by_name["g-forge"].bindings == (("forgejo", 1),)
    assert by_name["g-orphan"].bindings == ()


def test_zot_group_names():
    groups = rap.live_groups(_live_groups_client())
    assert rap.zot_group_names(groups) == {"g-zot"}


def test_grafana_find_404_is_no_users():
    def handler(request):
        return httpx.Response(404)

    client = httpx.Client(
        base_url="https://fake", transport=httpx.MockTransport(handler), timeout=30
    )
    assert rap.grafana_find(client, "ci-zot") == []


def test_grafana_find_returns_single_dto():
    # /api/users/lookup answers one UserProfileDTO, not a list.
    def handler(request):
        if request.url.path == "/api/users/lookup":
            return httpx.Response(
                200,
                json={"id": 1, "login": "ci-zot", "email": "ci-zot@example.com"},
            )
        return httpx.Response(404)

    client = httpx.Client(
        base_url="https://fake", transport=httpx.MockTransport(handler), timeout=30
    )
    found = rap.grafana_find(client, "ci-zot")
    assert [u.login for u in found] == ["ci-zot"]
    assert found[0].id == 1
    assert found[0].email == "ci-zot@example.com"


def test_grafana_find_rejects_email_match():
    # The lookup matches login OR email; a hit on the email field is not our
    # principal (our key is the login).
    def handler(request):
        if request.url.path == "/api/users/lookup":
            return httpx.Response(
                200,
                json={"id": 2, "login": "other", "email": "ci-zot@example.com"},
            )
        return httpx.Response(404)

    client = httpx.Client(
        base_url="https://fake", transport=httpx.MockTransport(handler), timeout=30
    )
    assert rap.grafana_find(client, "ci-zot") == []


def test_grafana_sweep_apply_mode_failure(monkeypatch):
    def handler(request):
        return httpx.Response(500)

    monkeypatch.setattr(
        rap,
        "grafana_client",
        lambda url, password: httpx.Client(
            base_url=url, transport=httpx.MockTransport(handler), timeout=30
        ),
    )
    with pytest.raises(SystemExit):
        rap.grafana_sweep("x", "https://fake", "pw", apply=True)
    rap.grafana_sweep("x", "https://fake", "pw", apply=False)  # warns, no raise


def test_paginate_follows_next_page():
    seen = []

    def handler(request):
        page = int(request.url.params.get("page", "1"))
        seen.append(page)
        if page == 1:
            return httpx.Response(
                200,
                json={
                    "results": [{"n": 1}],
                    "pagination": {"page": 1, "next": 2},
                },
            )
        return httpx.Response(
            200,
            json={"results": [{"n": 2}], "pagination": {"page": 2, "next": 0}},
        )

    client = httpx.Client(
        base_url="https://fake", transport=httpx.MockTransport(handler), timeout=30
    )
    out = rap.paginate(client, "/api/v3/items/")
    assert [o["n"] for o in out] == [1, 2]
    assert seen == [1, 2]
