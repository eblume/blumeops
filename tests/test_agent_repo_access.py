"""agent-repo-access: write on a repo == read of its Actions secrets.

`agent-repo-access` reconciles the `agents` bot's forge collaborations. The
Actions-secrets invariant: workflows execute at the pushed ref and every run
is handed the repo's secrets, so `access: write` on a repo whose
`/actions/secrets` list is non-empty is a violation — it must fail `--check`
(gate, listing each violation) and pre-empt a whole apply (no PUT/DELETE may
happen). An *unreadable* secrets list (403/404) on a listed write repo joins
the `blocked` fatal path, the same convention as unreadable collaborators.
PINNED_READ_ONLY (write on blumeops/agents/horkos/talos) stays refused at
load_policy time.
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
        "agent_repo_access", str(ROOT / "mise-tasks" / "agent-repo-access")
    )
    spec = importlib.util.spec_from_loader("agent_repo_access", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


ara = _load()


def _policy(repos):
    return {"owner": "eblume", "collaborator": "agents", "repos": repos}


@pytest.fixture
def policy(tmp_path, monkeypatch):
    """Point POLICY_PATH at a scratch repos.json; return a setter(repos)."""

    def set_repos(repos):
        path = tmp_path / "repos.json"
        path.write_text(json.dumps(_policy(repos)), encoding="utf-8")
        return path

    monkeypatch.setattr(ara, "POLICY_PATH", tmp_path / "repos.json")
    return set_repos


def _write_repo(name, **extra):
    entry = {"name": name, "access": "write", "pool": "none"}
    entry.update(extra)
    return entry


class FakeForge:
    """MockTransport-backed client; records every request, serves canned
    collaborators/hooks/secrets. List endpoints are page-aware because the
    script's paged() helper walks pages until an empty one."""

    def __init__(self):
        self.requests = []  # (method, url)
        self.repos = []  # visible repo names
        self.permission = {}  # repo -> agents permission
        self.secrets: (
            dict[str, list[str]] | None
        ) = {}  # repo -> names; None = endpoint 403s
        self.secrets_body: dict | list | None = None  # raw-body override (shape test)
        self.hooks_status = 200  # non-200: the hooks list is unreadable

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
        parts = path.strip("/").split("/")
        if len(parts) >= 5 and parts[:3] == ["api", "v1", "repos"]:
            _, _, _, _owner, repo, *tail = parts
            if tail == ["collaborators"]:
                return httpx.Response(
                    200, json=self._page(request, [{"login": "agents"}])
                )
            if tail == ["collaborators", "agents", "permission"]:
                return httpx.Response(
                    200, json={"permission": self.permission.get(repo, "none")}
                )
            if tail == ["hooks"]:
                if self.hooks_status != 200:
                    return httpx.Response(self.hooks_status, json={"message": "denied"})
                return httpx.Response(200, json=self._page(request, []))
            if tail == ["actions", "secrets"]:
                if self.secrets_body is not None:
                    return httpx.Response(200, json=self.secrets_body)
                names = None if self.secrets is None else self.secrets.get(repo)
                if names is None:
                    return httpx.Response(
                        403, json={"message": "insufficient permission"}
                    )
                # Forgejo serves a bare JSON array, not GitHub's wrapped shape.
                return httpx.Response(200, json=[{"name": n} for n in names])
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

        monkeypatch.setattr(ara.httpx, "Client", factory)
        return factory()


@pytest.fixture
def run_main(monkeypatch):
    """Invoke main() directly with rich output captured; returns (code, out)."""
    buf = io.StringIO()
    monkeypatch.setattr(
        ara, "console", Console(file=buf, force_terminal=False, width=200)
    )

    def invoke(*args, **kwargs):
        code = 0
        try:
            ara.main(*args, **kwargs)
        except typer.Exit as exc:
            code = exc.exit_code
        return code, buf.getvalue()

    return invoke


def test_write_repo_empty_secrets_in_sync(policy, run_main, monkeypatch):
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": []}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 0
    assert "In sync." in out


def test_write_repo_with_secrets_fails_check(policy, run_main, monkeypatch):
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": ["DEPLOY_KEY", "OTHER"]}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "Out of sync (--check)." in out
    assert (
        "actions-secrets: eblume/svc declares write but carries 2 Actions secret(s) (DEPLOY_KEY, OTHER)"
        in out
    )
    assert "write on a repo means read of its Actions secrets" in out


def test_apply_refuses_before_any_mutation(policy, run_main, monkeypatch):
    # want write, have read: drift alone would PUT a grant — the violation
    # must pre-empt it, so no /collaborators/ mutation may be issued.
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "read"}
    forge.secrets = {"svc": ["DEPLOY_KEY"]}
    forge.install(monkeypatch)

    code, out = run_main(token="t")  # apply mode: no --check, no --dry-run
    assert code == 1
    assert "Refusing to apply" in out
    assert (
        "actions-secrets: eblume/svc declares write but carries 1 Actions secret(s) (DEPLOY_KEY)"
        in out
    )
    mutating = [
        (m, u)
        for m, u in forge.requests
        if m in ("PUT", "DELETE") and "/collaborators/" in u
    ]
    assert mutating == []


def test_write_repo_unreadable_secrets_is_blocked(policy, run_main, monkeypatch):
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = None  # endpoint 403s for everything
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "Cannot read collaborators or Actions secrets" in out
    assert "svc" in out


def test_wrapped_secrets_shape_fails_loud(policy, run_main, monkeypatch):
    # Forgejo's list is a bare JSON array. If the body ever came back wrapped
    # (GitHub's shape), reading it as empty would silently disarm the
    # invariant — it must raise instead.
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets_body = {"secrets": [{"name": "DEPLOY_KEY"}], "total": 1}
    forge.install(monkeypatch)

    with pytest.raises(TypeError, match="/actions/secrets body for eblume/svc"):
        run_main(check=True, token="t")


def test_read_repo_never_calls_secrets_endpoint(policy, run_main, monkeypatch):
    policy([{"name": "svc", "access": "read", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "read"}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 0
    assert "In sync." in out
    assert not any("/actions/secrets" in url for _, url in forge.requests)


def test_pinned_read_only_write_refused_at_load(policy, run_main, monkeypatch):
    policy([{"name": "blumeops", "access": "write", "pool": "fork"}])

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "pinned read-only" in out
    assert "Refusing" in out


def test_apply_refuses_ok_case_without_drift(policy, run_main, monkeypatch):
    # have == want == "write": no collaborator drift at all, yet the secrets
    # must still pre-empt the apply — this is the load-bearing case, since an
    # already-write grant that acquires secrets is otherwise invisible to the
    # drift table.
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": ["ZOT_PUSH_API_KEY"]}
    forge.install(monkeypatch)

    code, out = run_main(token="t")  # apply mode
    assert code == 1
    assert "Refusing to apply" in out
    assert (
        "actions-secrets: eblume/svc declares write but carries 1 Actions secret(s) (ZOT_PUSH_API_KEY)"
        in out
    )
    mutating = [
        (m, u)
        for m, u in forge.requests
        if m in ("PUT", "DELETE") and "/collaborators/" in u
    ]
    assert mutating == []


def test_dry_run_lists_violations_without_failing(policy, run_main, monkeypatch):
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": ["DEPLOY_KEY"]}
    forge.install(monkeypatch)

    code, out = run_main(dry_run=True, token="t")
    assert code == 0
    assert (
        "actions-secrets: eblume/svc declares write but carries 1 Actions secret(s) (DEPLOY_KEY)"
        in out
    )
    mutating = [
        (m, u)
        for m, u in forge.requests
        if m in ("PUT", "DELETE") and "/collaborators/" in u
    ]
    assert mutating == []


def test_unreadable_secrets_and_hooks_listed_once(policy, run_main, monkeypatch):
    # Both the secrets list and the hook list are unreadable: the repo must be
    # reported once, not once per unreadable half.
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = None
    forge.hooks_status = 404
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert (
        "Cannot read collaborators or Actions secrets on 1 listed repo(s): svc" in out
    )
    msg = [line for line in out.splitlines() if "Cannot read collaborators" in line]
    assert len(msg) == 1
    assert msg[0].count("svc") == 1
