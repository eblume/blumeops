"""report-failure: the posted CI-failure body must stay under the byte cap.

Pins `.forgejo/actions/report-failure/action.yml`'s log block: the fenced tail
is capped at 8 KiB (so a PR comment never blows up), the cap is cut from the
end with a truncation note outside the fence, and the note's pointer is the
runner-logs command for a non-matrix job or the run URL for a matrix leg. The
max-reviews "a human should look" comment goes through the same cap.

The step's `run` script is extracted from the YAML and executed with bash. Its
`${{ inputs.* }}` placeholders are substituted literally, because the real
runner templates them before bash sees the script. `curl` is stubbed on PATH
so nothing leaves the machine; the stub records the POST body and serves
canned pagination/jobs/reviews responses.
"""

import json
import os
import pathlib
import shutil
import subprocess

import pytest
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
ACTION = ROOT / ".forgejo" / "actions" / "report-failure" / "action.yml"

if shutil.which("bash") is None or shutil.which("jq") is None:
    pytest.skip(
        "report-failure tests need bash and jq on PATH", allow_module_level=True
    )

CURL_STUB = r"""#!/usr/bin/env bash
case " $* " in
  *" POST "*)
    cat > "$CAPTURE_FILE"
    echo '{"html_url":"https://forge.example/x"}'
    ;;
  *"/actions/runs/"*)
    echo '[{"name":"other"},{"name":"horkos-test"}]'
    ;;
  *"/reviews"*)
    printf '%s' "${STUB_REVIEWS:-[]}"
    ;;
  *)
    echo '[]'
    ;;
esac
"""

LOG_NAME = "job.log"
SHA = "abcdef1" + "0" * 33


def _step_script(log_name: str, matrix: str, max_reviews: str) -> str:
    run = yaml.safe_load(ACTION.read_text())["runs"]["steps"][0]["run"]
    subs = {
        "${{ inputs.log-file }}": log_name,
        "${{ inputs.filter }}": "",
        "${{ inputs.matrix }}": matrix,
        "${{ inputs.trigger-authors }}": "talos",
        "${{ inputs.max-reviews }}": max_reviews,
    }
    for placeholder, value in subs.items():
        run = run.replace(placeholder, value)
    return run


def _run_action(tmp_path, log_text, *, matrix="", reviews="[]", max_reviews="3"):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    curl = bin_dir / "curl"
    curl.write_text(CURL_STUB)
    curl.chmod(0o755)

    runner_temp = tmp_path / "runner"
    runner_temp.mkdir()
    (runner_temp / LOG_NAME).write_text(log_text)

    event = tmp_path / "event.json"
    event.write_text(
        json.dumps({"pull_request": {"number": 1961, "user": {"login": "talos"}}})
    )

    script = tmp_path / "step.sh"
    script.write_text(_step_script(LOG_NAME, matrix, max_reviews))

    capture = tmp_path / "capture.json"
    env = {
        "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}",
        "RUNNER_TEMP": str(runner_temp),
        "GITHUB_API_URL": "https://forge.example/api/v1",
        "GITHUB_SERVER_URL": "https://forge.example",
        "GITHUB_REPOSITORY": "eblume/blumeops",
        "GITHUB_TOKEN": "test-token",
        "GITHUB_EVENT_PATH": str(event),
        "GITHUB_SHA": SHA,
        "GITHUB_RUN_NUMBER": "42",
        "GITHUB_RUN_ID": "4242",
        "GITHUB_WORKFLOW": "Tests",
        "GITHUB_JOB": "horkos-test",
        "CAPTURE_FILE": str(capture),
        "STUB_REVIEWS": reviews,
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
    assert proc.returncode == 0, proc.stderr
    assert capture.exists(), "no POST was made"
    return json.loads(capture.read_text())["body"]


def _last_line(body: str) -> str:
    return [line for line in body.splitlines() if line.strip()][-1]


def test_single_long_line_is_capped(tmp_path):
    body = _run_action(tmp_path, "a" * 20000 + "\n")

    assert "**CI failed:" in body
    assert len(body.encode("utf-8")) < 9000
    assert "```" in body
    last = _last_line(body)
    assert last.startswith("… truncated (")
    n = int(last.removeprefix("… truncated (").split(" bytes omitted)")[0])
    assert n > 0
    assert last == (
        f"… truncated ({n} bytes omitted); full log: mise run runner-logs 42 -j 1"
    )
    # The note sits outside the fence, which closes before it.
    assert body.rstrip().splitlines()[-3] == "```"


def test_many_long_lines_tail_and_cap(tmp_path):
    # The action keeps only the last 30 lines before capping, so the cap only
    # bites when those 30 lines exceed 8 KiB. Each line here is ~400 bytes.
    log = "".join(f"line {i:05d} " + "x" * 400 + "\n" for i in range(1, 3001))
    body = _run_action(tmp_path, log)

    assert len(body.encode("utf-8")) < 9000
    assert "line 03000 " in body
    # Inside the 30-line tail but beyond what 8 KiB holds.
    assert "line 02975 " not in body
    fenced = body.split("```\n", 1)[1].split("\n```", 1)[0].splitlines()
    assert fenced and all(line.startswith("line ") for line in fenced)
    last = _last_line(body)
    assert last.startswith("… truncated (")
    assert int(last.removeprefix("… truncated (").split(" bytes omitted)")[0]) > 0


def test_short_log_unchanged_no_note(tmp_path):
    body = _run_action(tmp_path, "short\n")

    assert body.endswith("\n\n```\nshort\n```\n")
    assert "truncated" not in body


def test_matrix_leg_pointer_is_run_url(tmp_path):
    body = _run_action(tmp_path, "a" * 20000 + "\n", matrix="linux-amd64")

    assert "(linux-amd64)" in body
    last = _last_line(body)
    assert last.endswith(
        "full log: https://forge.example/eblume/blumeops/actions/runs/42"
    )
    assert "runner-logs" not in last


def test_max_reviews_cap_comment_is_capped(tmp_path):
    reviews = json.dumps(
        [{"user": {"login": "forgejo-actions"}, "body": "<!-- ci-report v1:x -->"}] * 3
    )
    body = _run_action(tmp_path, "a" * 20000 + "\n", reviews=reviews)

    assert "a human should look" in body
    assert "```" in body
    assert len(body.encode("utf-8")) < 9000
    assert _last_line(body).startswith("… truncated (")
