"""horkos-forge-drift: the repos.json horkos_forge set is the whole blast radius.

`horkos-forge-drift` asserts, read-only, that the `horkos-forge` bot holds
write on exactly the repos.json `horkos_forge` set — the set
`agent-repo-access` reconciles — is not a site admin, and that blumeops `main`
stays whitelisted to eblume alone. These tests stub the forge with a minimal
httpx.MockTransport fake — no network, no vault.
"""

import importlib.machinery
import importlib.util
import io
import json
import pathlib

import httpx
import pytest
import typer
from rich.console import Console

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "horkos_forge_drift", str(ROOT / "mise-tasks" / "horkos-forge-drift")
    )
    spec = importlib.util.spec_from_loader("horkos_forge_drift", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


hfd = _load()


@pytest.fixture
def policy(tmp_path, monkeypatch):
    """Point POLICY_PATH at a scratch repos.json; return a setter(repos)."""

    def set_repos(repos):
        path = tmp_path / "repos.json"
        path.write_text(
            json.dumps({"owner": "eblume", "collaborator": "agents", "repos": repos}),
            encoding="utf-8",
        )
        return path

    monkeypatch.setattr(hfd, "POLICY_PATH", tmp_path / "repos.json")
    return set_repos


def _repo(name, horkos_forge=False):
    entry = {"name": name, "access": "write", "pool": "none"}
    if horkos_forge:
        entry["horkos_forge"] = True
    return entry


def _protected_main():
    return {
        "enable_push_whitelist": True,
        "enable_merge_whitelist": True,
        "push_whitelist_usernames": ["eblume"],
        "merge_whitelist_usernames": ["eblume"],
        "push_whitelist_deploy_keys": False,
    }


class FakeForge:
    """MockTransport-backed client; records every request, serves canned
    users/repos/collaborators/branch-protection state. List endpoints are
    page-aware because the script's paged() helper walks pages until an empty
    one."""

    def __init__(self):
        self.requests = []  # (method, url)
        self.repos = []  # visible eblume repo names
        self.access = {}  # repo -> horkos-forge access ("write" | "none")
        self.is_admin = False
        self.is_active = True
        self.main_protection = None  # None -> 404 (no branch protection)

    def _page(self, request, data):
        page = int(request.url.params.get("page", 1))
        return data if page == 1 else []

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append((request.method, str(request.url)))
        path = request.url.path
        if path == "/api/v1/repos/search":
            return httpx.Response(
                200,
                json={
                    "ok": True,
                    "data": self._page(
                        request,
                        [{"name": n, "owner": {"login": "eblume"}} for n in self.repos],
                    ),
                },
            )
        if path == "/api/v1/users/horkos-forge":
            return httpx.Response(
                200,
                json={
                    "login": "horkos-forge",
                    "is_admin": self.is_admin,
                    "is_active": self.is_active,
                },
            )
        parts = path.strip("/").split("/")
        if len(parts) >= 5 and parts[:3] == ["api", "v1", "repos"]:
            _, _, _, _owner, repo, *tail = parts
            if tail == ["collaborators"]:
                users = [{"login": "horkos-forge"}] if repo in self.access else []
                return httpx.Response(200, json=self._page(request, users))
            if tail == ["collaborators", "horkos-forge", "permission"]:
                return httpx.Response(
                    200, json={"permission": self.access.get(repo, "none")}
                )
            if tail == ["branch_protections", "main"]:
                if self.main_protection is None:
                    return httpx.Response(404, json={"message": "no protection"})
                return httpx.Response(200, json=self.main_protection)
        return httpx.Response(404, json={"message": "unexpected path"})

    def install(self, monkeypatch):
        real_client = httpx.Client

        def factory(*args, **kwargs):
            # Honor the script's base_url (and headers/timeout) so request URLs
            # are absolute — httpx cookie handling rejects relative URLs.
            # Bind real_client before patching: httpx.Client is the same module
            # object the script's httpx sees, so a self-reference would recurse.
            return real_client(
                *args, transport=httpx.MockTransport(self.handler), **kwargs
            )

        monkeypatch.setattr(hfd.httpx, "Client", factory)
        return factory()


@pytest.fixture
def run_main(monkeypatch):
    """Invoke main() directly with rich output captured; returns (code, out)."""
    buf = io.StringIO()
    monkeypatch.setattr(
        hfd, "console", Console(file=buf, force_terminal=False, width=200)
    )
    monkeypatch.setattr(hfd, "err", Console(file=buf, force_terminal=False, width=200))

    def invoke(*args, **kwargs):
        code = 0
        try:
            hfd.main(*args, **kwargs)
        except typer.Exit as exc:
            code = exc.exit_code
        return code, buf.getvalue()

    return invoke


def test_in_sync_when_grants_match_policy(policy, run_main, monkeypatch):
    # Grants match the flagged set exactly; nothing stray; not a site admin;
    # main protected -> exit 0 / "scoped as designed".
    policy(
        [
            _repo("blumeops", horkos_forge=True),
            _repo("horkos", horkos_forge=True),
            _repo("cv", horkos_forge=False),
        ]
    )
    forge = FakeForge()
    forge.repos = ["blumeops", "cv", "horkos", "timberborn-parsimony"]
    forge.access = {"blumeops": "write", "horkos": "write"}
    forge.main_protection = _protected_main()
    forge.install(monkeypatch)

    code, out = run_main(token="t")
    assert code == 0
    assert "is scoped as designed" in out
    assert "DRIFT" not in out
    assert "horkos-forge on eblume/blumeops (write)" in out
    assert "horkos-forge on eblume/horkos (write)" in out


def test_missing_write_on_flagged_repo_drifts(policy, run_main, monkeypatch):
    policy(
        [
            _repo("horkos", horkos_forge=True),
            _repo("cv", horkos_forge=True),
        ]
    )
    forge = FakeForge()
    forge.repos = ["horkos", "cv"]
    forge.access = {"horkos": "write", "cv": "read"}  # cv drifted to read
    forge.main_protection = _protected_main()
    forge.install(monkeypatch)

    code, out = run_main(token="t")
    assert code == 1
    assert "horkos-forge on eblume/cv" in out
    assert "expected write, found read" in out
    assert "is scoped as designed" not in out


def test_stray_grant_outside_set_drifts(policy, run_main, monkeypatch):
    policy([_repo("blumeops", horkos_forge=True)])
    forge = FakeForge()
    forge.repos = ["blumeops", "research"]
    forge.access = {"blumeops": "write", "research": "write"}  # stray grant
    forge.main_protection = _protected_main()
    forge.install(monkeypatch)

    code, out = run_main(token="t")
    assert code == 1
    assert "also a collaborator on research (write)" in out


def test_missing_policy_is_a_hard_failure(policy, run_main, monkeypatch):
    # POLICY_PATH was patched to a scratch path that was never written: the
    # check must hard-fail rather than claim a clean blast radius.
    code, out = run_main(token="t")
    assert code == 1
    assert "cannot read the horkos_forge policy" in out


def test_bad_policy_flag_is_a_hard_failure(policy, run_main, monkeypatch):
    policy([{"name": "svc", "access": "write", "pool": "none", "horkos_forge": "yes"}])

    code, out = run_main(token="t")
    assert code == 1
    assert "invalid horkos_forge 'yes'" in out


def test_skip_if_no_token_exits_zero(policy, run_main, monkeypatch):
    policy([_repo("blumeops", horkos_forge=True)])

    code, out = run_main(skip_if_no_token=True)
    assert code == 0
    assert "SKIPPED" in out
