"""Unit tests for the git URL -> owner/name identity parsing in aspects/runner.

These URLs are the forms a real remote.origin.url takes (ssh with port,
scp-style, https); the pair of trailing segments is the repo identity.
"""

import pathlib

import pytest

from aspects.runner import (
    Aspect,
    assert_kind_holds,
    baseline_for,
    parse_repo_identity,
)


def test_ssh_url_with_port():
    assert (
        parse_repo_identity("ssh://forgejo@forge.ops.eblu.me:2222/eblume/blumeops.git")
        == "eblume/blumeops"
    )


def test_scp_style_url_with_dot_git():
    assert parse_repo_identity("git@github.com:eblume/talos.git") == "eblume/talos"


def test_https_url():
    assert parse_repo_identity("https://forge.ops.eblu.me/eblume/talos.git") == (
        "eblume/talos"
    )


def test_scp_style_url_without_dot_git():
    assert parse_repo_identity("git@github.com:eblume/talos") == "eblume/talos"


@pytest.mark.parametrize(
    "garbage",
    ["localhost", "", "/srv/repos/blumeops.git", "git@github.com:eblume"],
)
def test_unparseable_url_raises(garbage):
    with pytest.raises(ValueError, match="--repo-name"):
        parse_repo_identity(garbage)


def _ratchet(violations, baseline=("a", "b")):
    def check(root):
        return list(violations)

    return Aspect("synthetic", "ratchet", None, check, pathlib.Path("."), baseline)


def test_ratchet_exact_baseline_passes():
    assert_kind_holds(_ratchet(["a", "b"]), pathlib.Path("."))


def test_ratchet_new_violation_fails():
    with pytest.raises(AssertionError, match="not in baseline.json"):
        assert_kind_holds(_ratchet(["a", "c"]), pathlib.Path("."))


def test_ratchet_stale_baseline_entry_fails():
    with pytest.raises(AssertionError, match="lower the baseline"):
        assert_kind_holds(_ratchet(["a"]), pathlib.Path("."))


def _ratchet_by_repo(violations, by_repo):
    def check(root):
        return list(violations)

    return Aspect(
        "synthetic",
        "ratchet",
        None,
        check,
        pathlib.Path("."),
        (),
        tuple((k, tuple(v)) for k, v in by_repo.items()),
    )


def test_baseline_for_object_form_is_per_repo():
    aspect = _ratchet_by_repo([], {"eblume/talos": ["x"]})
    assert baseline_for(aspect, "eblume/talos") == ("x",)
    assert baseline_for(aspect, "eblume/absent") == ()
    assert baseline_for(aspect, None) == ()


def test_baseline_for_list_form_ignores_identity():
    aspect = _ratchet(["a"], baseline=("a", "b"))
    assert baseline_for(aspect, "eblume/anything") == ("a", "b")
    assert baseline_for(aspect, None) == ("a", "b")


def test_object_form_absent_repo_fails_closed():
    aspect = _ratchet_by_repo(["x"], {"eblume/talos": ["x"]})
    assert_kind_holds(aspect, pathlib.Path("."), "eblume/talos")
    with pytest.raises(AssertionError, match="not in baseline.json"):
        assert_kind_holds(aspect, pathlib.Path("."), "eblume/other")


def test_object_form_stale_entry_fails_for_its_repo():
    aspect = _ratchet_by_repo([], {"eblume/talos": ["x"]})
    with pytest.raises(AssertionError, match="lower the baseline"):
        assert_kind_holds(aspect, pathlib.Path("."), "eblume/talos")


@pytest.mark.parametrize(
    "body",
    ['{"talos": ["x"]}', '{"eblume/talos": "x"}', '{"eblume/talos": [1]}', "[1]"],
)
def test_malformed_baseline_is_rejected(tmp_path, monkeypatch, body):
    from aspects import runner

    aspect_dir = tmp_path / "bad"
    aspect_dir.mkdir()
    (aspect_dir / "ASPECT.md").write_text("x")
    (aspect_dir / "__init__.py").write_text("")
    (aspect_dir / "test_bad.py").write_text(
        'KIND = "ratchet"\n\ndef check(root):\n    return []\n'
    )
    (aspect_dir / "baseline.json").write_text(body)
    monkeypatch.setattr(runner, "ASPECTS_DIR", tmp_path)
    with pytest.raises(ValueError, match="aspect bad: baseline.json"):
        runner.discover_aspects()
