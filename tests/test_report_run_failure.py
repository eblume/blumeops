"""report-run-failure: one open issue per workflow, deduped by exact title.

Pins `.forgejo/actions/report-run-failure/action.yml`: a failed non-PR run
opens `Workflow failed: <workflow>` when no open issue has that exact title,
comments on the existing one otherwise, and fails the step when the search or
the write does not return JSON. Prefix-only title matches must not be reused.

The step's `run` script is extracted from the YAML and executed with bash. Inputs
reach it the way the runner delivers them: through the step's `env` mapping
(`${{ inputs.* }}` resolved into `REPORT_*` variables), never by textual
substitution into the script. `curl` is stubbed on PATH so nothing leaves the
machine.
"""

import json
import os
import pathlib
import shutil
import subprocess
from datetime import UTC, datetime

import pytest
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
ACTION = ROOT / ".forgejo" / "actions" / "report-run-failure" / "action.yml"

if shutil.which("bash") is None or shutil.which("jq") is None:
    pytest.skip(
        "report-run-failure tests need bash and jq on PATH", allow_module_level=True
    )

# Every call is logged as "METHOD URL" to CALLS_FILE. POST bodies go to
# CAPTURE_FILE, one JSON document per line. The search (GET .../issues) returns
# STUB_SEARCH verbatim, and GET .../comments returns STUB_COMMENTS verbatim, so
# a test can serve a non-JSON page.
CURL_STUB = r"""#!/usr/bin/env bash
method=GET
url=""
data=""
while [ $# -gt 0 ]; do
  case "$1" in
    -X) method="$2"; shift ;;
    -d) data="$2"; shift ;;
    http*) url="$1" ;;
  esac
  shift
done
case "$url" in
  *"?"*) url_path="${url%%\?*}" ;;
  *) url_path="$url" ;;
esac
echo "$method $url_path" >> "$CALLS_FILE"
if [ "$method" = "POST" ]; then
  printf '%s\n' "$data" >> "$CAPTURE_FILE"
  case "$url_path" in
    */comments) echo '{"id":9,"html_url":"https://forge.example/c/9"}' ;;
    *) echo '{"number":7,"html_url":"https://forge.example/i/7"}' ;;
  esac
else
  case "$url_path" in
    */comments) printf '%s' "${STUB_COMMENTS:-[]}" ;;
    *) printf '%s' "${STUB_SEARCH:-[]}" ;;
  esac
fi
"""

SHA = "abcdef1" + "0" * 33


def _step(run_inputs):
    """Return (script, env-overrides) for the step, resolving its env mapping."""
    step = yaml.safe_load(ACTION.read_text())["runs"]["steps"][0]
    overrides = {}
    for name, template in step.get("env", {}).items():
        prefix, suffix = "${{ inputs.", " }}"
        assert template.startswith(prefix) and template.endswith(suffix), template
        input_name = template[len(prefix) : -len(suffix)].strip()
        overrides[name] = run_inputs[input_name]
    return step["run"], overrides


def _run_action(tmp_path, *, search, workflow="foo", note="", comments="[]"):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    curl = bin_dir / "curl"
    curl.write_text(CURL_STUB)
    curl.chmod(0o755)

    script_text, step_env = _step({"workflow": workflow, "note": note})
    script = tmp_path / "step.sh"
    script.write_text(script_text)

    calls = tmp_path / "calls.txt"
    capture = tmp_path / "capture.jsonl"
    env = {
        **step_env,
        "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
        "GITHUB_API_URL": "https://forge.example/api/v1",
        "GITHUB_SERVER_URL": "https://forge.example",
        "GITHUB_REPOSITORY": "eblume/blumeops",
        "GITHUB_TOKEN": "test-token",
        "GITHUB_EVENT_NAME": "schedule",
        "GITHUB_SHA": SHA,
        "GITHUB_RUN_ID": "4242",
        "GITHUB_RUN_NUMBER": "42",
        "CALLS_FILE": str(calls),
        "CAPTURE_FILE": str(capture),
        "STUB_SEARCH": search,
        "STUB_COMMENTS": comments,
    }
    proc = subprocess.run(
        ["bash", str(script)],
        cwd=tmp_path,
        env=env,
        capture_output=True,
        text=True,
        stdin=subprocess.DEVNULL,
        timeout=60,
        check=False,
    )
    call_log = calls.read_text().splitlines() if calls.exists() else []
    bodies = (
        [json.loads(line) for line in capture.read_text().splitlines()]
        if capture.exists()
        else []
    )
    return proc, call_log, bodies


def _issue(number, title, state="open"):
    return {"number": number, "title": title, "state": state}


def test_no_open_issue_creates_one(tmp_path):
    proc, calls, bodies = _run_action(tmp_path, search="[]")

    assert proc.returncode == 0, proc.stderr
    assert calls == [
        "GET https://forge.example/api/v1/repos/eblume/blumeops/issues",
        "POST https://forge.example/api/v1/repos/eblume/blumeops/issues",
    ]
    assert len(bodies) == 1
    assert bodies[0]["title"] == "Workflow failed: foo"
    body = bodies[0]["body"]
    assert "<!-- report-run-failure: foo -->" in body
    assert "https://forge.example/eblume/blumeops/actions/runs/42" in body
    assert "actions/runs/4242" not in body
    assert "`schedule`" in body
    assert "abcdef1" in body
    assert "A talos agent or a human should look" in body


def test_note_is_included_in_new_issue(tmp_path):
    proc, _, bodies = _run_action(tmp_path, search="[]", note="cron drift")

    assert proc.returncode == 0, proc.stderr
    assert "cron drift" in bodies[0]["body"]


def test_exact_open_issue_gets_comment_not_issue(tmp_path):
    search = json.dumps([_issue(3, "Workflow failed: foo")])
    proc, calls, bodies = _run_action(tmp_path, search=search, note="again")

    assert proc.returncode == 0, proc.stderr
    assert calls == [
        "GET https://forge.example/api/v1/repos/eblume/blumeops/issues",
        "GET https://forge.example/api/v1/repos/eblume/blumeops/issues/3/comments",
        "POST https://forge.example/api/v1/repos/eblume/blumeops/issues/3/comments",
    ]
    assert len(bodies) == 1
    assert "run [42]" in bodies[0]["body"]
    assert "again" in bodies[0]["body"]
    assert "title" not in bodies[0]


def test_same_day_report_comment_skips_post(tmp_path):
    today = datetime.now(UTC).strftime("%Y-%m-%d")
    search = json.dumps([_issue(3, "Workflow failed: foo")])
    comments = json.dumps([{"body": f"**{today}** — run [1](https://x) failed again."}])
    proc, calls, bodies = _run_action(tmp_path, search=search, comments=comments)

    assert proc.returncode == 0, proc.stderr
    assert "skipped" in proc.stdout
    assert calls == [
        "GET https://forge.example/api/v1/repos/eblume/blumeops/issues",
        "GET https://forge.example/api/v1/repos/eblume/blumeops/issues/3/comments",
    ]
    assert bodies == []


def test_older_day_report_comment_still_posts(tmp_path):
    search = json.dumps([_issue(3, "Workflow failed: foo")])
    comments = json.dumps(
        [{"body": "**2000-01-01** — run [1](https://x) failed again."}]
    )
    proc, calls, bodies = _run_action(tmp_path, search=search, comments=comments)

    assert proc.returncode == 0, proc.stderr
    assert (
        calls[-1]
        == "POST https://forge.example/api/v1/repos/eblume/blumeops/issues/3/comments"
    )
    assert len(bodies) == 1


def test_comment_search_non_json_fails_loudly(tmp_path):
    search = json.dumps([_issue(3, "Workflow failed: foo")])
    proc, calls, bodies = _run_action(tmp_path, search=search, comments="<html>")

    assert proc.returncode != 0
    assert "comment search on #3 failed" in proc.stderr
    assert bodies == []
    assert not any(c.startswith("POST") for c in calls)


def test_prefix_only_match_creates_new_issue(tmp_path):
    search = json.dumps([_issue(5, "Workflow failed: foo-bar")])
    proc, calls, bodies = _run_action(tmp_path, search=search)

    assert proc.returncode == 0, proc.stderr
    assert calls[-1] == "POST https://forge.example/api/v1/repos/eblume/blumeops/issues"
    assert not any("/comments" in c for c in calls)
    assert bodies[0]["title"] == "Workflow failed: foo"


def test_search_non_json_fails_loudly(tmp_path):
    proc, calls, bodies = _run_action(tmp_path, search="<html>forbidden</html>")

    assert proc.returncode != 0
    assert "issue search failed" in proc.stderr
    assert bodies == []
    assert not any(c.startswith("POST") for c in calls)


def test_workflow_value_with_shell_metacharacters_is_data(tmp_path):
    workflow = "foo'; touch PWNED_FILE; echo '"
    marker = tmp_path / "PWNED_FILE"
    proc, _calls, bodies = _run_action(tmp_path, search="[]", workflow=workflow)

    assert proc.returncode == 0, proc.stderr
    assert not marker.exists(), "workflow input was executed as shell"
    assert len(bodies) == 1
    assert bodies[0]["title"] == f"Workflow failed: {workflow}"


def test_exact_title_closed_issue_is_not_reused(tmp_path):
    # The server is trusted to filter on state, but the jq select must not rely on it.
    search = json.dumps([_issue(3, "Workflow failed: foo", state="closed")])
    proc, calls, bodies = _run_action(tmp_path, search=search)

    assert proc.returncode == 0, proc.stderr
    assert calls[-1] == "POST https://forge.example/api/v1/repos/eblume/blumeops/issues"
    assert not any("/comments" in c for c in calls)
    assert bodies[0]["title"] == "Workflow failed: foo"
