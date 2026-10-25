"""branch-cleanup --all-repos: the legacy sweep must delete only merged,
unprotected, closed-PR-free, old branches, and dry-run (the default) must never DELETE.
"""

import importlib.machinery
import importlib.util
import json
import pathlib

import httpx
import pytest
from rich.console import Console
from typer.testing import CliRunner

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    loader = importlib.machinery.SourceFileLoader(
        "branch_cleanup", str(ROOT / "mise-tasks" / "branch-cleanup")
    )
    spec = importlib.util.spec_from_loader("branch_cleanup", loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


bc = _load()
OLD = "2020-01-01T00:00:00Z"
NEW = "2099-01-01T00:00:00Z"
API = "/api/v1"


def _pr(ref, *, sha=None, repo="eblume/x", merged=False):
    """A PR dict. sha defaults to the branch's current head (see Forge.head_sha)."""
    return {
        "merged": merged,
        "head": {
            "ref": ref,
            "label": ref,
            "sha": sha if sha is not None else f"{ref}@head",
            "repo": {"full_name": repo} if repo is not None else None,
        },
    }


class Forge:
    """Fake Forgejo for one repo x (owner eblume).

    branches:      {name: iso timestamp}
    protected:     branch names with "protected": true
    open_prs:      head names of open canonical PRs (returned on every open listing)
    late_open_prs: head names of open PRs that appear after the first open listing
    merged_prs:    head names (str -> canonical merged PR at the branch's current
                   head) or ready-made PR dicts from _pr(..., merged=True)
    compare:       {"base...branch": total_commits}; missing key -> 404
    default_branch: what GET /repos/eblume/x reports
    fail_default:  GET /repos/eblume/x returns 500
    fail_late_open_listing: the second open-PR listing (the re-check) returns 500
    mutate_after_sweep: {name: new_sha} applied when the open-PR re-check runs;
                   GET /branches/{name} and listings report the new sha afterwards
    """

    def __init__(
        self,
        branches,
        open_prs=(),
        merged_prs=(),
        compare=None,
        *,
        protected=(),
        late_open_prs=(),
        default_branch="main",
        fail_default=False,
        fail_late_open_listing=False,
        mutate_after_sweep=None,
    ):
        self.branches = branches
        self.protected = set(protected)
        self.open_prs = list(open_prs)
        self.late_open_prs = list(late_open_prs)
        self.merged_prs = list(merged_prs)
        self.compare = compare or {}
        self.default_branch = default_branch
        self.fail_default = fail_default
        self.fail_late_open_listing = fail_late_open_listing
        self.mutate_after_sweep = dict(mutate_after_sweep or {})
        self.sha_overrides: dict[str, str] = {}
        self.open_listings = 0
        self.deleted: list[str] = []  # full request paths of DELETE calls

    def head_sha(self, name):
        return self.sha_overrides.get(name, f"{name}@head")

    def _merged_pr_items(self):
        items = []
        for m in self.merged_prs:
            if isinstance(m, dict):
                items.append(m)
            else:
                items.append(_pr(m, merged=True))
        return items

    def handler(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        page = int(request.url.params.get("page", 1))
        if request.method == "DELETE":
            self.deleted.append(path)
            return httpx.Response(204)
        if path == f"{API}/repos/eblume/x":
            if self.fail_default:
                return httpx.Response(500)
            return httpx.Response(200, json={"default_branch": self.default_branch})
        if path.startswith(f"{API}/repos/eblume/x/branches/"):
            name = path.removeprefix(f"{API}/repos/eblume/x/branches/")
            if name not in self.branches:
                return httpx.Response(404, json={})
            return httpx.Response(
                200, json={"name": name, "commit": {"id": self.head_sha(name)}}
            )
        if path.endswith("/branches"):
            items = [
                {
                    "name": n,
                    "protected": n in self.protected,
                    "commit": {"id": self.head_sha(n), "timestamp": t},
                }
                for n, t in self.branches.items()
            ]
            return httpx.Response(200, json=items if page == 1 else [])
        if path.endswith("/pulls"):
            if request.url.params["state"] == "open":
                if page != 1:
                    return httpx.Response(200, json=[])
                self.open_listings += 1
                if self.open_listings > 1:
                    if self.fail_late_open_listing:
                        return httpx.Response(500)
                    self.sha_overrides.update(self.mutate_after_sweep)
                heads = self.open_prs
                if self.open_listings > 1:
                    heads = heads + self.late_open_prs
                return httpx.Response(200, json=[_pr(r) for r in heads])
            return httpx.Response(
                200, json=self._merged_pr_items() if page == 1 else []
            )
        if "/compare/" in path:
            spec = path.split("/compare/", 1)[1]
            if spec not in self.compare:
                return httpx.Response(404, json={})
            return httpx.Response(200, json={"total_commits": self.compare[spec]})
        return httpx.Response(500)

    def client(self):
        return httpx.Client(transport=httpx.MockTransport(self.handler))


def _sweep(forge, cutoff=30):
    with forge.client() as c:
        return bc.sweep_repo(c, "eblume", "x", cutoff, Console(quiet=True))


def _names(counts):
    return {n for n, _, _ in counts["candidates"]}


def test_protected_names_never_candidates():
    # Default is trunk, so main is not caught by the default-branch check; both
    # main and preserve/keep have merged PRs at head and ff-merge compares (the
    # base is the default branch, trunk). Only the name check can exclude them.
    f = Forge(
        {"trunk": OLD, "main": OLD, "master": OLD, "preserve/keep": OLD},
        default_branch="trunk",
        merged_prs=["main", "preserve/keep"],
        compare={"trunk...main": 0, "trunk...preserve/keep": 0},
    )
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["protected"] == 4


def test_open_pr_head_excluded_even_when_merged_looking():
    f = Forge(
        {"feat": OLD},
        open_prs=["feat"],
        merged_prs=["feat"],
        compare={"main...feat": 0},
    )
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["open_pr"] == 1


def test_api_merged_pr_head_is_candidate():
    # Canonical merged PR whose head sha equals the branch's current HEAD.
    f = Forge({"squashed": OLD}, merged_prs=["squashed"])
    counts = _sweep(f)
    assert counts["candidates"] == [("squashed", counts["candidates"][0][1], "api")]


def test_fast_forward_merged_branch_is_candidate():
    f = Forge({"ff/one": OLD}, compare={"main...ff/one": 0})
    counts = _sweep(f)
    assert counts["candidates"][0][0] == "ff/one"
    assert counts["candidates"][0][2] == "ff"


def test_unmerged_branch_without_pr_kept():
    f = Forge({"wip": OLD}, compare={"main...wip": 3})
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["unmerged"] == 1


def test_young_merged_branch_kept():
    f = Forge({"fresh": NEW}, compare={"main...fresh": 0})
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["young"] == 1


def test_compare_error_is_not_a_candidate():
    f = Forge({"unknown": OLD}, compare={})
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["unmerged"] == 1


def test_dry_run_performs_no_delete(monkeypatch):
    f = Forge({"ff/one": OLD}, compare={"main...ff/one": 0})
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    with pytest.raises(bc.typer.Exit) as exc:
        bc.run_all_repos(f.client(), Console(quiet=True), 30, dry_run=True, yes=True)
    assert exc.value.exit_code == 0
    assert f.deleted == []


def test_delete_request_targets_named_branch():
    f = Forge({"ff/one": OLD}, compare={"main...ff/one": 0})
    with f.client() as c:
        ok, _ = bc.delete_remote_branch_api(c, "ff/one", "eblume", "x")
    assert ok
    assert f.deleted == [f"{API}/repos/eblume/x/branches/ff/one"]


def test_load_managed_repos_reads_repos_json():
    repos = bc.load_managed_repos()
    policy = json.loads((ROOT / "argocd/manifests/talos/repos.json").read_text())
    assert repos == sorted(r["name"] for r in policy["repos"] if r.get("managed"))
    assert "blumeops" in repos


# --- exact "api" classification ---------------------------------------------


def test_fork_pr_with_same_head_name_is_not_api():
    # A fork PR from talos/x whose head branch is named "feat" must not
    # vouch for the canonical branch "feat".
    fork = _pr("feat", repo="talos/x", merged=True)
    f = Forge({"feat": OLD}, merged_prs=[fork], compare={"main...feat": 3})
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["unmerged"] == 1


def test_fork_pr_is_ignored_even_when_compare_says_merged_by_ff():
    fork = _pr("feat", repo="talos/x", merged=True)
    f = Forge({"feat": OLD}, merged_prs=[fork], compare={"main...feat": 0})
    counts = _sweep(f)
    assert counts["candidates"][0][2] == "ff"


def test_null_head_repo_pr_is_ignored():
    orphan = _pr("feat", repo=None, merged=True)
    f = Forge({"feat": OLD}, merged_prs=[orphan], compare={"main...feat": 3})
    assert _names(_sweep(f)) == set()


def test_canonical_merged_pr_with_later_commits_is_not_api():
    # PR merged at an older head; the branch has since gained commits.
    stale = _pr("feat", sha="feat@old", merged=True)
    f = Forge({"feat": OLD}, merged_prs=[stale], compare={"main...feat": 2})
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["unmerged"] == 1


# --- protected / default branches -------------------------------------------


def test_branch_marked_protected_by_forge_is_never_candidate():
    f = Forge(
        {"feat": OLD},
        protected={"feat"},
        merged_prs=["feat"],
        compare={"main...feat": 0},
    )
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["protected"] == 1


def test_non_main_default_branch_is_never_candidate_and_ff_uses_it():
    f = Forge(
        {"trunk": OLD, "feat": OLD},
        default_branch="trunk",
        compare={"trunk...feat": 0},
    )
    counts = _sweep(f)
    assert _names(counts) == {"feat"}
    assert counts["candidates"][0][2] == "ff"
    assert counts["protected"] == 1  # trunk


def test_default_branch_fetch_failure_fails_closed(monkeypatch):
    f = Forge({"ff/one": OLD}, compare={"main...ff/one": 0}, fail_default=True)
    counts = _sweep(f)
    assert "error" in counts
    assert counts["candidates"] == []
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    with pytest.raises(bc.typer.Exit):
        bc.run_all_repos(f.client(), Console(quiet=True), 30, dry_run=False, yes=True)
    assert f.deleted == []


# --- CLI gating and dry-run default -----------------------------------------


def _runner_with(monkeypatch, forge):
    real_client = httpx.Client

    def make_client(**kwargs):
        return real_client(transport=httpx.MockTransport(forge.handler), **kwargs)

    monkeypatch.setattr(bc.httpx, "Client", make_client)
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    return CliRunner()


def test_all_repos_defaults_to_dry_run(monkeypatch):
    f = Forge({"ff/one": OLD}, compare={"main...ff/one": 0})
    runner = _runner_with(monkeypatch, f)
    result = runner.invoke(bc.app, ["--all-repos", "--token", "t"])
    assert result.exit_code == 0, result.output
    assert "Dry run" in result.output
    assert f.deleted == []


def test_execute_without_all_repos_rejected(monkeypatch):
    f = Forge({})
    runner = _runner_with(monkeypatch, f)
    result = runner.invoke(bc.app, ["--execute", "--token", "t"])
    assert result.exit_code == 1
    assert f.deleted == []


def test_execute_with_dry_run_rejected(monkeypatch):
    f = Forge({})
    runner = _runner_with(monkeypatch, f)
    result = runner.invoke(
        bc.app, ["--all-repos", "--execute", "--dry-run", "--token", "t"]
    )
    assert result.exit_code == 1
    assert f.deleted == []


def test_open_pr_appearing_before_delete_is_not_deleted(monkeypatch):
    # The first open-PR listing (during the sweep) is clean; ff/two gets an
    # open PR before the per-repo re-check, so only ff/one is deleted.
    f = Forge(
        {"ff/one": OLD, "ff/two": OLD},
        compare={"main...ff/one": 0, "main...ff/two": 0},
        late_open_prs=["ff/two"],
    )
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    with f.client() as c:
        bc.run_all_repos(c, Console(quiet=True), 30, dry_run=False, yes=True)
    assert f.deleted == [f"{API}/repos/eblume/x/branches/ff/one"]


def test_failed_open_pr_recheck_skips_repo_deletes(monkeypatch):
    # The re-check listing fails with 500: nothing in the repo may be deleted.
    f = Forge(
        {"ff/one": OLD, "ff/two": OLD},
        compare={"main...ff/one": 0, "main...ff/two": 0},
        fail_late_open_listing=True,
    )
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    with f.client() as c:
        bc.run_all_repos(c, Console(quiet=True), 30, dry_run=False, yes=True)
    assert f.deleted == []


def test_branch_moved_after_sweep_is_not_deleted(monkeypatch):
    # ff/two gains commits between the sweep and the delete: its fresh sha no
    # longer matches the sweep-time sha, so only the unchanged ff/one is deleted.
    f = Forge(
        {"ff/one": OLD, "ff/two": OLD},
        compare={"main...ff/one": 0, "main...ff/two": 0},
        mutate_after_sweep={"ff/two": "ff/two@new"},
    )
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    with f.client() as c:
        bc.run_all_repos(c, Console(quiet=True), 30, dry_run=False, yes=True)
    assert f.deleted == [f"{API}/repos/eblume/x/branches/ff/one"]


# --- listing timeouts: retried, then the repo is skipped (fail closed) -------


class TimingOut:
    """Wraps a Forge handler; requests whose path contains path_suffix raise a read timeout
    for the first `times` calls."""

    def __init__(self, forge, path_suffix, times):
        self.forge = forge
        self.path_suffix = path_suffix
        self.remaining = times
        self.calls = 0

    def handler(self, request: httpx.Request) -> httpx.Response:
        if self.path_suffix in request.url.path:
            self.calls += 1
            if self.remaining:
                self.remaining -= 1
                raise httpx.ReadTimeout("The read operation timed out", request=request)
        return self.forge.handler(request)

    def client(self):
        return httpx.Client(transport=httpx.MockTransport(self.handler))


@pytest.fixture
def no_sleep(monkeypatch):
    monkeypatch.setattr(bc.time, "sleep", lambda _s: None)


def test_listing_timeout_that_persists_skips_repo_and_deletes_nothing(
    monkeypatch, no_sleep
):
    # Every branch listing times out: the repo is reported as an error, not swept.
    f = Forge({"ff/one": OLD}, compare={"main...ff/one": 0})
    t = TimingOut(f, "/branches", times=10**6)
    counts = _sweep_with(t)
    assert "error" in counts
    assert counts["candidates"] == []
    assert t.calls == bc.LISTING_ATTEMPTS
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    with t.client() as c, pytest.raises(bc.typer.Exit) as exc:
        bc.run_all_repos(c, Console(quiet=True), 30, dry_run=False, yes=True)
    assert exc.value.exit_code == 0
    assert f.deleted == []


def test_transient_listing_timeout_is_retried_and_sweep_completes(no_sleep):
    f = Forge({"ff/one": OLD}, compare={"main...ff/one": 0})
    t = TimingOut(f, "/pulls", times=2)
    counts = _sweep_with(t)
    assert "error" not in counts
    assert _names(counts) == {"ff/one"}
    # Open-PR listing: 2 timeouts + 1 success; closed-PR listing: 1 success.
    assert t.remaining == 0
    assert t.calls == 4


def _sweep_with(t):
    with t.client() as c:
        return bc.sweep_repo(c, "eblume", "x", 30, Console(quiet=True))


def test_compare_timeout_fails_repo_instead_of_counting_unmerged(monkeypatch, no_sleep):
    # ff/one only looks merged via compare; a timed-out compare must not turn
    # into a silent "unmerged" count -- the whole repo is an ERROR and nothing is deleted.
    f = Forge({"ff/one": OLD}, compare={"main...ff/one": 0})
    t = TimingOut(f, "/compare/", times=10**6)
    counts = _sweep_with(t)
    assert "error" in counts
    assert counts["candidates"] == []
    assert counts["unmerged"] == 0
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    with t.client() as c, pytest.raises(bc.typer.Exit):
        bc.run_all_repos(c, Console(quiet=True), 30, dry_run=False, yes=True)
    assert f.deleted == []


def test_sweep_client_uses_explicit_timeout(monkeypatch):
    f = Forge({})
    seen = {}
    real_client = httpx.Client

    def make_client(**kwargs):
        seen.update(kwargs)
        return real_client(transport=httpx.MockTransport(f.handler), **kwargs)

    monkeypatch.setattr(bc.httpx, "Client", make_client)
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    result = CliRunner().invoke(bc.app, ["--all-repos", "--token", "t"])
    assert result.exit_code == 0, result.output
    assert seen["timeout"] == bc.SWEEP_TIMEOUT_S >= 60
