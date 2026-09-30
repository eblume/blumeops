"""flake-update-verify: artifact pin, verdict and rendering for the
flake-update posting job (eblume/blumeops#1318).

The script is bash + jq + sha256sum and has no network or nix deps, so these
tests drive it as a plain subprocess with no stubs. The result file is what
the zero-credential update job assembles; the sha pins are computed in-test
from the real fixture lock bytes (hashlib), so the pin logic runs against
actual lock files, and tampered variants are rewritten at test time, never
checked in.

Fixtures are the real old/new locks of eblume/blumeops@576cc2a9 (the same
pair test_flake_lock_check.py drills).
"""

import hashlib
import itertools
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "nixos" / "ringtail" / "flake-update-verify"
FIX = ROOT / "tests" / "fixtures" / "flake-lock-check"
OLD = FIX / "old.lock"
NEW = FIX / "new.lock"

# The five battery check names, exactly as flake-lock-check reports them.
BATTERY = ["scope", "originals", "ff-head", "ff-ancestor", "nar-hash"]

KERNEL = "6.15.5"
BOOTED = "6.15.5-1-arch"  # script strips the trailing -1-arch -> "6.15.5"
HEAD_SHA = "0123456789abcdef"
BRANCH = "ringtail-flake-update"
PR_URL = "https://forge.eblu.me/eblume/blumeops/pulls/1338"
RUN_DATE = "2026-09-01"

_seq = itertools.count()
_tamper_seq = itertools.count()


def result_json(**overrides) -> dict:
    """The result file the zero-credential update job assembles, pinned by
    hashing the real fixture lock bytes."""
    payload = {
        "lock_sha256": hashlib.sha256(NEW.read_bytes()).hexdigest(),
        "old_lock_sha256": hashlib.sha256(OLD.read_bytes()).hexdigest(),
        "kernel": KERNEL,
        "checks": [{"name": name, "status": "PASS", "detail": ""} for name in BATTERY],
        "inputs": {
            "nixpkgs": {"old": "a" * 64, "new": "a" * 64},
            "home-manager": {"old": "b" * 64, "new": "b" * 64},
            "disko": {"old": "c" * 64, "new": "c" * 64},
        },
    }
    payload.update(overrides)
    return payload


def write_result(tmp_path: pathlib.Path, **overrides) -> pathlib.Path:
    out = tmp_path / f"result-{next(_seq)}.json"
    out.write_text(json.dumps(result_json(**overrides)), encoding="utf-8")
    return out


def tampered(
    tmp_path: pathlib.Path, lock: pathlib.Path, **changes: object
) -> pathlib.Path:
    """Copy of a lock with dotted paths rewritten, e.g. version=6."""
    data = json.loads(lock.read_text(encoding="utf-8"))
    for dotted, value in changes.items():
        node = data
        *parts, leaf = dotted.split(".")
        for part in parts:
            node = node[part]
        node[leaf] = value
    out = tmp_path / f"tampered-{next(_tamper_seq)}.lock"
    out.write_text(json.dumps(data), encoding="utf-8")
    return out


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [str(SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
    )


def verdict_of(r: subprocess.CompletedProcess) -> dict:
    return json.loads(r.stdout)


def green_verdict() -> dict:
    return {
        "green": True,
        "error": "",
        "kernel": {"built": KERNEL, "booted": "6.15.5", "bump": False},
        "checks": [{"name": name, "status": "PASS", "detail": ""} for name in BATTERY],
    }


def red_verdict() -> dict:
    checks = [{"name": "scope", "status": "FAIL", "detail": "origin moved"}] + [
        {"name": name, "status": "PASS", "detail": ""} for name in BATTERY[1:]
    ]
    return {
        "green": False,
        "error": "",
        "kernel": {"built": KERNEL, "booted": "6.15.5", "bump": False},
        "checks": checks,
    }


def write_verdict(tmp_path: pathlib.Path, payload: dict) -> pathlib.Path:
    out = tmp_path / f"verdict-{next(_seq)}.json"
    out.write_text(json.dumps(payload), encoding="utf-8")
    return out


# ---------------------------------------------------------------------------
# verdict: exit 0 green, exit 1 red, exit 2 artifact/maintenance error.


def test_verdict_green(tmp_path):
    result = write_result(tmp_path)
    r = run(
        "verdict",
        "--result",
        str(result),
        "--main-lock",
        str(OLD),
        "--new-lock",
        str(NEW),
        "--booted",
        BOOTED,
    )
    assert r.returncode == 0, r.stdout + r.stderr
    v = verdict_of(r)
    assert v["green"] is True
    assert v["error"] == ""
    assert v["kernel"] == {"built": KERNEL, "booted": "6.15.5", "bump": False}
    assert [c["name"] for c in v["checks"]] == BATTERY
    assert all(c["status"] == "PASS" for c in v["checks"])


def test_verdict_red(tmp_path):
    checks = [{"name": n, "status": "PASS", "detail": ""} for n in BATTERY]
    checks[0] = {"name": "scope", "status": "FAIL", "detail": "origin moved"}
    result = write_result(tmp_path, checks=checks)
    r = run(
        "verdict",
        "--result",
        str(result),
        "--main-lock",
        str(OLD),
        "--new-lock",
        str(NEW),
        "--booted",
        BOOTED,
    )
    assert r.returncode == 1
    v = verdict_of(r)
    assert v["green"] is False
    assert v["error"] == ""
    assert v["checks"][0]["status"] == "FAIL"


def test_verdict_kernel_bump(tmp_path):
    result = write_result(tmp_path, kernel="6.16.0")
    r = run(
        "verdict",
        "--result",
        str(result),
        "--main-lock",
        str(OLD),
        "--new-lock",
        str(NEW),
        "--booted",
        BOOTED,
    )
    assert r.returncode == 0, r.stdout + r.stderr
    v = verdict_of(r)
    assert v["green"] is True
    assert v["kernel"]["built"] == "6.16.0"
    assert v["kernel"]["booted"] == "6.15.5"
    assert v["kernel"]["bump"] is True


def test_verdict_new_lock_tampered(tmp_path):
    result = write_result(tmp_path)
    forged = tampered(tmp_path, NEW, **{"nodes.nixpkgs.locked.rev": "9" * 40})
    r = run(
        "verdict",
        "--result",
        str(result),
        "--main-lock",
        str(OLD),
        "--new-lock",
        str(forged),
        "--booted",
        BOOTED,
    )
    assert r.returncode == 2
    assert "new-lock sha256 mismatch" in verdict_of(r)["error"]


def test_verdict_main_moved(tmp_path):
    result = write_result(tmp_path)
    moved = tampered(tmp_path, OLD, **{"nodes.nixpkgs.locked.rev": "0" * 40})
    r = run(
        "verdict",
        "--result",
        str(result),
        "--main-lock",
        str(moved),
        "--new-lock",
        str(NEW),
        "--booted",
        BOOTED,
    )
    assert r.returncode == 2
    assert "main moved" in verdict_of(r)["error"]


def test_verdict_checks_drifted(tmp_path):
    checks = [{"name": n, "status": "PASS", "detail": ""} for n in BATTERY]
    checks.append({"name": "extra", "status": "PASS", "detail": ""})
    result = write_result(tmp_path, checks=checks)
    r = run(
        "verdict",
        "--result",
        str(result),
        "--main-lock",
        str(OLD),
        "--new-lock",
        str(NEW),
        "--booted",
        BOOTED,
    )
    assert r.returncode == 2
    assert "drifted" in verdict_of(r)["error"]


def test_verdict_bad_status(tmp_path):
    checks = [{"name": n, "status": "PASS", "detail": ""} for n in BATTERY]
    checks[2] = {"name": "ff-head", "status": "MAYBE", "detail": "?"}
    result = write_result(tmp_path, checks=checks)
    r = run(
        "verdict",
        "--result",
        str(result),
        "--main-lock",
        str(OLD),
        "--new-lock",
        str(NEW),
        "--booted",
        BOOTED,
    )
    assert r.returncode == 2
    assert "PASS/FAIL" in verdict_of(r)["error"]


def test_verdict_missing_result(tmp_path):
    r = run(
        "verdict",
        "--result",
        str(tmp_path / "nope.json"),
        "--main-lock",
        str(OLD),
        "--new-lock",
        str(NEW),
        "--booted",
        BOOTED,
    )
    assert r.returncode == 2
    assert "result file missing" in verdict_of(r)["error"]


def test_verdict_bad_booted(tmp_path):
    result = write_result(tmp_path)
    r = run(
        "verdict",
        "--result",
        str(result),
        "--main-lock",
        str(OLD),
        "--new-lock",
        str(NEW),
        "--booted",
        "",
    )
    assert r.returncode == 2
    assert "--booted" in verdict_of(r)["error"]


# ---------------------------------------------------------------------------
# table: markdown lock battery for the PR comment.


def test_table_green(tmp_path):
    verdict = write_verdict(tmp_path, green_verdict())
    r = run(
        "table",
        "--result",
        str(verdict),
        "--head-sha",
        HEAD_SHA,
        "--branch",
        BRANCH,
    )
    assert r.returncode == 0, r.stdout + r.stderr
    assert "Lock battery" in r.stdout
    assert HEAD_SHA in r.stdout
    assert BRANCH in r.stdout
    for name in BATTERY:
        assert f"`{name}`" in r.stdout
    assert "| toplevel build | PASS |" in r.stdout
    assert "kernel" in r.stdout
    assert "All checks green" in r.stdout


def test_table_red(tmp_path):
    verdict = write_verdict(tmp_path, red_verdict())
    r = run(
        "table",
        "--result",
        str(verdict),
        "--head-sha",
        HEAD_SHA,
        "--branch",
        BRANCH,
    )
    assert r.returncode == 0, r.stdout + r.stderr
    assert "DO NOT MERGE" in r.stdout


def test_table_kernel_flag(tmp_path):
    payload = green_verdict()
    payload["kernel"] = {"built": "6.16.0", "booted": "6.15.5", "bump": True}
    verdict = write_verdict(tmp_path, payload)
    r = run(
        "table",
        "--result",
        str(verdict),
        "--head-sha",
        HEAD_SHA,
        "--branch",
        BRANCH,
    )
    assert r.returncode == 0, r.stdout + r.stderr
    assert "FLAG" in r.stdout
    assert "plan a reboot" in r.stdout


def test_table_moved_inputs(tmp_path):
    verdict = write_verdict(tmp_path, green_verdict())
    inputs = tmp_path / "inputs.json"
    inputs.write_text(
        json.dumps(
            {
                "inputs": {
                    "nixpkgs": {"old": "a" * 64, "new": "a" * 64},
                    "home-manager": {"old": "1" * 64, "new": "2" * 64},
                    "disko": {"old": "c" * 64, "new": "c" * 64},
                }
            }
        ),
        encoding="utf-8",
    )
    r = run(
        "table",
        "--result",
        str(verdict),
        "--head-sha",
        HEAD_SHA,
        "--branch",
        BRANCH,
        "--inputs-file",
        str(inputs),
    )
    assert r.returncode == 0, r.stdout + r.stderr
    assert "Moved:" in r.stdout
    assert "home-manager" in r.stdout


def test_table_missing_verdict(tmp_path):
    r = run(
        "table",
        "--result",
        str(tmp_path / "nope.json"),
        "--head-sha",
        HEAD_SHA,
        "--branch",
        BRANCH,
    )
    assert r.returncode == 2


# ---------------------------------------------------------------------------
# issue: markdown exception-issue body.


def test_issue_body(tmp_path):
    verdict = write_verdict(tmp_path, red_verdict())
    r = run(
        "issue",
        "--result",
        str(verdict),
        "--branch",
        BRANCH,
        "--head-sha",
        HEAD_SHA,
        "--pr-url",
        PR_URL,
        "--run-date",
        RUN_DATE,
    )
    assert r.returncode == 0, r.stdout + r.stderr
    assert "do not merge" in r.stdout
    assert "scope" in r.stdout
    assert PR_URL in r.stdout
    assert "Part of eblume/blumeops#1318" in r.stdout
