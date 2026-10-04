"""forge-reconcile: write on a repo == read of its Actions secrets.

`forge-reconcile` reconciles the `agents` bot's forge collaborations. The
Actions-secrets invariant: workflows execute at the pushed ref and every run
is handed the repo's secrets, so `access: write` on a repo whose
`/actions/secrets` list is non-empty is a violation — it must fail `--check`
(gate, listing each violation) and pre-empt a whole apply (no PUT/DELETE may
happen). An *unreadable* secrets list (403/404) on a listed write repo joins
the `blocked` fatal path, the same convention as unreadable collaborators.
PINNED_READ_ONLY (write on blumeops/agents/horkos/talos) stays refused at
load_policy time.

The same task also reconciles the `horkos-forge` bot's grants (repos.json's
per-repo `horkos_forge` flag, exempt from PINNED_READ_ONLY), and the forge →
horkos hook now carries Forgejo's terminal action-run events.

And branch protections against forge/branch-protections.json: whole-rule
declarations, set-compared lists, read-back after every write, a bot
whitelist fence at load time, and no protection writes under the CI token.
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
        "agent_repo_access", str(ROOT / "mise-tasks" / "forge-reconcile")
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
    """Point POLICY_PATH at a scratch repos.json; return a setter(repos).

    PROTECTIONS_PATH goes to a scratch file declaring no rules, so tests
    that are not about branch protection never see the real policy."""

    def set_repos(repos):
        path = tmp_path / "repos.json"
        path.write_text(json.dumps(_policy(repos)), encoding="utf-8")
        return path

    monkeypatch.setattr(ara, "POLICY_PATH", tmp_path / "repos.json")
    protections = tmp_path / "branch-protections.json"
    protections.write_text(json.dumps({"rules": []}), encoding="utf-8")
    monkeypatch.setattr(ara, "PROTECTIONS_PATH", protections)
    return set_repos


def _write_repo(name, **extra):
    entry = {"name": name, "access": "write", "pool": "none"}
    entry.update(extra)
    return entry


def _valid_user(is_admin=False, is_active=True):
    return {"login": "horkos-forge", "is_admin": is_admin, "is_active": is_active}


def _blumeops_main_rule(**overrides):
    """A valid blumeops:main protection as the API serves it (whitelisted to
    eblume alone) — the shape the blast-radius invariant expects."""
    rule = {
        "rule_name": "main",
        "enable_push_whitelist": True,
        "enable_merge_whitelist": True,
        "push_whitelist_usernames": ["eblume"],
        "merge_whitelist_usernames": ["eblume"],
        "push_whitelist_deploy_keys": False,
    }
    rule.update(overrides)
    return rule


class FakeForge:
    """MockTransport-backed client; records every request, serves canned
    collaborators/hooks/secrets. List endpoints are page-aware because the
    script's paged() helper walks pages until an empty one."""

    def __init__(self):
        self.requests = []  # (method, url)
        self.repos = []  # visible repo names
        self.permission = {}  # repo -> agents permission
        self.horkos_permission = {}  # repo -> horkos-forge permission
        self.secrets: (
            dict[str, list[str]] | None
        ) = {}  # repo -> names; None = endpoint 403s
        self.secrets_body: dict | list | None = None  # raw-body override (shape test)
        self.hooks_status = 200  # non-200: the hooks list is unreadable
        self.hooks: dict[str, list[dict]] = {}  # repo -> served hook objects
        # Events a PATCH silently drops, mimicking Forgejo v16.0.2's editHook
        # (which never maps action_run_*); POST maps everything.
        self.patch_drops: set[str] = set()
        self.next_hook_id = 100
        self.actions_off: set[str] = set()  # repos whose Actions unit is disabled
        # Path suffix -> status served instead of the real answer.
        self.status_overrides: dict[str, int] = {}
        self.protections: dict[str, list[dict]] = {}  # repo -> served rules
        # Fields a protection PATCH silently ignores (a 200 that changes nothing).
        self.protection_patch_drops: set[str] = set()
        # The folded-in horkos-forge blast-radius invariants read these.
        self.horkos_user: dict | None = None  # None -> 404 (site-admin check UNKNOWN)

    # Forgejo stores per-event flags and reads them back as names: the
    # `pull_request` umbrella sets the whole pull_request_* family (API
    # pullHook), `issues` the issue_* family, and the review flag reads back
    # as the approved/rejected/review-comment trio (EventsArray).
    PR_FAMILY = frozenset(
        {
            "pull_request_assign",
            "pull_request_label",
            "pull_request_milestone",
            "pull_request_comment",
            "pull_request_review",
            "pull_request_review_request",
            "pull_request_sync",
        }
    )
    ISSUE_FAMILY = frozenset(
        {"issue_assign", "issue_label", "issue_milestone", "issue_comment"}
    )
    REVIEW_TRIO = frozenset(
        {
            "pull_request_review_approved",
            "pull_request_review_rejected",
            "pull_request_review_comment",
        }
    )

    def _expand(self, events):
        flags = set(events)
        if "pull_request" in flags:
            flags |= self.PR_FAMILY
        if "issues" in flags:
            flags |= self.ISSUE_FAMILY
        if "pull_request_review" in flags:
            flags = (flags - {"pull_request_review"}) | self.REVIEW_TRIO
        if "pull_request_comment" in flags:
            flags.add("pull_request_review_comment")
        return sorted(flags)

    def _page(self, request, data):
        page = int(request.url.params.get("page", 1))
        return data if page == 1 else []

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append((request.method, str(request.url)))
        path = request.url.path
        for suffix, status in self.status_overrides.items():
            if path.endswith(suffix):
                return httpx.Response(status, json={"message": "overridden"})
        if path == "/api/v1/users/horkos-forge":
            if self.horkos_user is None:
                return httpx.Response(404, json={"message": "no such user"})
            return httpx.Response(200, json=self.horkos_user)
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
            # Grant mutations: forge-reconcile only PUTs collaborator grants
            # and DELETEs them — fold the change into the served state so a
            # follow-up read reflects it, and tests can assert on it.
            if (
                request.method in ("PUT", "DELETE")
                and len(tail) == 2
                and tail[0] == "collaborators"
            ):
                if request.method == "PUT":
                    granted = json.loads(request.content)["permission"]
                    if tail[1] == "horkos-forge":
                        self.horkos_permission[repo] = granted
                    else:
                        self.permission[repo] = granted
                else:
                    if tail[1] == "horkos-forge":
                        self.horkos_permission.pop(repo, None)
                    else:
                        self.permission.pop(repo, None)
                return httpx.Response(204)
            if tail == ["collaborators"]:
                users = []
                if repo in self.permission:
                    users.append({"login": "agents"})
                if repo in self.horkos_permission:
                    users.append({"login": "horkos-forge"})
                return httpx.Response(200, json=self._page(request, users))
            if tail == ["collaborators", "agents", "permission"]:
                return httpx.Response(
                    200, json={"permission": self.permission.get(repo, "none")}
                )
            if tail == ["collaborators", "horkos-forge", "permission"]:
                return httpx.Response(
                    200, json={"permission": self.horkos_permission.get(repo, "none")}
                )
            if tail == ["hooks"]:
                if self.hooks_status != 200:
                    return httpx.Response(self.hooks_status, json={"message": "denied"})
                if request.method == "POST":
                    body = json.loads(request.content)
                    hook = {
                        "id": self.next_hook_id,
                        "active": body["active"],
                        "events": self._expand(body["events"]),
                        "config": {
                            "url": body["config"]["url"],
                            "content_type": "json",
                        },
                        "secret_sent": body["config"].get("secret"),
                    }
                    self.next_hook_id += 1
                    self.hooks.setdefault(repo, []).append(hook)
                    return httpx.Response(201, json=hook)
                return httpx.Response(
                    200, json=self._page(request, self.hooks.get(repo, []))
                )
            if len(tail) == 2 and tail[0] == "hooks":
                hook = next(
                    (h for h in self.hooks.get(repo, []) if str(h["id"]) == tail[1]),
                    None,
                )
                if hook is None:
                    return httpx.Response(404, json={"message": "no such hook"})
                if request.method == "PATCH":
                    body = json.loads(request.content)
                    if "events" in body:
                        hook["events"] = self._expand(
                            set(body["events"]) - self.patch_drops
                        )
                    if "active" in body:
                        hook["active"] = body["active"]
                    return httpx.Response(200, json=hook)
                if request.method == "DELETE":
                    self.hooks[repo].remove(hook)
                    return httpx.Response(204)
                return httpx.Response(200, json=hook)
            if not tail:
                return httpx.Response(
                    200,
                    json={"name": repo, "has_actions": repo not in self.actions_off},
                )
            if tail == ["branch_protections"]:
                if request.method == "POST":
                    rule = json.loads(request.content)
                    self.protections.setdefault(repo, []).append(rule)
                    return httpx.Response(201, json=rule)
                return httpx.Response(200, json=self.protections.get(repo, []))
            if len(tail) == 2 and tail[0] == "branch_protections":
                rule = next(
                    (
                        r
                        for r in self.protections.get(repo, [])
                        if r["rule_name"] == tail[1]
                    ),
                    None,
                )
                if rule is None:
                    return httpx.Response(404, json={"message": "no such rule"})
                if request.method == "PATCH":
                    body = json.loads(request.content)
                    rule.update(
                        {
                            k: v
                            for k, v in body.items()
                            if k not in self.protection_patch_drops
                        }
                    )
                return httpx.Response(200, json=rule)
            if tail == ["actions", "secrets"]:
                if repo in self.actions_off:
                    # Forgejo 404s the endpoint when the Actions unit is off.
                    return httpx.Response(404, json={"message": "not found"})
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


def test_horkos_forge_flagged_repo_in_sync(policy, run_main, monkeypatch):
    # Flagged repo where horkos-forge already holds write: no horkos-forge
    # action at all (agents side is independently in sync too).
    policy([_write_repo("svc", horkos_forge=True)])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": []}
    forge.horkos_permission = {"svc": "write"}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 0
    assert "In sync." in out
    assert not any(
        m in ("PUT", "DELETE") and "/collaborators/" in u for m, u in forge.requests
    )


def test_horkos_forge_missing_grant_is_drift(policy, run_main, monkeypatch):
    # Flagged repo with no horkos-forge grant: --check reports the pending
    # grant and exits 1 (like the agents-bot drift tests); apply mode PUTs the
    # write grant, folded into the served state.
    policy([_write_repo("svc", horkos_forge=True)])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": []}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "Out of sync (--check)." in out
    assert "grant horkos-forge on eblume/svc → write" in out

    forge.requests.clear()
    code, out = run_main(token="t")  # apply mode
    assert code == 0
    assert any(m == "PUT" and "horkos-forge" in u for m, u in forge.requests)
    assert "grant horkos-forge on eblume/svc → write" in out
    assert forge.horkos_permission == {"svc": "write"}


def test_horkos_forge_unflagged_stale_grant_revoked(policy, run_main, monkeypatch):
    # Repo in repos.json but not flagged, with a leftover horkos-forge grant:
    # drift in --check, DELETE in apply mode.
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": []}
    forge.horkos_permission = {"svc": "write"}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "Out of sync (--check)." in out
    assert "revoke horkos-forge on eblume/svc" in out

    forge.requests.clear()
    code, out = run_main(token="t")  # apply mode
    assert code == 0
    assert any(m == "DELETE" and "horkos-forge" in u for m, u in forge.requests)
    assert forge.horkos_permission == {}


def test_horkos_forge_stale_grant_on_unlisted_repo_revoked(
    policy, run_main, monkeypatch
):
    # The agents sweep runs over ALL of the owner's repos (repos/search), and
    # the horkos-forge half mirrors it: a grant on a repo absent from repos.json
    # is stale and must be revoked, not left for the drift check.
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc", "orphan"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": []}
    forge.horkos_permission = {"orphan": "write"}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "revoke horkos-forge on eblume/orphan" in out

    forge.requests.clear()
    code, out = run_main(token="t")  # apply mode
    assert code == 0
    assert any(m == "DELETE" and "horkos-forge" in u for m, u in forge.requests)


def test_horkos_hook_events_include_terminal_action_runs():
    # Forgejo's terminal action-run events are horkos' settlement feed
    # (eblume/horkos#40). They are concrete (non-umbrella) events, so the GET
    # read-back reports them verbatim — SEND and READ must carry the same three
    # names, or the hook reconcile would flap forever.
    terminal = {"action_run_success", "action_run_failure", "action_run_recover"}
    assert terminal <= ara.HORKOS_HOOK_SEND_EVENTS
    assert terminal <= ara.HORKOS_HOOK_READ_EVENTS


def _horkos_hook(hook_id, events, active=True):
    return {
        "id": hook_id,
        "active": active,
        "events": sorted(events),
        "config": {"url": ara.HORKOS_HOOK_URL, "content_type": "json"},
    }


def _release_repo_forge(monkeypatch, hook):
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": []}
    forge.hooks = {"svc": [hook]}
    forge.install(monkeypatch)
    return forge


def test_hook_update_that_sticks_needs_no_secret(policy, run_main, monkeypatch):
    # A drifted hook whose PATCH takes: the read-back agrees, so no secret is
    # resolved and no hook is recreated — the routine, secret-free CI apply.
    policy([_write_repo("svc", release_hook=True)])
    hook = _horkos_hook(14, ara.HORKOS_HOOK_READ_EVENTS - {"push"})
    forge = _release_repo_forge(monkeypatch, hook)
    monkeypatch.delenv("HORKOS_FORGE_HOOK_SECRET", raising=False)
    monkeypatch.setattr(
        ara.subprocess,
        "run",
        lambda *a, **k: pytest.fail("secret must not be resolved"),
    )

    code, out = run_main(token="t")
    assert code == 0
    assert "update horkos release hook on eblume/svc" in out
    assert "recreat" not in out
    methods = [m for m, u in forge.requests if "/hooks" in u]
    assert "PATCH" in methods and "POST" not in methods and "DELETE" not in methods
    assert set(hook["events"]) == set(ara.HORKOS_HOOK_READ_EVENTS)


def test_hook_update_dropped_by_forge_is_recreated(policy, run_main, monkeypatch):
    # The live failure of 2026-09-21..24 (eblume/horkos#40): Forgejo v16.0.2's
    # editHook never maps action_run_*, so the PATCH answers 200 and drops
    # them. The read-back catches it; the hook is recreated through POST
    # (which maps them) with the signing secret, created before the old one
    # is deleted, and the new hook reads back in sync.
    policy([_write_repo("svc", release_hook=True)])
    terminal = {"action_run_success", "action_run_failure", "action_run_recover"}
    hook = _horkos_hook(14, ara.HORKOS_HOOK_READ_EVENTS - terminal)
    forge = _release_repo_forge(monkeypatch, hook)
    forge.patch_drops = terminal
    monkeypatch.setenv("HORKOS_FORGE_HOOK_SECRET", "shh")

    code, out = run_main(token="t")
    assert code == 0, out
    assert "edit did not stick" in out
    assert "recreate horkos release hook on eblume/svc" in out
    hook_calls = [(m, u.rsplit("/", 1)[-1]) for m, u in forge.requests if "/hooks" in u]
    assert hook_calls.index(("POST", "hooks")) < hook_calls.index(("DELETE", "14"))
    assert [h["id"] for h in forge.hooks["svc"]] == [100]
    new = forge.hooks["svc"][0]
    assert set(new["events"]) == set(ara.HORKOS_HOOK_READ_EVENTS)
    assert new["secret_sent"] == "shh"
    assert new["config"]["url"] == ara.HORKOS_HOOK_URL

    # Idempotent: a second run finds the recreated hook in sync.
    forge.requests.clear()
    code, out = run_main(check=True, token="t")
    assert code == 0
    assert "In sync." in out


def test_hook_recreate_without_secret_fails_loud(policy, run_main, monkeypatch):
    # Same drop, but no secret reachable (CI): the recreate must fail with the
    # local-run instructions rather than leave a hook with the old events and
    # report success.
    policy([_write_repo("svc", release_hook=True)])
    terminal = {"action_run_success", "action_run_failure", "action_run_recover"}
    hook = _horkos_hook(14, ara.HORKOS_HOOK_READ_EVENTS - terminal)
    forge = _release_repo_forge(monkeypatch, hook)
    forge.patch_drops = terminal
    monkeypatch.delenv("HORKOS_FORGE_HOOK_SECRET", raising=False)

    def no_op(*args, **kwargs):
        raise FileNotFoundError("op")

    monkeypatch.setattr(ara.subprocess, "run", no_op)

    code, out = run_main(token="t")
    assert code == 1
    assert "edit did not stick" in out
    assert "HORKOS_FORGE_HOOK_SECRET" in out
    assert not any(m == "DELETE" and "/hooks/" in u for m, u in forge.requests)
    assert [h["id"] for h in forge.hooks["svc"]] == [14]


def test_hook_create_reads_back_in_sync(policy, run_main, monkeypatch):
    # A fresh create is read back too: the served hook carries the full event
    # set, and the apply reports create (not recreate) with no PATCH/DELETE.
    policy([_write_repo("svc", release_hook=True)])
    forge = _release_repo_forge(monkeypatch, _horkos_hook(1, ["push"]))
    forge.hooks = {"svc": []}
    monkeypatch.setenv("HORKOS_FORGE_HOOK_SECRET", "shh")

    code, out = run_main(token="t")
    assert code == 0, out
    assert "create horkos release hook on eblume/svc" in out
    methods = [m for m, u in forge.requests if "/hooks" in u]
    assert "PATCH" not in methods and "DELETE" not in methods
    assert set(forge.hooks["svc"][0]["events"]) == set(ara.HORKOS_HOOK_READ_EVENTS)


def test_write_repo_with_actions_disabled_has_no_secrets(policy, run_main, monkeypatch):
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.actions_off = {"svc"}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 0, out
    assert "In sync." in out


def test_secrets_404_with_actions_enabled_is_blocked(policy, run_main, monkeypatch):
    policy([_write_repo("svc")])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.status_overrides = {"/actions/secrets": 404}
    forge.install(monkeypatch)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "Refusing to apply a partial policy" in out


# --- branch protections ---------------------------------------------------


def _rule(**overrides):
    """A complete rule declaration for eblume/svc:main."""
    rule = {
        "repo": "svc",
        "rule_name": "main",
        "enable_push": True,
        "enable_push_whitelist": True,
        "push_whitelist_usernames": ["eblume"],
        "push_whitelist_teams": [],
        "push_whitelist_deploy_keys": False,
        "enable_merge_whitelist": True,
        "merge_whitelist_usernames": ["eblume"],
        "merge_whitelist_teams": [],
        "enable_status_check": True,
        "status_check_contexts": ["Lint / prek (pull_request)", "* (pull_request)"],
        "required_approvals": 0,
        "enable_approvals_whitelist": True,
        "approvals_whitelist_username": ["eblume"],
        "approvals_whitelist_teams": [],
        "block_on_rejected_reviews": True,
        "block_on_official_review_requests": False,
        "block_on_outdated_branch": True,
        "dismiss_stale_approvals": True,
        "ignore_stale_approvals": False,
        "require_signed_commits": False,
        "protected_file_patterns": "*",
        "unprotected_file_patterns": "",
        "apply_to_admins": True,
    }
    rule.update(overrides)
    return rule


def _served(rule):
    """The rule as the API serves it: no `repo`, plus read-only fields."""
    served = {k: v for k, v in rule.items() if k != "repo"}
    served.update(branch_name=rule["rule_name"], created_at="t", updated_at="t")
    return served


@pytest.fixture
def protected(policy, monkeypatch):
    """A read repo `svc` (no secrets endpoint involved) whose protections
    are declared by the returned setter(rules) and served by the forge."""
    policy([{"name": "svc", "access": "read", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "read"}
    forge.install(monkeypatch)

    def declare(*rules):
        ara.PROTECTIONS_PATH.write_text(
            json.dumps({"rules": list(rules)}), encoding="utf-8"
        )

    return forge, declare


def _mutations(forge):
    return [
        (m, u) for m, u in forge.requests if m in ("POST", "PATCH", "PUT", "DELETE")
    ]


def test_protection_in_sync_ignores_list_order(protected, run_main):
    forge, declare = protected
    declare(_rule())
    served = _served(_rule())
    served["status_check_contexts"] = list(reversed(served["status_check_contexts"]))
    forge.protections = {"svc": [served]}

    code, out = run_main(check=True, token="t")
    assert code == 0, out
    assert "In sync." in out


def test_protection_drift_fails_check_naming_field(protected, run_main):
    forge, declare = protected
    declare(_rule())
    forge.protections = {
        "svc": [_served(_rule(status_check_contexts=["Lint / prek (pull_request)"]))]
    }

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "update branch protection eblume/svc:main (status_check_contexts)" in out
    assert not _mutations(forge)


def test_protection_update_patches_only_diff_and_reads_back(protected, run_main):
    forge, declare = protected
    declare(_rule())
    forge.protections = {
        "svc": [_served(_rule(status_check_contexts=["Lint / prek (pull_request)"]))]
    }

    code, out = run_main(token="t")
    assert code == 0, out
    patches = [u for m, u in _mutations(forge) if m == "PATCH"]
    assert patches == [
        "https://forge.ops.eblu.me/api/v1/repos/eblume/svc/branch_protections/main"
    ]
    assert (
        forge.protections["svc"][0]["status_check_contexts"]
        == _rule()["status_check_contexts"]
    )
    assert "update branch protection eblume/svc:main" in out


def test_protection_missing_rule_is_created(protected, run_main):
    forge, declare = protected
    declare(_rule())

    code, out = run_main(token="t")
    assert code == 0, out
    assert [m for m, _ in _mutations(forge)] == ["POST"]
    assert forge.protections["svc"][0]["rule_name"] == "main"


def test_protection_patch_that_does_not_stick_fails(protected, run_main):
    forge, declare = protected
    declare(_rule())
    forge.protections = {"svc": [_served(_rule(status_check_contexts=[]))]}
    forge.protection_patch_drops = {"status_check_contexts"}

    code, out = run_main(token="t")
    assert code == 1
    assert "did not converge" in out
    assert "status_check_contexts" in out


def test_protection_refused_under_ci_token(protected, run_main, monkeypatch):
    forge, declare = protected
    declare(_rule())
    forge.protections = {"svc": [_served(_rule(status_check_contexts=[]))]}
    monkeypatch.setenv("FORGE_REPO_WRITE_TOKEN", "ci")

    code, out = run_main()
    assert code == 1
    assert "Refusing 1 branch protection change(s) under the CI token" in out
    assert not _mutations(forge)


def test_protection_ci_token_still_reports_drift(protected, run_main, monkeypatch):
    forge, declare = protected
    declare(_rule())
    forge.protections = {"svc": [_served(_rule(status_check_contexts=[]))]}
    monkeypatch.setenv("FORGE_REPO_WRITE_TOKEN", "ci")

    code, out = run_main(check=True)
    assert code == 1
    assert "update branch protection eblume/svc:main" in out


def test_protection_undeclared_live_rule_left_alone(protected, run_main):
    forge, declare = protected
    declare(_rule())
    forge.protections = {
        "svc": [_served(_rule()), _served(_rule(rule_name="release/*"))]
    }

    code, out = run_main(check=True, token="t")
    assert code == 0, out
    assert "'release/*' not in" in out


@pytest.mark.parametrize("bot", ["agents", "horkos-forge", "Horkos-Forge"])
@pytest.mark.parametrize(
    "field",
    [
        "push_whitelist_usernames",
        "merge_whitelist_usernames",
        "approvals_whitelist_username",
    ],
)
def test_protection_bot_whitelist_refused_at_load(protected, run_main, bot, field):
    forge, declare = protected
    declare(_rule(**{field: ["eblume", bot]}))

    code, out = run_main(token="t")
    assert code == 1
    assert "BOT_WHITELIST_FENCE" in out
    assert not forge.requests


def test_protection_partial_rule_refused(protected, run_main):
    _forge, declare = protected
    rule = _rule()
    del rule["apply_to_admins"]
    declare(rule)

    code, out = run_main(token="t")
    assert code == 1
    assert "does not declare apply_to_admins" in out


def test_protection_unknown_field_refused(protected, run_main):
    _forge, declare = protected
    declare(_rule(enable_force_push=True))

    code, out = run_main(token="t")
    assert code == 1
    assert "unknown field(s) enable_force_push" in out


def test_protection_unreadable_is_blocked(protected, run_main, monkeypatch):
    forge, declare = protected
    declare(_rule())
    forge.status_overrides = {"/branch_protections": 403}
    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "Refusing to apply a partial policy" in out


def test_real_protection_policy_loads():
    """The checked-in forge/branch-protections.json passes its own fences."""
    rules = ara.load_protections(("agents", "horkos-forge"))
    assert {(r["repo"], r["rule_name"]) for r in rules} >= {("blumeops", "main")}


# --- horkos-forge blast-radius invariants (folded in from horkos-forge-drift) --


def _forge_client(forge, monkeypatch):
    """A client backed by the fake, made through the module's (patched)
    httpx.Client so absolute URLs work as in production."""
    forge.install(monkeypatch)
    return ara.httpx.Client(
        base_url=ara.FORGE_URL, headers={"Authorization": "token t"}, timeout=30.0
    )


def test_invariant_horkos_is_site_admin(policy, monkeypatch):
    policy([{"name": "svc", "access": "read", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.horkos_user = _valid_user(is_admin=True)
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_site_admin(c, findings)
    assert any("site admin" in f for f in findings.failures)


def test_invariant_horkos_not_admin_is_ok(policy, monkeypatch):
    policy([{"name": "svc", "access": "read", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.horkos_user = _valid_user(is_admin=False)
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_site_admin(c, findings)
    assert findings.failures == []


def test_invariant_horkos_user_unreadable_fails(policy, monkeypatch):
    policy([{"name": "svc", "access": "read", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.horkos_user = None  # 404
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_site_admin(c, findings)
    assert any("could not verify" in f for f in findings.failures)


def test_invariant_main_whitelist_allows_non_eblume(policy, monkeypatch):
    policy([{"name": "svc", "access": "read", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc", "blumeops"]
    forge.protections = {
        "blumeops": [
            _blumeops_main_rule(push_whitelist_usernames=["eblume", "mallory"])
        ]
    }
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_main_whitelist(c, "eblume", findings)
    assert any("mallory" in f for f in findings.failures)


def test_invariant_main_protection_missing_fails(policy, monkeypatch):
    policy([{"name": "svc", "access": "read", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc", "blumeops"]
    forge.protections = {"blumeops": []}
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_main_whitelist(c, "eblume", findings)
    assert any("no branch protection" in f for f in findings.failures)


def test_invariant_main_whitelist_valid_is_ok(policy, monkeypatch):
    policy([{"name": "svc", "access": "read", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc", "blumeops"]
    forge.protections = {"blumeops": [_blumeops_main_rule()]}
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_main_whitelist(c, "eblume", findings)
    assert findings.failures == []


# --- PR-check semantics (same-repo PRs only) ---------------------------------


def _base_state(monkeypatch, repos, protections=()):
    """Point the base-state readers the --pr-base-ref path uses at these."""
    monkeypatch.setattr(
        ara, "read_policies_at", lambda ref: ara._policies_dict({"repos": repos})
    )
    monkeypatch.setattr(ara, "read_protections_at", lambda ref: list(protections))


def test_pr_check_intended_only_is_green(policy, run_main, monkeypatch, tmp_path):
    # A repos.json access change (write→read) the PR intends: green, the
    # intended line in the report file, no unexpected drift.
    policy([{"name": "svc", "access": "read", "pool": "none"}])  # head declares read
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}  # live still write — the PR's read is pending
    forge.secrets = {"svc": []}  # write repo, no secrets
    forge.horkos_user = _valid_user(is_admin=False)
    forge.protections = {"blumeops": [_blumeops_main_rule()]}
    forge.install(monkeypatch)
    _base_state(monkeypatch, [{"name": "svc", "access": "write", "pool": "none"}])

    report = tmp_path / "notice.md"
    code, out = run_main(
        check=True, token="t", pr_base_ref="main", report_file=str(report)
    )
    assert code == 0, out
    assert "Unexpected drift" not in out
    assert "intended drift only" in out
    assert "`eblume/svc` agents access: write -> read" in report.read_text()


def test_pr_check_unexpected_drift_fails(policy, run_main, monkeypatch, tmp_path):
    # A protection on a repo the PR leaves unchanged (head == base declare it),
    # missing on the live forge: base plans a create the PR did not intend ->
    # unexpected -> fails.
    policy([{"name": "svc", "access": "write", "pool": "none"}])
    # HEAD's declared protections (PROTECTIONS_PATH) also carry other:main, so
    # the PR does not touch that protection.
    ara.PROTECTIONS_PATH.write_text(
        __import__("json").dumps({"rules": [_rule(repo="other")]}), encoding="utf-8"
    )
    forge = FakeForge()
    forge.repos = ["svc", "other", "blumeops"]
    forge.secrets = {"svc": []}
    forge.permission = {"svc": "write"}  # svc in sync
    forge.horkos_user = _valid_user(is_admin=False)
    forge.protections = {"blumeops": [_blumeops_main_rule()]}  # `other` has none live
    forge.install(monkeypatch)
    # BASE declares other:main too (same as head), and has the invariant state.
    _base_state(
        monkeypatch,
        [{"name": "svc", "access": "write", "pool": "none"}],
        [_rule(repo="other")],
    )

    report = tmp_path / "notice.md"
    code, out = run_main(
        check=True, token="t", pr_base_ref="main", report_file=str(report)
    )
    assert code == 1, out
    assert "UNEXPECTED drift" in out
    assert "other:main" in out
    # A failing PR still posts its notice (even with nothing intended), so the
    # red reason is read; it carries the [X] unexpected section.
    assert report.exists()
    assert "[X]" in report.read_text()


def test_pr_check_fork_pr_skips(policy, run_main, monkeypatch):
    # No token + --skip-if-no-token: the fork/agent-PR path exits 0 before any
    # PR categorization (a green tick that checked nothing is worse than none).
    policy([_write_repo("svc")])

    code, out = run_main(check=True, skip_if_no_token=True, pr_base_ref="main")
    assert code == 0
    assert "SKIPPED" in out
