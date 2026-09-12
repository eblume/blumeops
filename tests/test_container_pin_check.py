"""container-pin-check: kustomization image pins must exist in our registry.

The interesting cases are the failure modes — a pin that names a tag the
registry does not have yet must hold the PR red, and a malformed/invalid pin
must fail without ever reaching the registry. Upstream registries are
intentionally skipped, so those must make zero HTTP calls.

Scoping: --all-files globs REPO_ROOT; the changed-files path is exercised by
stubbing the git subprocess (fail → fall back to all files; empty → nothing
to check).
"""

import importlib.machinery
import importlib.util
import io
import pathlib
import subprocess

import httpx
import pytest
import typer
from rich.console import Console

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: app() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "container_pin_check", str(ROOT / "mise-tasks" / "container-pin-check")
    )
    spec = importlib.util.spec_from_loader("container_pin_check", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


pin_check = _load()


def _kustomization(pins_yaml: str) -> str:
    return (
        "apiVersion: kustomize.config.k8s.io/v1beta1\n"
        "kind: Kustomization\n"
        f"images:\n{pins_yaml}"
    )


@pytest.fixture
def repo(tmp_path, monkeypatch):
    """Point REPO_ROOT at a scratch dir and return add(service, body)."""
    manifests = tmp_path / "argocd" / "manifests"

    def add(service: str, body: str) -> pathlib.Path:
        path = manifests / service / "kustomization.yaml"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")
        return path

    monkeypatch.setattr(pin_check, "REPO_ROOT", tmp_path)
    return add


class FakeRegistry:
    """MockTransport-backed client; records requests, drives status/errors."""

    def __init__(self):
        self.requests = []
        self.status = 200
        self.error = None

    def handler(self, request: httpx.Request) -> httpx.Response:
        self.requests.append((request.method, str(request.url)))
        if self.error is not None:
            raise self.error
        return httpx.Response(
            self.status,
            headers={"content-type": "application/vnd.oci.image.manifest.v1+json"},
        )

    def install(self, monkeypatch):
        client = httpx.Client(transport=httpx.MockTransport(self.handler))
        monkeypatch.setattr(pin_check.httpx, "Client", lambda *a, **k: client)
        return client


@pytest.fixture
def run_main(monkeypatch):
    """Invoke main() directly with rich output captured; returns (code, out)."""
    buf = io.StringIO()
    monkeypatch.setattr(
        pin_check, "console", Console(file=buf, force_terminal=False, width=200)
    )

    def invoke(*args, **kwargs):
        code = 0
        try:
            pin_check.main(*args, **kwargs)
        except typer.Exit as exc:
            code = exc.exit_code
        return code, buf.getvalue()

    return invoke


def test_ok_pin(repo, run_main, monkeypatch):
    repo(
        "alloy",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/alloy\n    newTag: v1.0.0\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 0
    assert "registry.ops.eblu.me/blumeops/alloy" in out
    assert "v1.0.0" in out
    assert "OK" in out
    assert "All image pins exist" in out


def test_404_fails_with_build_hint(repo, run_main, monkeypatch):
    repo(
        "alloy",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/alloy\n    newTag: v1.0.0\n"
        ),
    )
    reg = FakeRegistry()
    reg.status = 404
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "registry.ops.eblu.me/blumeops/alloy" in out
    assert "v1.0.0" in out
    assert "FAIL" in out
    assert "not in registry" in out
    assert "runner-logs" in out


def test_500_could_not_verify(repo, run_main, monkeypatch):
    repo(
        "alloy",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/alloy\n    newTag: v1.0.0\n"
        ),
    )
    reg = FakeRegistry()
    reg.status = 500
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "could not verify (HTTP 500)" in out


def test_network_error_could_not_verify(repo, run_main, monkeypatch):
    repo(
        "alloy",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/alloy\n    newTag: v1.0.0\n"
        ),
    )
    reg = FakeRegistry()
    reg.error = httpx.ConnectError("no route")
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "could not verify (network:" in out
    assert "ALL_PROXY=socks5://localhost:1055" in out


def test_upstream_pin_skipped(repo, run_main, monkeypatch):
    repo(
        "birdnet",
        _kustomization(
            f"  - name: ghcr.io/tphakala/birdnet-go\n    digest: sha256:{'a' * 64}\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 0
    assert reg.requests == []
    assert "No local image pins in scope." in out


def test_invalid_tag_fails_without_http(repo, run_main, monkeypatch):
    # UPPER-case is actually VALID under the tag grammar (uppercase is
    # permitted); a tag with a character outside the allowed set is not.
    repo(
        "svc",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/svc\n    newTag: v1.0!\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "invalid tag" in out
    assert reg.requests == []


@pytest.mark.parametrize("bad_path", ["BlumeOps/svc", "blume..ops/svc"])
def test_invalid_image_path_fails_without_http(repo, run_main, monkeypatch, bad_path):
    repo(
        "svc",
        _kustomization(
            f"  - name: registry.ops.eblu.me/{bad_path}\n    newTag: v1.0.0\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "invalid image path" in out
    assert reg.requests == []


def test_digest_pin_heads_digest_path(repo, run_main, monkeypatch):
    digest = "sha256:" + "a" * 64
    repo(
        "svc",
        _kustomization(
            f"  - name: registry.ops.eblu.me/blumeops/svc\n    digest: {digest}\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, _ = run_main(all_files=True)
    assert code == 0
    assert len(reg.requests) == 1
    method, url = reg.requests[0]
    assert method == "HEAD"
    assert url.endswith(f"/v2/blumeops/svc/manifests/{digest}")


def test_newtag_tag_at_digest_heads_digest_path(repo, run_main, monkeypatch):
    digest = "sha256:" + "a" * 64
    repo(
        "svc",
        _kustomization(
            f"  - name: registry.ops.eblu.me/blumeops/svc\n"
            f"    newTag: v1.0.0-abc1234-nix@{digest}\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, _ = run_main(all_files=True)
    assert code == 0
    assert len(reg.requests) == 1
    method, url = reg.requests[0]
    assert method == "HEAD"
    assert url.endswith(f"/v2/blumeops/svc/manifests/{digest}")
    assert "v1.0.0-abc1234-nix" not in url  # the tag half never reaches the registry


def test_newtag_tag_at_digest_404_fails(repo, run_main, monkeypatch):
    digest = "sha256:" + "a" * 64
    repo(
        "svc",
        _kustomization(
            f"  - name: registry.ops.eblu.me/blumeops/svc\n"
            f"    newTag: v1.0.0-abc1234-nix@{digest}\n"
        ),
    )
    reg = FakeRegistry()
    reg.status = 404
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "not in registry" in out
    assert "FAIL" in out


@pytest.mark.parametrize(
    "bad_newtag",
    [
        "v1.0.0@sha256:not-a-digest",
        "v1.0.0@sha256:" + "a" * 63,  # digest grammar needs exactly 64 hex
        "v1.0!@sha256:" + "a" * 64,
        "v1.0.0@",
        "v1.0.0@sha256:" + "A" * 64,  # digest hex is lowercase
        "v1.0.0@sha256:abc@def",
    ],
)
def test_newtag_bad_combined_form_fails_without_http(
    repo, run_main, monkeypatch, bad_newtag
):
    repo(
        "svc",
        _kustomization(
            f"  - name: registry.ops.eblu.me/blumeops/svc\n    newTag: {bad_newtag}\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "invalid tag" in out
    assert reg.requests == []


def test_malformed_yaml_fails_without_http(repo, run_main, monkeypatch):
    repo("svc", "images: [unclosed")
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "malformed" in out
    assert reg.requests == []


def test_git_failure_falls_back_to_all_files(repo, run_main, monkeypatch):
    repo(
        "alloy",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/alloy\n    newTag: v1.0.0\n"
        ),
    )
    # these exercise the main-diff path; CI runners set GITHUB_BASE_REF for
    # PR events, which would route scope_files through changed_vs_base
    monkeypatch.delenv("GITHUB_BASE_REF", raising=False)
    monkeypatch.setattr(pin_check, "git_changed_files", lambda args: None)
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, _ = run_main(all_files=False)
    assert code == 0
    assert len(reg.requests) == 1  # checked the file despite git failing


def test_git_empty_changed_set_no_http(repo, run_main, monkeypatch):
    repo(
        "alloy",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/alloy\n    newTag: v1.0.0\n"
        ),
    )
    # as above: these test the main-diff path, not the PR base-ref path
    monkeypatch.delenv("GITHUB_BASE_REF", raising=False)
    monkeypatch.setattr(pin_check, "git_changed_files", lambda args: [])
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=False)
    assert code == 0
    assert reg.requests == []
    assert "No local image pins in scope." in out


def test_base_ref_fetches_and_diffs(repo, run_main, monkeypatch):
    repo(
        "alloy",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/alloy\n    newTag: v1.0.0\n"
        ),
    )
    calls: list[list[str]] = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, stdout="", stderr="")

    monkeypatch.setattr(pin_check.subprocess, "run", fake_run)
    monkeypatch.setenv("GITHUB_BASE_REF", "main")
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=False)
    assert [
        "git",
        "fetch",
        "--depth=1",
        "origin",
        "main:refs/remotes/origin/main",
    ] in calls
    assert ["git", "diff", "--name-only", "origin/main", "HEAD"] in calls
    assert code == 0
    assert "No local image pins in scope." in out


def test_base_ref_fetch_failure_falls_back_to_all_files(repo, run_main, monkeypatch):
    repo(
        "alloy",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/alloy\n    newTag: v1.0.0\n"
        ),
    )
    monkeypatch.setattr(
        pin_check.subprocess,
        "run",
        lambda cmd, **kw: subprocess.CompletedProcess(cmd, 1, stdout="", stderr="boom"),
    )
    monkeypatch.setenv("GITHUB_BASE_REF", "main")
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=False)
    assert code == 0
    assert len(reg.requests) == 1  # fell back to all files and checked the pin
    assert "could not fetch/diff origin/main" in out


def test_invalid_digest_fails_without_http(repo, run_main, monkeypatch):
    repo(
        "svc",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/svc\n"
            "    digest: sha256:not-a-digest\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "invalid digest" in out
    assert reg.requests == []


def test_non_string_newname_fails_without_http(repo, run_main, monkeypatch):
    repo(
        "svc",
        _kustomization(
            "  - name: registry.ops.eblu.me/blumeops/svc\n"
            "    newName: 123\n"
            "    newTag: v1.0.0\n"
        ),
    )
    reg = FakeRegistry()
    reg.install(monkeypatch)
    code, out = run_main(all_files=True)
    assert code == 1
    assert "invalid image name" in out
    assert reg.requests == []
