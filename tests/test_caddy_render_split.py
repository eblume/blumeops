"""caddy template split: the fly-only :8443 listener serves exactly the
services flagged `fly_proxied`, and the :443 wildcard site keeps every
service. Self-contained (no mise-task import): renders the real template
with a small synthetic context, so it runs anywhere jinja2 is available.
"""

import pathlib

import jinja2

ROOT = pathlib.Path(__file__).resolve().parent.parent

TEMPLATE_DIR = ROOT / "ansible/roles/caddy/templates"

SERVICES = [
    {
        "name": "flysvc",
        "host": "flysvc.ops.eblu.me",
        "backend": "http://localhost:1001",
        "fly_proxied": True,
    },
    {
        "name": "plainsvc",
        "host": "plainsvc.ops.eblu.me",
        "backend": "http://localhost:1002",
    },
    {
        "name": "staticsvc",
        "host": "staticsvc.ops.eblu.me",
        "kind": "static",
        "root": "/srv/static",
        "fly_proxied": True,
    },
]


def render() -> str:
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(TEMPLATE_DIR)),
        keep_trailing_newline=True,
    )
    return env.get_template("Caddyfile.j2").render(
        caddy_domain="ops.eblu.me",
        caddy_https_port=443,
        caddy_fly_https_port=8443,
        caddy_fly_proxied_services=["flysvc", "staticsvc"],
        caddy_services=SERVICES,
        caddy_tcp_services=[],
    )


def test_both_listeners_present():
    text = render()
    assert "*.ops.eblu.me:443 {" in text
    assert "*.ops.eblu.me:8443 {" in text


def test_fly_block_contains_exactly_the_flagged_hosts():
    text = render()
    fly = text[text.index("*.ops.eblu.me:8443 {") : text.index("# Base domain")]
    assert "host flysvc.ops.eblu.me" in fly
    assert "host staticsvc.ops.eblu.me" in fly
    assert "host plainsvc.ops.eblu.me" not in fly


def test_main_block_keeps_every_service():
    text = render()
    main = text[text.index("*.ops.eblu.me:443 {") : text.index("*.ops.eblu.me:8443 {")]
    for host in ("flysvc.ops.eblu.me", "plainsvc.ops.eblu.me", "staticsvc.ops.eblu.me"):
        assert f"host {host}" in main


def test_fallback_appears_once_per_listener():
    assert render().count('respond "Unknown service" 404') == 2


def test_no_layer4_block_without_tcp_services():
    assert "layer4" not in render()


def render_empty_fly_list() -> str:
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(str(TEMPLATE_DIR)),
        keep_trailing_newline=True,
    )
    return env.get_template("Caddyfile.j2").render(
        caddy_domain="ops.eblu.me",
        caddy_https_port=443,
        caddy_fly_https_port=8443,
        caddy_fly_proxied_services=[],
        caddy_services=SERVICES,
        caddy_tcp_services=[],
    )


def test_no_fly_listener_when_list_empty():
    text = render_empty_fly_list()
    assert "*.ops.eblu.me:8443" not in text
    assert "*.ops.eblu.me:443 {" in text
    assert text.count('respond "Unknown service" 404') == 1
