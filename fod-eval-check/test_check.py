"""The eval-based FOD check's red/green fixture meta-tests.

Each fixtures/red/*.nix evaluates (with pinned nixpkgs, IFD off, system
pinned) to a derivation whose walk MUST produce at least one violation;
each fixtures/green/*.nix to a derivation whose walk MUST be clean. A hard
error if fixtures/red/ is empty — a guard that can't fail can't be added.

The fixture harness reuses the check's own machinery: the fixture walk is
classified with the container-context template bundle (same nixpkgs pin the
containers use) and the hand-written catalogue.
"""

from __future__ import annotations

import json
import os
import pathlib
import subprocess
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import check  # noqa: E402
import classify  # noqa: E402

REPO = check.REPO_ROOT
FIXTURES = REPO / "fod-eval-check" / "fixtures"
SYSTEM = check.PINNED_SYSTEM

# The nixpkgs pin for the fixture evals: FOD_EVAL_CHECK_NIXPKGS when set
# (in-pod), else resolved from the in-repo containers pin like the check.
# Every harness nix call respects the same store resolution as check.py
# (review #2, F5): FOD_EVAL_CHECK_STORE first, then the default store when
# usable, then an auto-created local store under $XDG_CACHE_HOME.

def _nixpkgs_path() -> str:
    override = os.environ.get("FOD_EVAL_CHECK_NIXPKGS")
    if override:
        return override
    env = dict(os.environ)
    env.setdefault("HOME", str(REPO))
    # CI default: the plain relative path ref exactly as the build workflow
    # uses it. In a talos pod the worktree is not libgit2-readable (files
    # owned by another uid), so a `./containers` flake eval fails on git
    # ownership; retry with an explicit `path:` flake ref — same lock, same
    # resulting nixpkgs outPath. CI never takes the fallback.
    refs = ["./containers#nixpkgsPath", f"path:{REPO / 'containers'}#nixpkgsPath"]
    for ref in refs:
        r = subprocess.run(
            ["nix", *_nix_store(), "--extra-experimental-features", check.FEATURES_EVAL, "eval", "--raw", ref],
            capture_output=True,
            text=True,
            cwd=REPO,
            env=env,
            timeout=600,
        )
        if r.returncode == 0:
            return r.stdout.strip().splitlines()[-1]
    raise RuntimeError(f"cannot resolve ./containers#nixpkgsPath: {r.stderr}")


_NIXPKGS: str | None = None


def _env() -> dict[str, str]:
    global _NIXPKGS
    if _NIXPKGS is None:
        _NIXPKGS = _nixpkgs_path()
    env = dict(os.environ)
    env["NIX_PATH"] = f"nixpkgs={_NIXPKGS}"
    env.setdefault("HOME", str(REPO))
    env.setdefault("XDG_CACHE_HOME", str(REPO / ".cache"))
    return env


def _walk_cache() -> pathlib.Path | None:
    cache = os.environ.get("FOD_EVAL_CHECK_WALK_CACHE")
    if not cache:
        return None
    p = pathlib.Path(cache)
    p.mkdir(parents=True, exist_ok=True)
    return p


def _nix_store() -> list[str]:
    s = check.resolve_store(os.environ.get("FOD_EVAL_CHECK_STORE"))
    return ["--store", s] if s else []


def fixture_walk(case_nix: pathlib.Path) -> dict:
    """Instantiate a fixture expression (IFD off, system pinned) and walk it."""
    env = _env()
    cache = _walk_cache()
    cached = cache / f"{case_nix.stem}.json" if cache else None
    if cached and cached.exists():
        return json.loads(cached.read_text(encoding="utf-8"))
    r = subprocess.run(
        [
            "nix-instantiate",
            *_nix_store(),
            str(case_nix),
            "--system",
            SYSTEM,
            "--extra-experimental-features",
            check.FEATURES_WALK,
            "--option",
            "allow-import-from-derivation",
            "false",
        ],
        capture_output=True,
        text=True,
        cwd=case_nix.parent,
        env=env,
        timeout=1800,
    )
    if r.returncode != 0:
        raise RuntimeError(f"fixture instantiate {case_nix.name} failed: {check._last_line(r.stderr, r.returncode)}")
    drv = r.stdout.strip().splitlines()[-1]
    r = subprocess.run(
        ["nix", *_nix_store(), "derivation", "show", "-r", "--extra-experimental-features", check.FEATURES_WALK, drv],
        capture_output=True,
        text=True,
        cwd=case_nix.parent,
        env=env,
        timeout=1800,
    )
    if r.returncode != 0:
        raise RuntimeError(f"fixture walk {case_nix.name} failed: {check._last_line(r.stderr, r.returncode)}")
    walk = json.loads(r.stdout)
    if cached is not None:
        cached.write_text(json.dumps(walk), encoding="utf-8")
    return walk


def classify_fixture(case_nix: pathlib.Path) -> list[classify.Violation]:
    """The walk of a fixture, classified with the container context."""
    env = _env()
    ctx = check.Context("containers", ["import <nixpkgs> {}"], store=check.resolve_store(os.environ.get("FOD_EVAL_CHECK_STORE")), env=env, repo=REPO, system=SYSTEM)
    catalogue = check.catalogues()
    return classify.classify_walk(fixture_walk(case_nix), ctx.templates(), catalogue)


def _cases(kind: str) -> list[pathlib.Path]:
    d = FIXTURES / kind
    return sorted(d.glob("*.nix"))


@pytest.mark.parametrize("case", _cases("red"), ids=lambda p: p.stem)
def test_red_fixture_rejected(case):
    violations = classify_fixture(case)
    assert violations, f"{case.name} was accepted — the check must reject this FOD"
    print(f"red fixture {case.stem} rejected: {violations[0].reason}")


@pytest.mark.parametrize("case", _cases("green"), ids=lambda p: p.stem)
def test_green_fixture_accepted(case):
    violations = classify_fixture(case)
    assert not violations, f"{case.name} was rejected:\n" + "\n".join(f"  {v.reason}" for v in violations)


def test_meta_red_fixtures_nonempty():
    """In the #1826 shape: a guard that can't fail can't be added."""
    assert _cases("red"), "fixtures/red/ has no case — a guard that can't fail can't be added"


def test_meta_green_fixtures_nonempty():
    assert _cases("green"), "fixtures/green/ has no case"


# --------------------------------------------------------------------------
# Trust-anchor unit tests (review #2, F1): the locked-identity rules the CLI
# enforces, tested pure (no nix eval).
# --------------------------------------------------------------------------

def test_anchor_accepts_canonical_github_identity():
    assert check._canonical_identity({"type": "github", "owner": "NixOS", "repo": "nixpkgs", "ref": "nixos-26.05"})


def test_anchor_accepts_url_spellings():
    for url in ("https://github.com/NixOS/nixpkgs", "git+https://github.com/NixOS/nixpkgs", "git+https://github.com/NixOS/nixpkgs.git"):
        assert check._canonical_identity({"type": "git", "url": url})


def test_anchor_rejects_foreign_identities():
    # an attacker re-pointing a template source at a fork (reviewer's shape)
    assert not check._canonical_identity({"type": "github", "owner": "attacker", "repo": "nixpkgs"})
    assert not check._canonical_identity({"type": "github", "owner": "NixOS", "repo": "nixpkgs-fork"})
    assert not check._canonical_identity({"type": "git", "url": "https://gitlab.com/attacker/nixpkgs"})
    assert not check._canonical_identity(None)
    assert not check._canonical_identity({})


def test_anchor_uses_the_locked_original():
    lock = {
        "nodes": {
            "root": {"inputs": {"nixpkgs": "nixpkgs"}},
            "nixpkgs": {"locked": {"type": "github", "owner": "NixOS", "repo": "nixpkgs", "rev": "abc"},
                        "original": {"type": "github", "owner": "attacker", "repo": "nixpkgs"}},
        }
    }
    assert not check._canonical_identity(check._lock_node_identity(lock, "nixpkgs"))


def test_catalogue_is_closed():
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        d = pathlib.Path(td)
        for pname in check.DECLARED_CATALOGUE:
            (d / f"{pname}.json").write_text("{}")
        assert check.catalogues(d) == {p: {} for p in sorted(check.DECLARED_CATALOGUE)}
        # a PR adding catalogue/evil.json fails closed
        (d / "evil.json").write_text("{}")
        with pytest.raises(RuntimeError):
            check.catalogues(d)


def test_catalogue_declared_missing_fails():
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        d = pathlib.Path(td)
        with pytest.raises(RuntimeError):
            check.catalogues(d)


def test_selfpin_strict_pattern():
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        d = pathlib.Path(td)
        good = d / "good"
        good.mkdir()
        nix = good / "default.nix"
        nix.write_text(
            'pkgs: import (fetchTarball { url = "https://github.com/NixOS/'
            'nixpkgs/archive/7c8764b7c7b09b34f632464276218ef9090eaa11.tar.gz"; '
            'sha256 = "0000000000000000000000000000000000000000000000000000"; }) {}'
        )
        assert check.selfpin_extract(nix) is not None
        # a foreign fetchTarball (or any non-matching one) is a red violation
        bad = d / "bad"
        bad.mkdir()
        nix2 = bad / "default.nix"
        nix2.write_text(
            'import (fetchTarball { url = "https://archive.foo.org/evil.tar.gz"; '
            'sha256 = "0000000000000000000000000000000000000000000000000000"; })'
        )
        with pytest.raises(check.SelfPinFailure):
            check.selfpin_extract(nix2)
        # no fetchTarball at all: not a self-pin, no anchor needed
        nix3 = d / "plain"
        nix3.mkdir()
        (nix3 / "default.nix").write_text("{ pkgs ? import <nixpkgs> {} }: pkgs.hello")
        assert check.selfpin_extract(nix3 / "default.nix") is None
