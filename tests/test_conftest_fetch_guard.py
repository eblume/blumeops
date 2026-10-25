"""Self-test for the autouse no-real-fetch guard in conftest.py."""

import pathlib
import subprocess

import pytest


@pytest.mark.parametrize(
    "call",
    [
        lambda: subprocess.run(["git", "fetch", "origin"], check=False),
        lambda: subprocess.run(["/usr/bin/git", "fetch", "origin"], check=False),
        lambda: subprocess.run(["env", "git", "fetch"], check=False),
        lambda: subprocess.run([pathlib.Path("/usr/bin/git"), "fetch"], check=False),
        lambda: subprocess.run("git fetch origin", shell=True, check=False),
        lambda: subprocess.check_output(["git", "fetch"]),
        lambda: subprocess.run(["git", "-C", "/x", "fetch"], check=False),
        lambda: subprocess.run(["sh", "-c", "git fetch origin"], check=False),
        lambda: subprocess.run([b"git", b"fetch"], check=False),
        lambda: subprocess.run(["git", "pull"], check=False),
    ],
)
def test_guard_blocks_fetch(call):
    with pytest.raises(AssertionError):
        call()


@pytest.mark.parametrize(
    "argv",
    [
        ["git", "log", "--grep", "fetch"],
        ["git", "config", "alias.fetch", "log"],
        ["sh", "-c", "echo fetch"],
    ],
)
def test_guard_allows_non_fetch(argv):
    subprocess.run(argv, capture_output=True, check=False)


def test_guard_allows_local_git(tmp_path):
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    out = subprocess.run(
        ["git", "-C", str(tmp_path), "rev-parse", "--git-dir"],
        capture_output=True,
        text=True,
        check=True,
    )
    assert out.stdout.strip()
