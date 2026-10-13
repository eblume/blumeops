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
import subprocess

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

    PROTECTIONS_PATH goes to a scratch file declaring no rules, and
    RUNNERS_PATH/RUNBOOK_PATH to scratch copies of the real declared runner
    topology + runbook, so tests that are not about branch protection or the
    runner checks never see the repo's live files (#1526)."""

    def set_repos(repos):
        path = tmp_path / "repos.json"
        path.write_text(json.dumps(_policy(repos)), encoding="utf-8")
        return path

    monkeypatch.setattr(ara, "POLICY_PATH", tmp_path / "repos.json")
    protections = tmp_path / "branch-protections.json"
    protections.write_text(json.dumps({"rules": []}), encoding="utf-8")
    runners = tmp_path / "runners.json"
    runners.write_text((ROOT / "forge" / "runners.json").read_text(), encoding="utf-8")
    runbook = tmp_path / "runbook-forgejo-ci.md"
    runbook.write_text(
        (ROOT / "docs" / "how-to" / "runbooks" / "runbook-forgejo-ci.md").read_text(),
        encoding="utf-8",
    )
    # No declared Actions-secret names by default: the name-drift check (on
    # every --check) iterates the declared-state file's repos, and a test that
    # is not about Actions secrets should not also see the real file's list.
    monkeypatch.setattr(ara, "declared_actions_secret_names", dict)
    monkeypatch.setattr(ara, "PROTECTIONS_PATH", protections)
    monkeypatch.setattr(ara, "RUNNERS_PATH", runners)
    # RUNBOOK_PATH arrives with the runbook check (#1526); setattr with
    # raising=False keeps this fixture valid before that commit.
    monkeypatch.setattr(ara, "RUNBOOK_PATH", runbook, raising=False)
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
            dict[str, list[str] | None] | None
        ) = {}  # repo -> names; a whole-None value or a per-repo None = 403s
        self.secrets_body: dict | list | None = None  # raw-body override (shape test)
        # The values half's record: (method, repo, name, value-as-put) for
        # every PUT/DELETE the script issues against /actions/secrets/<name>;
        # value is None for a DELETE, the data payload for a PUT.
        self.secret_writes: list[tuple[str, str, str, str | None]] = []
        # Non-None: answer every PUT/DELETE of an Actions secret with this
        # status instead of 201/204 (the PUT-failure test forces a 500).
        self.secret_status: int | None = None
        self.hooks_status = 200  # non-200: the hooks list is unreadable
        self.hooks: dict[str, list[dict]] = {}  # repo -> served hook objects
        # Events a PATCH silently drops, mimicking Forgejo v16.0.2's editHook
        # (which never maps action_run_*); POST maps everything.
        self.patch_drops: set[str] = set()
        self.next_hook_id = 100
        self.actions_off: set[str] = set()  # repos whose Actions unit is disabled
        # repo -> {workflow path: raw content}; served for the runner-label
        # scan's /contents listing and raw fetches.
        self.workflows: dict[str, dict[str, str]] = {}
        # Path suffix -> status served instead of the real answer.
        self.status_overrides: dict[str, int] = {}
        # The blumeops:main rule is seeded as a valid live default (whitelisted
        # to eblume) — it is the environment fact the blast-radius invariant
        # asserts, present on the live forge like any other repo's protections.
        # Tests that exercise it override the whole protections dict.
        self.protections: dict[str, list[dict]] = {"blumeops": [_blumeops_main_rule()]}
        # Fields a protection PATCH silently ignores (a 200 that changes nothing).
        self.protection_patch_drops: set[str] = set()
        # The folded-in horkos-forge blast-radius invariants read these. A fresh
        # forge defaults to a valid (active, non-admin) bot user and a valid
        # blumeops:main rule whitelisted to eblume — the passing invariant state,
        # so a test that exercises the --check drift path does not also fail the
        # blast-radius invariants; the invariant tests override either.
        self.horkos_user: dict | None = {
            "is_admin": False,
            "active": True,
            "deactivated": False,
        }

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
        if path.startswith("/api/v1/users/"):
            # Owner lookup for the runner-scope id fallback (owner:<id>): any
            # other login is served with a stable id.
            return httpx.Response(200, json={"id": 1, "login": path.rsplit("/", 1)[-1]})
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
            if tail and tail[0] == "contents":
                # The /contents listing for a directory; a repo with no
                # workflow files serves an empty list (a missing dir is 404).
                directory = "/".join(tail[1:])
                entries = []
                for path in sorted(self.workflows.get(repo, {})):
                    if path.startswith(f"{directory}/"):
                        entries.append({"name": path.rsplit("/", 1)[-1], "path": path})
                return httpx.Response(200, json=entries)
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
                    json={
                        "name": repo,
                        "id": 100
                        + (self.repos.index(repo) if repo in self.repos else 0),
                        "has_actions": repo not in self.actions_off,
                        "default_branch": "main",
                    },
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
            if len(tail) == 3 and tail[0] == "actions" and tail[1] == "secrets":
                name = tail[2]
                if request.method in ("PUT", "DELETE"):
                    if self.secret_status is not None:
                        return httpx.Response(
                            self.secret_status, json={"message": "forced"}
                        )
                    if request.method == "PUT":
                        body = json.loads(request.content)
                        self.secret_writes.append(("PUT", repo, name, body.get("data")))
                    else:
                        self.secret_writes.append(("DELETE", repo, name, None))
                    return httpx.Response(201 if request.method == "PUT" else 204)
                return httpx.Response(404, json={"message": "not found"})
        if len(parts) >= 6 and parts[2:4] == ["raw", "branch"]:
            # Raw file fetch: /{owner}/{repo}/raw/branch/{ref}/{path}.
            content = self.workflows.get(parts[1], {}).get("/".join(parts[5:]))
            if content is None:
                return httpx.Response(404, json={"message": "no such file"})
            return httpx.Response(200, text=content)
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
    forge.protections.update({"svc": [served]})

    code, out = run_main(check=True, token="t")
    assert code == 0, out
    assert "In sync." in out


def test_protection_drift_fails_check_naming_field(protected, run_main):
    forge, declare = protected
    declare(_rule())
    forge.protections.update(
        {"svc": [_served(_rule(status_check_contexts=["Lint / prek (pull_request)"]))]}
    )

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
    forge.protections.update({"svc": [_served(_rule(status_check_contexts=[]))]})
    monkeypatch.setenv("FORGE_REPO_WRITE_TOKEN", "ci")

    code, out = run_main(check=True)
    assert code == 1
    assert "update branch protection eblume/svc:main" in out


def test_protection_undeclared_live_rule_left_alone(protected, run_main):
    forge, declare = protected
    declare(_rule())
    forge.protections.update(
        {"svc": [_served(_rule()), _served(_rule(rule_name="release/*"))]}
    )

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
    forge.status_overrides = {"/eblume/svc/branch_protections": 403}
    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "Refusing to apply a partial policy" in out


def test_real_protection_policy_loads():
    """The checked-in forge/branch-protections.json passes its own fences."""
    rules = ara.load_protections(("agents", "horkos-forge"))
    assert {(r["repo"], r["rule_name"]) for r in rules} >= {("blumeops", "main")}


# --- runner-label policy (derived from forge/runners.json, #1526) --------


def _runner(name, labels, scope, privileged=True):
    return {
        "name": name,
        "host": "h",
        "labels": labels,
        "scope": scope,
        "capacity": 1,
        "privileged": privileged,
        "unit": "u",
    }


def test_derived_label_policy_matches_checked_in_runners_json():
    """The equivalence assertion: the real forge/runners.json derives exactly
    the gated map the policy used to hardcode — touching the file re-derives
    the gate instead of editing this test."""
    data = json.loads((ROOT / "forge" / "runners.json").read_text())
    assert ara.derive_privileged_label_policy(data["runners"]) == {
        "indri": frozenset({"blumeops"}),
        "indri-priv": frozenset({"blumeops"}),
        "priv": frozenset({"blumeops"}),
        "nix-container-builder": frozenset(
            {"blumeops", "horkos", "talos", "hephaestus"}
        ),
    }


def test_derived_policy_instance_runner_ungates_label():
    """An instance-scoped runner serves every repo, so its label is not gated:
    the map has no entry for it at all."""
    assert (
        ara.derive_privileged_label_policy([_runner("r", ["priv"], "instance")]) == {}
    )


def test_derived_policy_mixed_instance_and_repo_scope_ungates():
    """One instance-scoped registrant is enough to ungate: the label can be
    taken by a runner that serves every repo."""
    runners = [
        _runner("a", ["priv"], "eblume/blumeops"),
        _runner("b", ["priv"], "instance"),
    ]
    assert ara.derive_privileged_label_policy(runners) == {}


def test_derived_policy_multiple_repo_scopes_union():
    """Several repo-scoped registrants union their repos into the allowed set."""
    runners = [
        _runner("a", ["priv"], "eblume/blumeops"),
        _runner("b", ["priv"], "eblume/horkos"),
    ]
    assert ara.derive_privileged_label_policy(runners) == {
        "priv": frozenset({"blumeops", "horkos"})
    }


def test_derived_policy_host_suffix_stripped():
    """`priv:host` contributes the base `priv`, never a `host` label; two
    runners sharing the base but with different suffixes still gate once."""
    runners = [
        _runner("a", ["priv:host"], "eblume/blumeops"),
        _runner("b", ["priv:other"], "eblume/horkos"),
    ]
    assert ara.derive_privileged_label_policy(runners) == {
        "priv": frozenset({"blumeops", "horkos"})
    }


def test_derived_policy_per_label_scope():
    """The gate is per label, not per runner: an instance-scoped runner's
    scope ungates only the labels it advertises, and does not leak into a
    label only the repo-scoped runner carries."""
    runners = [
        _runner("a", ["mix"], "instance"),
        _runner("b", ["mix", "gated"], "eblume/blumeops"),
    ]
    assert ara.derive_privileged_label_policy(runners) == {
        "gated": frozenset({"blumeops"})
    }


def test_derived_policy_owner_scope_ungates_label():
    """An owner-only scope serves every repo of that owner (the live leg's
    _serves_repo treats `scope == owner` as serving all of them), so its
    label is not gated: a single owner-scoped runner leaves the map empty
    rather than contributing a repo name nothing matches."""
    assert ara.derive_privileged_label_policy([_runner("r", ["priv"], "eblume")]) == {}


def test_derived_policy_mixed_owner_and_instance_scope_ungates():
    """One instance-scoped and one owner-scoped registrant both serve every
    repo, so the label is ungated."""
    runners = [
        _runner("a", ["priv"], "instance"),
        _runner("b", ["priv"], "eblume"),
    ]
    assert ara.derive_privileged_label_policy(runners) == {}


# --- runner-label workflow scan (#1358, #1515, #1526) -----------------------


def _workflow_yml(runs_on):
    return f"jobs:\n  ci:\n    runs-on: {runs_on}\n"


def test_workflow_undeclared_label_fails(policy, run_main, monkeypatch):
    """Acceptance: a repo whose workflow runs on a label no runner declares
    fails --check naming the label."""
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.workflows = {
        "svc": {".forgejo/workflows/ci.yml": _workflow_yml("some-unknown-label")}
    }
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "live_runner_series", list)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "some-unknown-label" in out
    assert "no workflow targets an undeclared runner label" not in out


def test_plain_glue_word_as_bare_label_fails(policy):
    """A plain (non-expression) `runs-on: push` names the glue word `push`
    as a bare label: the glue excuse requires the raw value that named the
    token to be a `${{ }}` expression, so the declaration leg fails it."""
    policy([])
    findings = ara.Findings()
    ara.check_unknown_labels("eblume", findings, {"svc": {"push": "push"}})
    assert any(
        "`push` is not a runner label any runner declares" in f
        for f in findings.failures
    )


def test_plain_suffix_word_as_bare_label_fails(policy):
    """A plain `runs-on: host` names the declared `:host` suffix as a bare
    label: the suffix excuse requires the raw value to contain `:`, so it
    fails the declaration leg (only `priv:host`'s `host` is excused)."""
    policy([])
    findings = ara.Findings()
    ara.check_unknown_labels("eblume", findings, {"svc": {"host": "host"}})
    assert any(
        "`host` is not a runner label any runner declares" in f
        for f in findings.failures
    )


def test_expression_ternary_still_passes(policy):
    """The real workflows' `${{ github.event_name == 'pull_request' &&
    'indri-build' || 'indri' }}` ternary still passes: every token is glue
    (the raw value contains `${{`) or a declared label base."""
    policy([])
    ternary = "${{ github.event_name == 'pull_request' && 'indri-build' || 'indri' }}"
    findings = ara.Findings()
    ara.check_unknown_labels(
        "eblume",
        findings,
        {
            "blumeops": {
                token: ternary
                for token in (
                    "github",
                    "event_name",
                    "pull_request",
                    "indri-build",
                    "indri",
                )
            }
        },
    )
    assert findings.failures == []


def test_workflow_declared_labels_pass(policy, run_main, monkeypatch):
    """Allowed repo targeting a gated label, with the label live-registered
    for it: all three legs green."""
    policy([{"name": "blumeops", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["blumeops"]
    forge.workflows = {
        "blumeops": {".forgejo/workflows/ci.yml": _workflow_yml("priv:host")}
    }
    forge.install(monkeypatch)
    monkeypatch.setattr(
        ara,
        "live_runner_series",
        lambda: [
            {
                "runner": "ringtail-priv-runner",
                "labels": "priv:host",
                "scope": "eblume/blumeops",
            }
        ],
    )

    code, out = run_main(check=True, token="t")
    assert code == 0, out
    assert "no workflow targets an undeclared runner label" in out
    assert "every workflow runs-on label is served by a live runner" in out


def test_workflow_gated_label_disallowed_repo_fails(policy, run_main, monkeypatch):
    """A repo targeting a gated label it is not declared to fails the gate
    even when another runner live-registers the label."""
    policy([{"name": "horkos", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["horkos"]
    forge.workflows = {"horkos": {".forgejo/workflows/ci.yml": _workflow_yml("priv")}}
    forge.install(monkeypatch)
    monkeypatch.setattr(
        ara,
        "live_runner_series",
        lambda: [
            {
                "runner": "ringtail-priv-runner",
                "labels": "priv:host",
                "scope": "eblume/blumeops",
            }
        ],
    )

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "`priv` is targeted only by its declared repos" in out
    assert "eblume/horkos" in out


def test_workflow_label_exception_is_exempt(policy, run_main, monkeypatch):
    """A (repo, label) pair listed in runners.json's label_exceptions does
    not fail the declaration leg nor the live leg."""
    policy([{"name": "gamedev", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["gamedev"]
    forge.workflows = {
        "gamedev": {".forgejo/workflows/ci.yml": _workflow_yml("docker")}
    }
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "live_runner_series", list)

    code, out = run_main(check=True, token="t")
    assert code == 0, out


def test_live_leg_wrong_scope_fails(policy, run_main, monkeypatch):
    """A declared label registered only by a runner scoped to another repo:
    the targeting repo lacks a live server, so the check fails naming the
    runner that holds the label elsewhere."""
    policy([{"name": "horkos", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["horkos"]
    forge.workflows = {
        "horkos": {".forgejo/workflows/ci.yml": _workflow_yml("nix-container-builder")}
    }
    forge.install(monkeypatch)
    monkeypatch.setattr(
        ara,
        "live_runner_series",
        lambda: [
            {
                "runner": "ringtail-nix-builder-blumeops",
                "labels": "nix-container-builder:host",
                "scope": "eblume/blumeops",
            }
        ],
    )

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "nix-container-builder" in out
    assert "ringtail-nix-builder-blumeops" in out
    assert "no live runner scoped to eblume/horkos" in out


def test_live_leg_instance_scope_serves(policy, run_main, monkeypatch):
    """The instance-scoped runner serves every repo, so its label passes the
    live leg for any targeting repo."""
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.workflows = {
        "svc": {".forgejo/workflows/ci.yml": _workflow_yml("indri-build")}
    }
    forge.install(monkeypatch)
    monkeypatch.setattr(
        ara,
        "live_runner_series",
        lambda: [
            {"runner": "indri-build", "labels": "indri-build", "scope": "instance"}
        ],
    )

    code, out = run_main(check=True, token="t")
    assert code == 0, out
    assert "every workflow runs-on label is served by a live runner" in out


def test_live_leg_prometheus_down_is_unknown(policy, run_main, monkeypatch):
    """An unreachable Prometheus is an unknown, which fails --check."""
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.workflows = {"svc": {".forgejo/workflows/ci.yml": _workflow_yml("priv")}}
    forge.install(monkeypatch)

    def boom():
        raise httpx.TransportError("boom")

    monkeypatch.setattr(ara, "live_runner_series", boom)

    code, out = run_main(check=True, token="t")
    assert code == 1
    assert "prometheus unreachable" in out


def test_live_runner_series_parses_vector_response(monkeypatch):
    """The live leg parses a Prometheus vector body into per-series
    (runner, labels, scope) dicts; a series without a scope defaults to
    instance. live_runner_series opens a fresh httpx.Client, so stub the
    class with one that serves the canned body."""
    canned = {
        "status": "success",
        "data": {
            "resultType": "vector",
            "result": [
                {
                    "metric": {
                        "runner": "ringtail-priv-runner",
                        "labels": "priv:host",
                        "scope": "eblume/blumeops",
                    },
                    "value": [1700000000.0, "1"],
                },
                {
                    "metric": {"runner": "indri-build", "labels": "indri-build"},
                    "value": [1700000001.0, "1"],
                },
            ],
        },
    }

    class StubClient:
        def __init__(self, *args, **kwargs):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *exc):
            return False

        def get(self, url, params=None):
            return httpx.Response(200, json=canned, request=httpx.Request("GET", url))

    monkeypatch.setattr(ara.httpx, "Client", StubClient)
    assert ara.live_runner_series() == [
        {
            "runner": "ringtail-priv-runner",
            "labels": "priv:host",
            "scope": "eblume/blumeops",
        },
        {"runner": "indri-build", "labels": "indri-build", "scope": "instance"},
    ]


# --- runbook runner table (#1526) -------------------------------------------


ROWS = [
    ("indri-runner", "LaunchAgent `mcquack.eblume.forgejo-runner` (user `erichblume`)"),
    (
        "indri-build",
        "LaunchAgent `mcquack.eblume.forgejo-runner-build` (user `indri-build`, waits for colima)",
    ),
    (
        "ringtail-nix-builder-blumeops",
        "`gitea-runner-nix_container_builder_blumeops.service`",
    ),
    (
        "ringtail-nix-builder-horkos",
        "`gitea-runner-nix_container_builder_horkos.service`",
    ),
    (
        "ringtail-nix-builder-hephaestus",
        "`gitea-runner-nix_container_builder_hephaestus.service`",
    ),
    (
        "ringtail-nix-builder-talos",
        "`gitea-runner-nix_container_builder_talos.service`",
    ),
    ("ringtail-priv-runner", "`gitea-runner-priv.service`"),
]


def _runbook_md(rows):
    body = "\n".join(f"| `{name}` | [[host]] | {service} |" for name, service in rows)
    return (
        "## ForgejoRunnerOffline\n\nSome prose.\n\n"
        "| Runner | Host | Service |\n"
        "|--------|------|---------|\n"
        f"{body}\n\nMore prose after the table.\n"
    )


def _runbook_findings(monkeypatch, tmp_path, content):
    path = tmp_path / "runbook.md"
    path.write_text(content, encoding="utf-8")
    monkeypatch.setattr(ara, "RUNBOOK_PATH", path)
    findings = ara.Findings()
    ara.check_runbook_runner_table(findings)
    return findings


def test_runbook_table_consistent_is_ok(policy):
    """The checked-in runbook + runners.json pair passes: every declared
    runner listed once with its unit in backticks."""
    findings = ara.Findings()
    ara.check_runbook_runner_table(findings)
    assert findings.failures == []


def test_runbook_table_wrong_unit_fails(monkeypatch, tmp_path):
    rows = [(n, s) for n, s in ROWS]
    rows[0] = ("indri-runner", "LaunchAgent `wrong.unit.service`")
    findings = _runbook_findings(monkeypatch, tmp_path, _runbook_md(rows))
    assert any("mcquack.eblume.forgejo-runner" in f for f in findings.failures)


def test_runbook_table_missing_row_fails(monkeypatch, tmp_path):
    rows = [(name, service) for name, service in ROWS if name != "ringtail-priv-runner"]
    findings = _runbook_findings(monkeypatch, tmp_path, _runbook_md(rows))
    assert any(
        "ringtail-priv-runner" in f and "missing" in f for f in findings.failures
    )


def test_runbook_table_extra_row_fails(monkeypatch, tmp_path):
    rows = list(ROWS) + [("fake-runner", "`fake.service`")]
    findings = _runbook_findings(monkeypatch, tmp_path, _runbook_md(rows))
    assert any(
        "fake-runner" in f and "not a declared runner" in f for f in findings.failures
    )


def test_runbook_table_stops_at_next_heading(monkeypatch, tmp_path):
    """A second table under a later `## ` heading is not misread as runner
    rows: the parser stops collecting at the next heading, so the scratch
    runbook parses without false failures."""
    body = "\n".join(f"| `{name}` | [[host]] | {service} |" for name, service in ROWS)
    content = (
        "## ForgejoRunnerOffline\n\nSome prose.\n\n"
        "| Runner | Host | Service |\n"
        "|--------|------|---------|\n"
        f"{body}\n\n"
        "## Some Other Section\n\n"
        "| Thing | Other |\n"
        "|-------|-------|\n"
        "| `not-a-runner` | whatever |\n"
    )
    findings = _runbook_findings(monkeypatch, tmp_path, content)
    assert findings.failures == []


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


# --- Actions-secret name drift (names read from the declared-state file) ----


def _declared(monkeypatch, mapping):
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: dict(mapping))


def test_actions_secret_names_in_sync(policy, monkeypatch):
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["A", "B"]}
    _declared(monkeypatch, {"svc": ["A", "B"]})
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_actions_secret_names(c, "eblume", findings)
    assert findings.failures == []


def test_actions_secret_names_missing_fails(policy, monkeypatch):
    # Declared but not live: the role PUTs it, so a missing name is drift.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["A"]}
    _declared(monkeypatch, {"svc": ["A", "B"]})
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_actions_secret_names(c, "eblume", findings)
    assert any("missing: B" in f for f in findings.failures)


def test_actions_secret_names_extra_fails(policy, monkeypatch):
    # Live but not declared: the role DELETEs it, so an extra name is drift
    # (the cv `secrets: []` case, where any live name is undeclared).
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["A", "STALE"]}
    _declared(monkeypatch, {"svc": ["A"]})
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_actions_secret_names(c, "eblume", findings)
    assert any("STALE" in f and "undeclared" in f for f in findings.failures)


def test_actions_secret_names_empty_declaration_in_sync(policy, monkeypatch):
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": []}
    _declared(monkeypatch, {"svc": []})
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_actions_secret_names(c, "eblume", findings)
    assert findings.failures == []


def test_actions_secret_names_unreadable_fails(policy, monkeypatch):
    # `secrets` keyed with repo -> None makes the endpoint 403: a check that
    # cannot see is a failure, not a pass.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": None}
    _declared(monkeypatch, {"svc": ["A"]})
    with _forge_client(forge, monkeypatch) as c:
        findings = ara.Findings()
        ara.check_actions_secret_names(c, "eblume", findings)
    assert any("could not read" in f for f in findings.failures)


def test_declared_actions_secret_names_parses_file(tmp_path, monkeypatch):
    # The real declared-state shape: names only — empty repo lists kept (they
    # are the authoritative-delete case), names validated against the in-code
    # ACTIONS_SECRET_SOURCES allowlist before they parse.
    path = tmp_path / "actions-secrets.json"
    path.write_text(
        json.dumps(
            {
                "repos": [
                    {
                        "repo": "blumeops",
                        "secrets": ["FORGE_REPO_WRITE_TOKEN", "BLUMEOPS_CI_OP_TOKEN"],
                    },
                    {"repo": "cv", "secrets": []},
                ]
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr(ara, "ACTIONS_SECRETS_PATH", path)
    names = ara.declared_actions_secret_names()
    assert names["blumeops"] == ["FORGE_REPO_WRITE_TOKEN", "BLUMEOPS_CI_OP_TOKEN"]
    assert names["cv"] == []


def test_declared_actions_secret_names_malformed_fails(tmp_path, monkeypatch):
    # A broken read must fail loudly (the real file can only fail the check),
    # never parse to an empty dict that would pass against a secret-carrying
    # live forge.
    path = tmp_path / "actions-secrets.json"
    path.write_text("{not json", encoding="utf-8")
    monkeypatch.setattr(ara, "ACTIONS_SECRETS_PATH", path)
    with pytest.raises(typer.Exit):
        ara.declared_actions_secret_names()


def test_declared_actions_secret_names_unknown_source_fails(tmp_path, monkeypatch):
    # A declared name with no entry in the in-code ACTIONS_SECRET_SOURCES
    # allowlist fails loudly: the file stays names-only, so a routine-looking
    # data edit cannot point a repo's CI secrets at a vault item.
    path = tmp_path / "actions-secrets.json"
    path.write_text(
        json.dumps({"repos": [{"repo": "blumeops", "secrets": ["NOT_A_REAL_SOURCE"]}]}),
        encoding="utf-8",
    )
    monkeypatch.setattr(ara, "ACTIONS_SECRETS_PATH", path)
    with pytest.raises(typer.Exit):
        ara.declared_actions_secret_names()


def test_check_flags_actions_secret_name_drift(policy, run_main, monkeypatch):
    # End-to-end: grants in sync, but a live name the role no longer declares
    # fails --check — the name drift that previously only a human's
    # provision-indri --check would have caught.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["STALE"]}
    forge.horkos_user = _valid_user(is_admin=False)
    forge.protections = {"blumeops": [_blumeops_main_rule()]}
    forge.install(monkeypatch)
    _declared(monkeypatch, {"svc": []})

    code, out = run_main(check=True, token="t")
    assert code == 1, out
    assert "Actions secret names" in out
    assert "STALE" in out


def test_check_actions_secret_names_in_sync_is_green(policy, run_main, monkeypatch):
    # The positive end-to-end: grants in sync and the live names matching the
    # role's declarations pass the whole --check (the baseline the first real
    # weekly run should report).
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["A", "B"]}
    forge.horkos_user = _valid_user(is_admin=False)
    forge.protections = {"blumeops": [_blumeops_main_rule()]}
    forge.install(monkeypatch)
    _declared(monkeypatch, {"svc": ["A", "B"]})

    code, out = run_main(check=True, token="t")
    assert code == 0, out
    assert "In sync." in out


# --- Actions-secret values half (human apply vs CI report) -------------------


class _FakeOp:
    """Stand-in for subprocess.run's `op read`: returns a fixed stdout, or
    raises CalledProcessError when built with fail=True. Records every call so
    tests can assert op was / wasn't reached."""

    def __init__(self, fail=False):
        self.fail = fail
        self.calls: list[list[str]] = []

    def __call__(self, args, **kwargs):
        self.calls.append(args)
        if self.fail:
            raise subprocess.CalledProcessError(1, args)
        return subprocess.CompletedProcess(
            args, 0, stdout="secret-value-XYZ\n", stderr=""
        )


def _op_must_not_run(*_args, **_kwargs):
    raise AssertionError("op must not run")


def test_secret_values_applied_on_human_run(policy, run_main, monkeypatch):
    # Human apply: declared A is PUT (value from op, never echoed), the stale
    # live STALE is DELETE — the idempotent 201/204 shape the role had.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["A", "STALE"]}
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": ["A"]})
    monkeypatch.setattr(ara, "ACTIONS_SECRET_SOURCES", {("svc", "A"): "op://v/i/f"})
    op = _FakeOp()
    monkeypatch.setattr(ara.subprocess, "run", op)

    code, out = run_main(token="t")
    assert code == 0, out
    assert forge.secret_writes == [
        ("PUT", "svc", "A", "secret-value-XYZ"),
        ("DELETE", "svc", "STALE", None),
    ]
    assert "PUT eblume/svc:A" in out
    assert "DELETE eblume/svc:STALE" in out
    assert "secret-value-XYZ" not in out
    assert "Applied 2 change(s)." in out


def test_secret_values_reported_not_applied_under_ci_token(
    policy, run_main, monkeypatch
):
    # CI apply: name drift is reported on one dim line, never PUT/DELETE'd,
    # and op is never reached — exit 0 (the name drift is the weekly --check's
    # job).
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": []}
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": ["A"]})
    monkeypatch.setattr(ara, "ACTIONS_SECRET_SOURCES", {("svc", "A"): "op://v/i/f"})
    monkeypatch.setattr(ara.subprocess, "run", _op_must_not_run)
    monkeypatch.setenv("FORGE_REPO_WRITE_TOKEN", "ci")

    code, out = run_main()
    assert code == 0, out
    assert forge.secret_writes == []
    assert "1 Actions-secret PUT(s) + 0 DELETE(s) not applied under the CI token" in out


def test_secret_op_read_failure_aborts_before_any_write(policy, run_main, monkeypatch):
    # op failure: abort before ANY PUT/DELETE — no name is touched on a
    # half-failed read, and the error carries no value or op output.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["STALE"]}
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": ["A"]})
    monkeypatch.setattr(ara, "ACTIONS_SECRET_SOURCES", {("svc", "A"): "op://v/i/f"})
    op = _FakeOp(fail=True)
    monkeypatch.setattr(ara.subprocess, "run", op)

    code, out = run_main(token="t")
    assert code == 1, out
    assert forge.secret_writes == []
    assert op.calls == [["op", "read", "op://v/i/f"]]
    assert "Could not read the Actions secret value: op read exited 1" in out
    assert "aborting before any PUT or DELETE" in out
    assert "secret-value-XYZ" not in out


def test_secret_undeclared_live_deleted_only_on_human_run(
    policy, run_main, monkeypatch
):
    # An undeclared live name is reported under the CI token, never deleted.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["STALE"]}
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": []})
    monkeypatch.setattr(ara.subprocess, "run", _op_must_not_run)
    monkeypatch.setenv("FORGE_REPO_WRITE_TOKEN", "ci")

    code, out = run_main()
    assert code == 0, out
    assert forge.secret_writes == []
    assert "0 Actions-secret PUT(s) + 1 DELETE(s) not applied under the CI token" in out


def test_secret_fence_blocks_put_on_write_repo(policy, run_main, monkeypatch):
    # Declared write on a secrets-carrying repo: the values half refuses
    # before any PUT (write on a repo is read of its Actions secrets).
    policy([{"name": "svc", "access": "write", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {
        "svc": []
    }  # write, no secrets: no violation — the fence under test
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": ["A"]})
    monkeypatch.setattr(ara, "ACTIONS_SECRET_SOURCES", {("svc", "A"): "op://v/i/f"})
    op = _FakeOp()
    monkeypatch.setattr(ara.subprocess, "run", op)

    code, out = run_main(token="t")
    assert code == 1, out
    assert "Refusing to PUT Actions secrets" in out
    assert "secret-value-XYZ" not in out
    assert forge.secret_writes == []
    assert op.calls == []


def test_secret_fence_revoked_this_run_is_rerun_not_violation(
    policy, run_main, monkeypatch
):
    # Live write this run revokes (the agents half DELETEs it before the
    # values half): the fence evaluates the plan-time grant state, so it
    # refuses the PUT on this run and says re-run, not violation. The grant
    # revocation still lands; a second run would PUT.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}  # live write → the grant half revokes it
    forge.secrets = {"svc": []}
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": ["A"]})
    monkeypatch.setattr(ara, "ACTIONS_SECRET_SOURCES", {("svc", "A"): "op://v/i/f"})
    op = _FakeOp()
    monkeypatch.setattr(ara.subprocess, "run", op)

    code, out = run_main(token="t")
    assert code == 1, out
    assert forge.secret_writes == []
    assert op.calls == []
    assert "Refusing to PUT Actions secrets" in out
    assert "write grant was just revoked in this run; re-run" in out
    assert "secret-value-XYZ" not in out


def test_no_secrets_skips_values_half(policy, run_main, monkeypatch):
    # --no-secrets: a human apply that wants grants/hooks/protections only.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["STALE"]}
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": ["A"]})
    monkeypatch.setattr(ara.subprocess, "run", _op_must_not_run)

    code, out = run_main(token="t", no_secrets=True)
    assert code == 0, out
    assert forge.secret_writes == []


def test_secret_put_failure_reports_status_not_value(policy, run_main, monkeypatch):
    # Forgejo answers 500: the PUT failure names the status code, never the
    # value or the response body.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": []}
    forge.secret_status = 500
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": ["A"]})
    monkeypatch.setattr(ara, "ACTIONS_SECRET_SOURCES", {("svc", "A"): "op://v/i/f"})
    op = _FakeOp()
    monkeypatch.setattr(ara.subprocess, "run", op)

    code, out = run_main(token="t")
    assert code == 1, out
    assert "PUT eblume/svc:A failed: HTTP 500" in out
    assert "secret-value-XYZ" not in out


def test_pr_check_secret_names_intended_is_green(
    policy, run_main, monkeypatch, tmp_path
):
    # Head declares a second name the base does not: intended drift only (the
    # human values half lands it after merge) — green, with the Actions-secrets
    # line in the posted report.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["A"]}  # live matches base
    forge.horkos_user = _valid_user(is_admin=False)
    forge.protections = {"blumeops": [_blumeops_main_rule()]}
    forge.install(monkeypatch)
    monkeypatch.setattr(
        ara, "declared_actions_secret_names", lambda: {"svc": ["A", "B"]}
    )
    _base_state(
        monkeypatch,
        [{"name": "svc", "access": "none", "pool": "none"}],
        secrets={"svc": ["A"]},
    )

    report = tmp_path / "notice.md"
    code, out = run_main(
        check=True, token="t", pr_base_ref="main", report_file=str(report)
    )
    assert code == 0, out
    assert "Unexpected drift" not in out
    assert "Actions secret" in report.read_text()
    assert "eblume/svc" in report.read_text()


def test_pr_check_secret_names_unexpected_live_fails(
    policy, run_main, monkeypatch, tmp_path
):
    # Base and head declare the same names, but the live forge carries an
    # undeclared one: unexpected drift the PR does not intend — fails, and
    # names the ghost secret.
    policy([{"name": "svc", "access": "none", "pool": "none"}])
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.secrets = {"svc": ["A", "GHOST"]}
    forge.horkos_user = _valid_user(is_admin=False)
    forge.protections = {"blumeops": [_blumeops_main_rule()]}
    forge.install(monkeypatch)
    monkeypatch.setattr(ara, "declared_actions_secret_names", lambda: {"svc": ["A"]})
    _base_state(
        monkeypatch,
        [{"name": "svc", "access": "none", "pool": "none"}],
        secrets={"svc": ["A"]},
    )

    code, out = run_main(
        check=True,
        token="t",
        pr_base_ref="main",
        report_file=str(tmp_path / "notice.md"),
    )
    assert code == 1, out
    assert "undeclared live Actions secret on eblume/svc: GHOST" in out


# --- PR-check semantics (same-repo PRs only) ---------------------------------


def _base_state(monkeypatch, repos, protections=(), secrets=None):
    """Point the base-state readers the --pr-base-ref path uses at these."""
    monkeypatch.setattr(
        ara, "read_policies_at", lambda ref: ara._policies_dict({"repos": repos})
    )
    monkeypatch.setattr(ara, "read_protections_at", lambda ref: list(protections))
    monkeypatch.setattr(
        ara, "actions_secret_names_at", lambda ref: {} if secrets is None else secrets
    )


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
    # The script still writes the report on a failing PR (so a local `--check`
    # reader gets the red reason), carrying the [X] unexpected section. In CI the
    # notice step is success()-gated, so a failing PR's red reason reaches the
    # thread via the teed log (report-failure), not the notice.
    assert report.exists()
    assert "[X]" in report.read_text()


def test_pr_check_rule_removal_posts_notice(policy, run_main, monkeypatch, tmp_path):
    # A PR whose only effect is removing a branch protection (head plan is
    # empty — the live rule is "extra, left alone", not a planned action) must
    # still run the categorization and post a notice that the protection is
    # now unmanaged, instead of silently passing as "in sync".
    policy([{"name": "svc", "access": "write", "pool": "none"}])
    # Head declares no protections (PROTECTIONS_PATH empty); base declares svc:main.
    ara.PROTECTIONS_PATH.write_text('{"rules": []}', encoding="utf-8")
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}
    forge.secrets = {"svc": []}
    forge.protections.update(
        {"svc": [_served(_rule())]}
    )  # svc:main live, now unmanaged
    forge.install(monkeypatch)
    _base_state(
        monkeypatch,
        [{"name": "svc", "access": "write", "pool": "none"}],
        [_rule(repo="svc")],
    )

    report = tmp_path / "notice.md"
    code, out = run_main(
        check=True, token="t", pr_base_ref="main", report_file=str(report)
    )
    assert code == 0, out
    assert report.exists()
    assert "branch protection" in report.read_text()


def test_pr_check_head_plan_violation_forbidden(
    policy, run_main, monkeypatch, tmp_path
):
    # A PR that grants write on a repo carrying Actions secrets: its *target*
    # state violates the Actions-secrets fence. The check fails FORBIDDEN — the
    # human reads that before merging, rather than discovering it on the merge
    # push.
    policy([{"name": "svc", "access": "write", "pool": "none"}])
    ara.PROTECTIONS_PATH.write_text('{"rules": []}', encoding="utf-8")
    forge = FakeForge()
    forge.repos = ["svc"]
    forge.permission = {"svc": "write"}  # head grants write (pending on the live forge)
    forge.secrets = {"svc": ["DEPLOY_KEY"]}  # write + secrets = violation
    forge.install(monkeypatch)
    _base_state(monkeypatch, [{"name": "svc", "access": "none", "pool": "none"}])

    report = tmp_path / "notice.md"
    code, out = run_main(
        check=True, token="t", pr_base_ref="main", report_file=str(report)
    )
    assert code == 1, out
    assert "FORBIDDEN" in out
    assert "Actions secret" in out
    assert report.exists()
    assert "Forbidden" in report.read_text()
    assert "actions-secrets: eblume/svc" in report.read_text()


def test_pr_check_fork_pr_skips(policy, run_main, monkeypatch):
    # No token + --skip-if-no-token: the fork/agent-PR path exits 0 before any
    # PR categorization (a green tick that checked nothing is worse than none).
    policy([_write_repo("svc")])

    code, out = run_main(check=True, skip_if_no_token=True, pr_base_ref="main")
    assert code == 0
    assert "SKIPPED" in out
