"""Unit tests for the git URL -> owner/name identity parsing in aspects/runner.

These URLs are the forms a real remote.origin.url takes (ssh with port,
scp-style, https); the pair of trailing segments is the repo identity.
"""

import pathlib

import pytest

from aspects.runner import Aspect, assert_kind_holds, parse_repo_identity


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
