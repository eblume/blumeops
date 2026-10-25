"""branch-cleanup --all-repos: the legacy sweep must delete only merged,
unprotected, closed-PR-free, old branches, and --dry-run must never DELETE.
"""

import importlib.machinery
import importlib.util
import json
import pathlib

import httpx
import pytest
from rich.console import Console

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


def _pr(ref):
    return {"head": {"ref": ref, "label": ref}}


class Forge:
    """Fake Forgejo for one repo: branches, PRs, compare results, DELETE log."""

    def __init__(self, branches, open_prs=(), merged_prs=(), compare=None):
        self.branches = branches  # {name: iso timestamp}
        self.open_prs = list(open_prs)
        self.merged_prs = list(merged_prs)
        self.compare = compare or {}  # {branch: total_commits}
        self.deleted = []

    def handler(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        page = int(request.url.params.get("page", 1))
        if request.method == "DELETE":
            self.deleted.append(path.rsplit("/", 1)[-1])
            return httpx.Response(204)
        if path.endswith("/branches"):
            items = [
                {"name": n, "commit": {"timestamp": t}}
                for n, t in self.branches.items()
            ]
            return httpx.Response(200, json=items if page == 1 else [])
        if path.endswith("/pulls"):
            if request.url.params["state"] == "open":
                prs = [_pr(r) for r in self.open_prs]
            else:
                prs = [dict(_pr(r), merged=True) for r in self.merged_prs]
            return httpx.Response(200, json=prs if page == 1 else [])
        if "/compare/" in path:
            branch = path.split("/compare/main...", 1)[1]
            if branch not in self.compare:
                return httpx.Response(404, json={})
            return httpx.Response(200, json={"total_commits": self.compare[branch]})
        return httpx.Response(500)

    def client(self):
        return httpx.Client(transport=httpx.MockTransport(self.handler))


def _sweep(forge, cutoff=30):
    with forge.client() as c:
        return bc.sweep_repo(c, "eblume", "x", cutoff, Console(quiet=True))


def _names(counts):
    return {n for n, _, _ in counts["candidates"]}


def test_protected_names_never_candidates():
    f = Forge({"main": OLD, "master": OLD, "preserve/keep": OLD}, merged_prs=["main"])
    assert _names(_sweep(f)) == set()


def test_open_pr_head_excluded_even_when_merged_looking():
    f = Forge(
        {"feat": OLD}, open_prs=["feat"], merged_prs=["feat"], compare={"feat": 0}
    )
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["open_pr"] == 1


def test_api_merged_pr_head_is_candidate():
    f = Forge({"squashed": OLD}, merged_prs=["squashed"])
    counts = _sweep(f)
    assert counts["candidates"] == [("squashed", counts["candidates"][0][1], "api")]


def test_fast_forward_merged_branch_is_candidate():
    f = Forge({"ff/one": OLD}, compare={"ff/one": 0})
    counts = _sweep(f)
    assert counts["candidates"][0][0] == "ff/one"
    assert counts["candidates"][0][2] == "ff"


def test_unmerged_branch_without_pr_kept():
    f = Forge({"wip": OLD}, compare={"wip": 3})
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["unmerged"] == 1


def test_young_merged_branch_kept():
    f = Forge({"fresh": NEW}, compare={"fresh": 0})
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["young"] == 1


def test_compare_error_is_not_a_candidate():
    f = Forge({"unknown": OLD}, compare={})
    counts = _sweep(f)
    assert _names(counts) == set()
    assert counts["unmerged"] == 1


def test_dry_run_performs_no_delete(tmp_path, monkeypatch):
    f = Forge({"ff/one": OLD}, compare={"ff/one": 0})
    monkeypatch.setattr(bc, "load_managed_repos", lambda: ["x"])
    with pytest.raises(bc.typer.Exit) as exc:
        bc.run_all_repos(f.client(), Console(quiet=True), 30, dry_run=True, yes=True)
    assert exc.value.exit_code == 0
    assert f.deleted == []


def test_delete_request_targets_named_branch():
    f = Forge({"ff/one": OLD}, compare={"ff/one": 0})
    with f.client() as c:
        ok, _ = bc.delete_remote_branch_api(c, "ff/one", "eblume", "x")
    assert ok
    assert f.deleted == ["one"]


def test_load_managed_repos_reads_repos_json():
    repos = bc.load_managed_repos()
    policy = json.loads((ROOT / "argocd/manifests/talos/repos.json").read_text())
    assert repos == sorted(r["name"] for r in policy["repos"] if r.get("managed"))
    assert "blumeops" in repos
