"""status-sidecar watchers: ringtail-apply and mcquack-indri-rebuild.

I drive both scripts as subprocesses with a tmp dir prepended to PATH: a
`curl` stub (appends every arg to $CURL_LOG, exits $CURL_RC, default 0,
so a test can model a failed post). Each script reads mtime through a
helper that tries GNU `stat -c %Y` then darwin `stat -f %m`, so the real
scripts run unmodified on whatever platform the CI host is. The ringtail
script is invoked via explicit `bash` and the indri one via `sh`: their
shebangs point at store paths that do not exist here. Each script keys
sidecars by name:mtime-epoch and rebuilds the seen file every pass, so an
unchanged sidecar is quiet, a re-run of the same name re-alerts only when
the sidecar itself changes, a "started" sidecar is silence while fresh and
alerts once stale, and a failed post is never recorded — the next pass
retries it.
"""

import os
import pathlib
import shutil
import subprocess
import time

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASH = shutil.which("bash") or "bash"
SH = shutil.which("sh") or "sh"

# One arg per log line, in invocation order: the parser reconstructs the
# (possibly multi-line) --data body from the fixed argument positions.
CURL_STUB = """\
#!/bin/sh
# curl stub for the watcher tests: no network here. Appends every arg on
# its own line to $CURL_LOG, then exits $CURL_RC (default 0) so a test can
# model a failed post that the script must retry next pass.
for _a in "$@"; do
  printf '%s\\n' "$_a" >>"${CURL_LOG:?curl stub: CURL_LOG is required}"
done
exit "${CURL_RC:-0}"
"""

SCRIPTS = [
    {
        "id": "ringtail",
        "script": ROOT / "nixos" / "ringtail" / "ringtail-apply-watcher.sh",
        "invoke": [BASH],
        "silent": ("success", "superseded"),
        "failed": "rebuild-failed",
        "failed_title": "ringtail apply failed",
        "stalled_title": "ringtail apply stalled",
        "verdict_echo": "ringtail apply verdict",
    },
    {
        "id": "indri",
        "script": ROOT / "darwin" / "indri" / "mcquack-indri-rebuild-watcher.sh",
        "invoke": [SH],
        "silent": ("0", "superseded"),
        "failed": "1",
        "failed_title": "indri switch failed",
        "stalled_title": "indri switch stalled",
        "verdict_echo": "indri switch verdict",
    },
]


class Watcher:
    """Stub curl on a tmp PATH; drive one script."""

    def __init__(self, spec: dict, tmp_path: pathlib.Path):
        self.spec = spec
        self.dir = tmp_path / "status"
        self.dir.mkdir()
        self.seen = tmp_path / "seen"
        bin = tmp_path / "bin"
        bin.mkdir()
        curl = bin / "curl"
        curl.write_text(CURL_STUB, encoding="utf-8")
        curl.chmod(0o755)
        self.bin = bin
        self.curl_log = tmp_path / "curl.log"

    def sidecar(self, sha: str, content: str, mtime: int | None = None) -> pathlib.Path:
        f = self.dir / f"{sha}.status"
        f.write_text(content, encoding="utf-8")
        if mtime is not None:
            os.utime(f, (mtime, mtime))
        return f

    def logfile(self, sha: str, content: str) -> pathlib.Path:
        f = self.dir / f"{sha}.log"
        f.write_text(content, encoding="utf-8")
        return f

    def key(self, sha: str) -> str:
        mtime = int(os.stat(self.dir / f"{sha}.status").st_mtime)
        return f"{sha}.status:{mtime}"

    def run(self, curl_rc: str = "0") -> subprocess.CompletedProcess:
        env = dict(os.environ)
        env.update(
            PATH=f"{self.bin}{os.pathsep}{env.get('PATH', '')}",
            STATUS_DIR=str(self.dir),
            WATCHER_SEEN=str(self.seen),
            NTFY_TOPIC="https://ntfy.invalid/ops-approvals",
            CURL_LOG=str(self.curl_log),
            CURL_RC=curl_rc,
        )
        return subprocess.run(
            [*self.spec["invoke"], str(self.spec["script"])],
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def posts(self) -> list[dict]:
        """Reconstruct the stub log (one arg per line) into {title, body}."""
        if not self.curl_log.exists():
            return []
        lines = self.curl_log.read_text(encoding="utf-8").splitlines()
        url = "https://ntfy.invalid/ops-approvals"
        out = []
        i = 0
        while i < len(lines):
            # fixed sequence: -fsS -m 10 -X POST -H Title -H Tags -H Prio
            # --data BODY URL; BODY may span lines (never a line == url).
            assert lines[i] == "-fsS" and lines[i + 4] == "POST", lines[i : i + 5]
            assert lines[i + 11] == "--data", lines[i : i + 13]
            title = lines[i + 6].removeprefix("Title: ")
            j = i + 12
            body = []
            while lines[j] != url:
                body.append(lines[j])
                j += 1
            out.append({"title": title, "body": "\n".join(body)})
            i = j + 1
        return out

    def seen_lines(self) -> list[str]:
        if not self.seen.exists():
            return []
        return self.seen.read_text(encoding="utf-8").splitlines()


@pytest.fixture(params=SCRIPTS, ids=[s["id"] for s in SCRIPTS])
def watcher(request, tmp_path):
    return Watcher(request.param, tmp_path)


# --- verdicts ------------------------------------------------------------


def test_failed_verdict_posts_then_seen(watcher):
    watcher.sidecar("deadbeef", watcher.spec["failed"])
    watcher.logfile("deadbeef", "nginx unit crashed\n")

    r = watcher.run()
    assert r.returncode == 0, r.stderr
    assert watcher.spec["verdict_echo"] in r.stderr
    posts = watcher.posts()
    assert len(posts) == 1
    assert posts[0]["title"] == f"{watcher.spec['failed_title']}: deadbeef.status"
    assert "status=" in posts[0]["body"]
    assert "nginx unit crashed" in posts[0]["body"]
    # the landed post settles the key until the sidecar itself changes
    assert watcher.seen_lines() == [watcher.key("deadbeef")]


def test_unchanged_sidecar_posts_nothing_again(watcher):
    watcher.sidecar("abc123", watcher.spec["failed"])
    watcher.logfile("abc123", "boom\n")

    r1 = watcher.run()
    assert r1.returncode == 0, r1.stderr
    assert len(watcher.posts()) == 1

    r2 = watcher.run()
    assert r2.returncode == 0, r2.stderr
    assert len(watcher.posts()) == 1

    # a settled key stays settled: no re-post on a third pass
    r3 = watcher.run()
    assert r3.returncode == 0, r3.stderr
    assert len(watcher.posts()) == 1


def test_second_failure_new_mtime_posts_again(watcher):
    watcher.sidecar("def456", watcher.spec["failed"], mtime=1_700_000_000)

    r1 = watcher.run()
    assert r1.returncode == 0, r1.stderr
    assert len(watcher.posts()) == 1

    # a re-run of the same SHA is a new sidecar: new mtime, new alert
    watcher.sidecar("def456", watcher.spec["failed"], mtime=1_700_003_600)
    r2 = watcher.run()
    assert r2.returncode == 0, r2.stderr
    assert len(watcher.posts()) == 2


def test_silent_verdicts_post_nothing(watcher):
    for verdict in watcher.spec["silent"]:
        watcher.sidecar(f"silent-{verdict}", verdict)

    r = watcher.run()
    assert r.returncode == 0, r.stderr
    assert watcher.posts() == []
    # the silent verdicts settle: their keys land in the seen file
    for verdict in watcher.spec["silent"]:
        assert watcher.key(f"silent-{verdict}") in watcher.seen_lines()


# --- started (in-flight / stalled) ---------------------------------------


def test_fresh_started_sidecar_is_silent(watcher):
    watcher.sidecar("1234567890abcdef", "started 1234567890")

    r = watcher.run()
    assert r.returncode == 0, r.stderr
    assert watcher.posts() == []
    # in-flight: not settled, so the key must not land in the seen file
    assert watcher.key("1234567890abcdef") not in watcher.seen_lines()


def test_stale_started_sidecar_alerts_stalled(watcher):
    old = int(time.time()) - 91 * 60
    watcher.sidecar("fedcba", f"started {old}", mtime=old)

    r = watcher.run()
    assert r.returncode == 0, r.stderr
    posts = watcher.posts()
    assert len(posts) == 1
    assert watcher.spec["stalled_title"] in posts[0]["title"]
    # the staleness post settles the key until the sidecar changes
    assert watcher.key("fedcba") in watcher.seen_lines()

    # a settled stalled key stays settled on the next pass
    r2 = watcher.run()
    assert r2.returncode == 0, r2.stderr
    assert len(watcher.posts()) == 1


# --- retry a failed post -------------------------------------------------


def test_failed_post_is_retried_next_pass(watcher):
    watcher.sidecar("cafe0000", watcher.spec["failed"])

    r1 = watcher.run(curl_rc="1")
    assert r1.returncode == 0, r1.stderr
    assert len(watcher.posts()) == 1
    # the failed post is not recorded, so the next pass re-posts
    assert watcher.seen_lines() == []

    r2 = watcher.run(curl_rc="1")
    assert r2.returncode == 0, r2.stderr
    assert len(watcher.posts()) == 2
    assert watcher.seen_lines() == []
