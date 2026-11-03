"""Tests for the branch-presence check (mise-tasks/changelog-check --branch).

A branch must add a changelog fragment, a `<branch>.skip.md` marker, or be a
release PR (deletes fragments and bumps `version`). The nested-fragment check
runs in every mode and is covered by its red fixtures.
"""

import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "mise-tasks" / "changelog-check"


def git(cwd, *args):
    return subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@t", *args],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )


def commit(cwd, files, message="c"):
    for rel, content in files.items():
        path = cwd / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    git(cwd, "add", "-A")
    git(cwd, "commit", "-q", "-m", message)


def check(cwd, *args):
    return subprocess.run(
        [str(SCRIPT), *args],
        check=False,
        cwd=cwd,
        capture_output=True,
        text=True,
    )


def make_repo(tmp_path, main_files=None, gitkeep=True):
    """A repo with `main` (the base) and a `feature/x-y` branch checked out."""
    repo = tmp_path / "repo"
    repo.mkdir()
    git(repo, "init", "-q", "-b", "main")
    commit(
        repo,
        {
            "version": "1.0.0\n",
            "docs/changelog.d/existing.feature.md": "existing\n",
            **({"docs/changelog.d/.gitkeep": ""} if gitkeep else {}),
            **(main_files or {}),
        },
        "main",
    )
    git(repo, "checkout", "-q", "-b", "feature/x-y")
    return repo


def test_no_fragment_fails(tmp_path):
    repo = make_repo(tmp_path)
    commit(repo, {"src.txt": "work\n"})
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 1, result.stdout + result.stderr
    assert "docs/changelog.d/feature-x-y.<type>.md" in result.stdout


def test_real_fragment_passes(tmp_path):
    repo = make_repo(tmp_path)
    commit(repo, {"docs/changelog.d/feature-x-y.feature.md": "new\n"})
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "feature-x-y.feature.md" in result.stdout


def test_skip_marker_passes(tmp_path):
    repo = make_repo(tmp_path)
    commit(repo, {"docs/changelog.d/feature-x-y.skip.md": ""})
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 0, result.stdout + result.stderr


def test_nested_fragment_fails(tmp_path):
    repo = make_repo(tmp_path)
    commit(repo, {"docs/changelog.d/a/b.feature.md": "nested\n"})
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 1, result.stdout + result.stderr
    assert "subdirectory" in result.stdout


def test_gitkeep_alone_is_not_a_fragment(tmp_path):
    repo = make_repo(tmp_path, gitkeep=False)
    commit(repo, {"docs/changelog.d/.gitkeep": ""})
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 1, result.stdout + result.stderr


def test_non_ascii_fragment_passes(tmp_path):
    repo = make_repo(tmp_path)
    commit(repo, {"docs/changelog.d/feature-caf\u00e9.feature.md": "new\n"})
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "feature-caf\u00e9.feature.md" in result.stdout


def test_release_pr_passes(tmp_path):
    repo = make_repo(tmp_path)
    git(repo, "rm", "-q", "docs/changelog.d/existing.feature.md")
    commit(repo, {"version": "1.0.1\n"}, "release")
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "Release PR" in result.stdout


def test_deletion_without_version_bump_fails(tmp_path):
    repo = make_repo(tmp_path)
    git(repo, "rm", "-q", "docs/changelog.d/existing.feature.md")
    commit(repo, {"src.txt": "work\n"})
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 1, result.stdout + result.stderr


def test_main_branch_passes(tmp_path):
    repo = make_repo(tmp_path)
    git(repo, "checkout", "-q", "main")
    commit(repo, {"src.txt": "work\n"})
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 0, result.stdout + result.stderr


def test_custom_dir(tmp_path):
    repo = make_repo(tmp_path, {"changelog.d/existing.feature.md": "x\n"})
    commit(repo, {"changelog.d/feature-x-y.bugfix.md": "fixed\n"})
    result = check(repo, "--branch", "--base", "main", "--dir", "changelog.d")
    assert result.returncode == 0, result.stdout + result.stderr

    # The default directory is not consulted when --dir points elsewhere.
    result = check(repo, "--branch", "--base", "main")
    assert result.returncode == 1, result.stdout + result.stderr


def test_unresolvable_base_warns_and_passes(tmp_path):
    repo = make_repo(tmp_path)
    commit(repo, {"src.txt": "work\n"})
    result = check(repo, "--branch")
    assert result.returncode == 0, result.stdout + result.stderr
    assert "WARNING" in result.stderr
    assert "skipped" in result.stderr


def test_explicit_missing_base_fails(tmp_path):
    repo = make_repo(tmp_path)
    commit(repo, {"src.txt": "work\n"})
    result = check(repo, "--branch", "--base", "no-such-ref")
    assert result.returncode == 1, result.stdout + result.stderr
    assert "no-such-ref" in result.stdout


def test_no_branch_flag_skips_presence_check(tmp_path):
    repo = make_repo(tmp_path)
    commit(repo, {"src.txt": "work\n"})
    result = check(repo)
    assert result.returncode == 0, result.stdout + result.stderr
