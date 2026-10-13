"""Tests for the PR-body linter (mise-tasks/pr-body-lint).

MUST_MATCH and MUST_PASS are the shared example set, not an exhaustive spec:
the talos `tea` wrapper (eblume/talos default.nix teaWrapper) carries the same
table in its own test, and CI's docs-checks step runs this very script. A
pattern that drifts on one side shows up here as a failing test instead of a
silent difference — keep the two tables in lockstep when either side changes.
"""

import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "mise-tasks" / "pr-body-lint"

# Bodies that must be rejected (exit 1): each carries an after-merge heading.
MUST_MATCH = [
    "## After merge…",
    "## Post-merge cleanup",
    "# Remaining steps (human)",
    "### after merge",
    "##\tPOST-MERGE",
    "intro\n\n## After merge\n- pin the argocd tag",
]

# Bodies that must pass (exit 0): PR bodies without an after-merge heading.
MUST_PASS = [
    "## Human steps",
    "## Aftermarket pricing",
    "## What this changes\n\nThe linter runs before the PR is posted.",
    "This merge lands after the October review cycle.",
    "",
]


def run_lint(body: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(SCRIPT)],
        input=body,
        capture_output=True,
        text=True,
        check=False,
    )


def test_must_match_bodies_are_rejected():
    for body in MUST_MATCH:
        result = run_lint(body)
        assert result.returncode == 1, (
            f"expected rejection for {body!r}: {result.stdout}"
        )
        assert "::error::" in result.stdout


def test_must_pass_bodies_are_accepted():
    for body in MUST_PASS:
        result = run_lint(body)
        assert result.returncode == 0, (
            f"expected acceptance for {body!r}: {result.stdout}"
        )


def test_body_file_argument_matches_stdin(tmp_path):
    body_file = tmp_path / "body.txt"
    body_file.write_text(MUST_MATCH[0] + "\n")
    result = subprocess.run(
        [str(SCRIPT), str(body_file)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 1


def test_too_many_arguments_fail(tmp_path):
    body_file = tmp_path / "body.txt"
    body_file.write_text(MUST_PASS[0])
    result = subprocess.run(
        [str(SCRIPT), str(body_file), str(body_file)],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 2
