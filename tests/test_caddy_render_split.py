"""caddy service-data split: the fly-only :8443 listener serves exactly the
services flagged `fly_proxied`, and the data has unique hosts, names and tcp
ports. Data-level only (no Caddyfile render): exercises the check function
in mise-tasks/caddy-render-check against synthetic service data.
"""

import copy
import importlib.machinery
import importlib.util
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHECK_PATH = ROOT / "mise-tasks/caddy-render-check"

_loader = importlib.machinery.SourceFileLoader("caddy_render_check", str(CHECK_PATH))
_spec = importlib.util.spec_from_loader("caddy_render_check", _loader)
assert _spec is not None
check = importlib.util.module_from_spec(_spec)
_loader.exec_module(check)

BASE = {
    "domain": "ops.eblu.me",
    "https_port": 443,
    "fly_https_port": 8443,
    "services": [
        {
            "name": "flysvc",
            "host": "flysvc.ops.eblu.me",
            "kind": "proxy",
            "backend": "http://localhost:1001",
            "fly_proxied": True,
        },
        {
            "name": "plainsvc",
            "host": "plainsvc.ops.eblu.me",
            "kind": "proxy",
            "backend": "http://localhost:1002",
            "fly_proxied": False,
        },
        {
            "name": "staticsvc",
            "host": "staticsvc.ops.eblu.me",
            "kind": "static",
            "root": "/srv/static",
            "fly_proxied": True,
        },
    ],
    "tcp_services": [{"port": 2222, "backend": "localhost:2200"}],
    "fly_proxied_services": ["flysvc", "staticsvc"],
}


def errors_for(mutate=None) -> list[str]:
    data = copy.deepcopy(BASE)
    if mutate:
        mutate(data)
    return check.check_services(data)


def test_consistent_split_passes():
    assert errors_for() == []


def test_empty_fly_list_passes():
    def mutate(d):
        for s in d["services"]:
            s["fly_proxied"] = False
        d["fly_proxied_services"] = []

    assert errors_for(mutate) == []


def test_flagged_but_unlisted_fails():
    def mutate(d):
        d["fly_proxied_services"] = ["flysvc"]

    errs = errors_for(mutate)
    assert any("staticsvc: fly_proxied but not listed" in e for e in errs)


def test_listed_but_unflagged_fails():
    def mutate(d):
        d["fly_proxied_services"] = ["flysvc", "staticsvc", "plainsvc"]

    errs = errors_for(mutate)
    assert any(
        "plainsvc: listed in fly_proxied_services but not fly_proxied" in e
        for e in errs
    )


def test_listed_unknown_service_fails():
    def mutate(d):
        d["fly_proxied_services"] = ["flysvc", "staticsvc", "ghost"]

    errs = errors_for(mutate)
    assert any("ghost: in fly_proxied_services but no such service" in e for e in errs)


def test_fly_member_with_bad_kind_fails():
    def mutate(d):
        d["services"][0]["kind"] = "redirect"

    errs = errors_for(mutate)
    assert any("flysvc: fly_proxied with unknown kind" in e for e in errs)


def test_host_outside_domain_fails():
    def mutate(d):
        d["services"][1]["host"] = "plainsvc.example.com"

    errs = errors_for(mutate)
    assert any(
        "plainsvc: host 'plainsvc.example.com' is not under ops.eblu.me" in e
        for e in errs
    )


def test_duplicate_host_fails():
    def mutate(d):
        d["services"][1]["host"] = "flysvc.ops.eblu.me"

    errs = errors_for(mutate)
    assert any("duplicate service hosts" in e for e in errs)


def test_duplicate_name_fails():
    def mutate(d):
        d["services"][1]["name"] = "flysvc"

    errs = errors_for(mutate)
    assert any("duplicate service names" in e for e in errs)


def test_duplicate_tcp_port_fails():
    def mutate(d):
        d["tcp_services"].append({"port": 2222, "backend": "elsewhere:2200"})

    errs = errors_for(mutate)
    assert any("duplicate tcp_services ports: 2222" in e for e in errs)


def test_checked_in_data_passes():
    import json

    data = json.loads(
        (ROOT / "darwin/indri/caddy-services.json").read_text(encoding="utf-8")
    )
    assert check.check_services(data) == []
