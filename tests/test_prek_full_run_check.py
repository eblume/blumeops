"""Tests for the full-run fallback decision (mise-tasks/prek-full-run-check).

The check exists because changed-file mode fails open in ways no hook's
`files` filter can close: a delete-only or rename-only diff never hands
every hook its changed files, and a config-only diff never reaches the hook
its config rewrites. Each of those must fall back to `--all-files`;
everything else stays scoped. The diff is judged from the fork point, so a
branch behind main is judged on its own changes only.
"""

import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parent.parent / "mise-tasks" / "prek-full-run-check"

PREK_TOML = """\
[[repos]]
repo = "local"

[[repos.hooks]]
id = "docs-check-links"
name = "docs-check-links"
entry = "./mise-tasks/docs-check-links"
language = "system"
files = '^docs/.*\\.md$'
pass_filenames = false

[[repos.hooks]]
id = "ty-check"
name = "ty-check"
entry = "./mise-tasks/ty-check"
language = "system"
files = '(\\.py$|^mise-tasks/)'
pass_filenames = false

[[repos.hooks]]
id = "yamllint"
name = "yamllint"
entry = "yamllint"
language = "system"
args = ["-c", ".yamllint.yaml"]
files = '^docs/'
pass_filenames = false

[[repos.hooks]]
id = "actionlint"
name = "actionlint"
entry = "actionlint"
language = "system"
args = ["-config-file", ".github/actionlint.yaml"]
files = '^\\.forgejo/'
pass_filenames = false

[[repos.hooks]]
id = "whole-scope"
name = "whole-scope"
entry = "env ANSIBLE_ROLES_PATH=ansible/roles ansible-lint ansible/"
language = "python"
files = '^ansible/$'
pass_filenames = false
"""

CONFIG_FILES = [
    "prek.toml",
    "pyproject.toml",
    "uv.lock",
    ".yamllint.yaml",  # only via the args derivation in PREK_TOML
    ".ansible-lint",
    ".github/actionlint.yaml",  # only via the args derivation in PREK_TOML
    ".editorconfig",
    ".shellcheckrc",
    "taplo.toml",
]


def git(cwd, *args):
    return subprocess.run(
        ["git", "-c", "user.name=t", "-c", "user.email=t@example.com", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=True,
    )


def commit(cwd, files):
    for rel, content in files.items():
        p = cwd / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    git(cwd, "add", "-A")
    git(cwd, "commit", "-q", "-m", "step")


def shas(cwd):
    out = git(cwd, "rev-parse", "HEAD~1", "HEAD").stdout.split()
    return out[0], out[1]


def check(cwd, *args):
    return subprocess.run(
        ["bash", str(SCRIPT), *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.fixture
def repo(tmp_path):
    git(tmp_path, "init", "-q", "-b", "main")
    commit(
        tmp_path,
        {
            "prek.toml": PREK_TOML,
            "pyproject.toml": "[tool.ruff]\n",
            "uv.lock": "{}\n",
            "docs/reference/argocd.md": "# ArgoCD\n",
            "docs/reference/other.md": "See [argocd](argocd.md).\n",
            "mise-tasks/docs-check-links": "#!/usr/bin/env bash\nexit 0\n",
            "mise-tasks/ty-check": "#!/usr/bin/env bash\nexit 0\n",
        },
    )
    # A second commit so `shas` has a base to diff against.
    commit(tmp_path, {"docs/reference/other.md": "See [argocd](argocd.md) now.\n"})
    return tmp_path


def test_ordinary_change_stays_scoped(repo):
    commit(repo, {"docs/reference/argocd.md": "# edited\n"})
    base, head = shas(repo)
    result = check(repo, base, head)
    assert result.returncode == 1, result.stdout
    assert "safe" in result.stdout


def test_new_file_stays_scoped(repo):
    commit(repo, {"docs/reference/new.md": "# New\n"})
    base, head = shas(repo)
    result = check(repo, base, head)
    assert result.returncode == 1, result.stdout


def test_delete_only_diff_requires_full_run(repo):
    # Deleting argocd.md breaks the incoming link in other.md, but the
    # deletion never appears in `--from-ref`'s file list.
    (repo / "docs/reference/argocd.md").unlink()
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", "delete")
    base, head = shas(repo)
    result = check(repo, base, head)
    assert result.returncode == 0, result.stdout
    assert "deleted files" in result.stdout
    assert "argocd.md" in result.stdout


def test_rename_only_diff_requires_full_run(repo):
    # A move is a delete+add, and with rename detection on the deleted path
    # never appears in the D filter, so the old path's incoming links would
    # go unlinted.
    git(repo, "mv", "docs/reference/argocd.md", "archive-argocd.md")
    git(repo, "commit", "-q", "-m", "move")
    base, head = shas(repo)
    result = check(repo, base, head)
    assert result.returncode == 0, result.stdout
    assert "deleted files" in result.stdout
    assert "argocd.md" in result.stdout


def test_entry_script_edit_requires_full_run(repo):
    commit(repo, {"mise-tasks/docs-check-links": "#!/usr/bin/env bash\nexit 1\n"})
    base, head = shas(repo)
    result = check(repo, base, head)
    assert result.returncode == 0, result.stdout
    assert "entry script" in result.stdout
    assert "mise-tasks/docs-check-links" in result.stdout


def test_non_script_entry_is_not_picked_up(repo):
    # The whole-scope hook's entry names a project, not a script file;
    # touching its config (files =) must not be mistaken for a script edit.
    commit(repo, {"prek.toml": PREK_TOML.replace("ansible/", "ansible/roles/")})
    base, head = shas(repo)
    result = check(repo, base, head)
    # prek.toml itself is a config file, so the full run still fires — but
    # for the config reason, not a phantom entry script.
    assert result.returncode == 0, result.stdout
    assert "config" in result.stdout
    assert "entry script" not in result.stdout


@pytest.mark.parametrize("config_file", CONFIG_FILES)
def test_config_touch_requires_full_run(repo, config_file):
    existing = repo / config_file
    content = existing.read_text() if existing.is_file() else "rewritten\n"
    commit(repo, {config_file: content + "# changed\n"})
    base, head = shas(repo)
    result = check(repo, base, head)
    assert result.returncode == 0, result.stdout
    assert "config" in result.stdout
    assert config_file in result.stdout


def test_deletion_and_config_together_name_both(repo):
    (repo / "docs/reference/argocd.md").unlink()
    commit(repo, {"pyproject.toml": "[tool.ruff]\nselect = []\n"})
    base, head = shas(repo)
    result = check(repo, base, head)
    assert result.returncode == 0, result.stdout
    assert "deleted files" in result.stdout
    assert "config" in result.stdout


def test_stale_branch_judged_from_fork_point(repo):
    # main gains a file after the branch's fork point; judged from the base
    # tip that file would count as a branch deletion, but from the fork
    # point the branch's own change is a plain edit and stays scoped.
    git(repo, "switch", "-q", "-c", "feat")
    commit(repo, {"docs/reference/argocd.md": "# edited by branch\n"})
    git(repo, "switch", "-q", "main")
    commit(repo, {"docs/reference/main-only.md": "# main moved\n"})
    base = git(repo, "rev-parse", "main").stdout.strip()
    head = git(repo, "rev-parse", "feat").stdout.strip()
    result = check(repo, base, head)
    assert result.returncode == 1, result.stdout


def test_single_quoted_entry_is_derived(repo):
    # The derivation must not depend on TOML's string style.
    content = (
        (repo / "prek.toml")
        .read_text()
        .replace(
            'entry = "./mise-tasks/docs-check-links"',
            "entry = './mise-tasks/docs-check-links'",
        )
    )
    commit(repo, {"prek.toml": content})
    commit(repo, {"mise-tasks/docs-check-links": "#!/usr/bin/env bash\nexit 2\n"})
    base, head = shas(repo)
    result = check(repo, base, head)
    assert result.returncode == 0, result.stdout
    assert "entry script" in result.stdout


def test_empty_diff_requires_full_run(repo):
    head = git(repo, "rev-parse", "HEAD").stdout.strip()
    result = check(repo, head, head)
    assert result.returncode == 0, result.stdout
    assert "empty diff" in result.stdout


def test_unresolvable_ref_fails_closed(repo):
    _, head = shas(repo)
    result = check(repo, "does-not-exist", head)
    assert result.returncode == 2
    assert "error" in result.stderr


def test_missing_args_fails_closed(repo):
    result = check(repo)
    assert result.returncode == 2
    assert "usage" in result.stderr
