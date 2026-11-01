"""darwin/indri/mcquack-runner-cache-prune.sh: the runner stop logic, run for real.

The script is executed as-is under bash, with PATH-prepended stubs for
`launchctl` and `uv`, and a stand-in `forgejo-runner` process: a native
binary named forgejo-runner (a symlink to bash: on macOS a `#!` script's comm
is its interpreter, so only a directly exec'd binary matches `pgrep -x`) that
ignores SIGTERM and holds a FIFO read so it has no children unless the test
gives it one. Nothing touches launchd or the real uv cache.

Covered: an idle runner that ignores SIGTERM is SIGKILLed after the grace
window and the prune still runs; a runner with a live job child is not killed
while the child lives; a runner whose job never ends hits the drain cap, exits
1, and the trap still bootstraps it back; a second forgejo-runner process (the
indri-build runner, which `pgrep -x` also matches) is neither waited on nor
killed.

Every spawned process group is SIGKILLed in a finally block, so nothing leaks.
"""

import os
import pathlib
import signal
import subprocess
import time

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASH = pathlib.Path("/bin/bash").resolve()
SCRIPT = ROOT / "darwin" / "indri" / "mcquack-runner-cache-prune.sh"

# Passed to the stand-in as `forgejo-runner -c RUNNER_BODY`.
RUNNER_BODY = """
trap '' TERM
if [ -n "${RUNNER_CHILD_PIDFILE:-}" ]; then
  sleep 1000 &
  echo $! > "${RUNNER_CHILD_PIDFILE}"
fi
exec 9<>"${RUNNER_HOLD_FIFO}"
while true; do read -r -t 1 -u 9 _ || true; done
"""

# `launchctl print` reports the job's pid the way launchd does, so the script
# can scope itself to its own runner.
LAUNCHCTL_SRC = """#!/bin/bash
if [ "$1" = print ]; then
  [ -n "${LAUNCHCTL_RUNNER_PID:-}" ] && printf '\tpid = %s\n' "${LAUNCHCTL_RUNNER_PID}"
  exit 0
fi
echo "$*" >> "${LAUNCHCTL_LOG}"
exit 0
"""

UV_SRC = """#!/bin/bash
echo "$*" >> "${UV_LOG}"
exit 0
"""


def _write_exec(path: pathlib.Path, body: str) -> None:
    path.write_text(body)
    path.chmod(0o755)


def _runner_binary(path: pathlib.Path) -> pathlib.Path:
    path.symlink_to(BASH)
    return path


@pytest.fixture
def env_setup(tmp_path):
    """Stubs, sandboxed HOME/UV_CACHE_DIR, and knobs. Yields (env, paths)."""
    bindir = tmp_path / "bin"
    runnerdir = tmp_path / "runner"
    home = tmp_path / "home"
    uvcache = tmp_path / "uvcache"
    for d in (bindir, runnerdir, home, uvcache, uvcache / "archive-v0"):
        d.mkdir()
    decoydir = tmp_path / "decoy"
    decoydir.mkdir()
    launchctl_log = tmp_path / "launchctl.log"
    uv_log = tmp_path / "uv.log"
    hold_fifo = tmp_path / "hold.fifo"
    os.mkfifo(hold_fifo)
    _write_exec(bindir / "launchctl", LAUNCHCTL_SRC)
    _write_exec(bindir / "uv", UV_SRC)
    runner = _runner_binary(runnerdir / "forgejo-runner")
    # A same-named runner the script must ignore (the indri-build runner).
    decoy = _runner_binary(decoydir / "forgejo-runner")

    env = {
        "PATH": f"{bindir}:{os.environ['PATH']}",
        "HOME": str(home),
        "UV_CACHE_DIR": str(uvcache),
        "LAUNCHCTL_LOG": str(launchctl_log),
        "UV_LOG": str(uv_log),
        "RUNNER_HOLD_FIFO": str(hold_fifo),
        "POLL_S": "1",
        "IDLE_GRACE_S": "3",
        "KILL_WAIT_S": "3",
        "DRAIN_MAX_S": "60",
    }
    paths = {
        "runner": runner,
        "decoy": decoy,
        "runnerdir": runnerdir,
        "launchctl_log": launchctl_log,
        "uv_log": uv_log,
        "child_pidfile": tmp_path / "child.pid",
        "out": tmp_path / "prune.out",
    }
    procs: list[subprocess.Popen] = []
    yield env, paths, procs

    # Teardown: SIGKILL every process group we started, plus any stray runner.
    for proc in procs:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            pass
    if paths["child_pidfile"].exists():
        try:
            os.kill(int(paths["child_pidfile"].read_text()), signal.SIGKILL)
        except (ProcessLookupError, ValueError):
            pass


def _start_runner(env, paths, procs, *, child: bool):
    """Start the stand-in runner under a reaping launcher shell.

    The launcher `wait`s for the runner so the runner's exit is reaped (the
    script would otherwise see a zombie forgejo-runner and never finish). The
    launcher and runner share a process group so teardown can killpg it.
    """
    run_env = dict(env, RUNNER_BODY=RUNNER_BODY)
    if child:
        run_env["RUNNER_CHILD_PIDFILE"] = str(paths["child_pidfile"])
    launcher = subprocess.Popen(
        ["bash", "-c", f'"{paths["runner"]}" -c "$RUNNER_BODY" & wait'],
        env=run_env,
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    procs.append(launcher)
    # Wait until pgrep -x sees the stand-in; otherwise the test proves nothing.
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        found = subprocess.run(
            ["pgrep", "-P", str(launcher.pid), "-x", "forgejo-runner"],
            capture_output=True,
            text=True,
            check=False,
        )
        if found.returncode == 0 and found.stdout.strip():
            break
        time.sleep(0.1)
    else:
        pytest.fail("stub forgejo-runner is not matched by `pgrep -x`")
    # launchd's pid for the job: the script scopes itself to it.
    env["LAUNCHCTL_RUNNER_PID"] = found.stdout.split()[0]
    if child:
        deadline = time.monotonic() + 5
        while not paths["child_pidfile"].exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        assert paths["child_pidfile"].exists(), "runner stub did not start its child"
    return launcher


def _run_script(env, paths):
    with open(paths["out"], "w") as out:
        return subprocess.run(
            ["bash", str(SCRIPT)],
            env=env,
            stdout=out,
            stderr=subprocess.STDOUT,
            timeout=120,
            check=False,
        )


def _read(paths) -> str:
    return paths["out"].read_text()


def _launchctl_calls(paths) -> list[str]:
    if not paths["launchctl_log"].exists():
        return []
    return paths["launchctl_log"].read_text().splitlines()


def _child_pid(paths) -> int:
    return int(paths["child_pidfile"].read_text())


def _start_decoy(env, paths, procs) -> subprocess.Popen:
    """Start a second same-named runner that launchd does not know about."""
    decoy = subprocess.Popen(
        [str(paths["decoy"]), "-c", RUNNER_BODY],
        env=dict(env, RUNNER_BODY=RUNNER_BODY),
        start_new_session=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    procs.append(decoy)
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        found = subprocess.run(
            ["pgrep", "-x", "forgejo-runner"],
            capture_output=True,
            text=True,
            check=False,
        )
        if str(decoy.pid) in found.stdout.split():
            return decoy
        time.sleep(0.1)
    pytest.fail("decoy forgejo-runner is not matched by `pgrep -x`")


def test_idle_sigterm_ignoring_runner_is_sigkilled(env_setup):
    env, paths, procs = env_setup
    _start_runner(env, paths, procs, child=False)

    started = time.monotonic()
    result = _run_script(env, paths)
    elapsed = time.monotonic() - started

    out = _read(paths)
    assert result.returncode == 0, out
    assert "SIGKILL" in out
    assert elapsed < float(env["DRAIN_MAX_S"]), f"took {elapsed:.1f}s"
    assert paths["uv_log"].exists(), "uv cache prune stub was not called"
    calls = _launchctl_calls(paths)
    assert any(c.startswith("bootout ") for c in calls), calls
    assert any(c.startswith("bootstrap ") for c in calls), calls


def test_runner_with_live_job_child_is_not_killed_while_child_lives(env_setup):
    env, paths, procs = env_setup
    # IDLE_GRACE_S=3 with POLL_S=1: the child outlives several grace windows.
    _start_runner(env, paths, procs, child=True)
    child_pid = _child_pid(paths)

    with open(paths["out"], "w") as out:
        proc = subprocess.Popen(
            ["bash", str(SCRIPT)],
            env=env,
            stdout=out,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        procs.append(proc)
        try:
            time.sleep(8)
            assert proc.poll() is None, "script finished while a job child was alive"
            assert "SIGKILL" not in _read(paths), _read(paths)
            os.kill(child_pid, signal.SIGKILL)
            try:
                rc = proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                pytest.fail(
                    f"script did not finish after the child exited:\n{_read(paths)}"
                )
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)

    out = _read(paths)
    assert rc == 0, out
    assert "SIGKILL" in out, out
    assert paths["uv_log"].exists(), "uv cache prune stub was not called"
    assert any(c.startswith("bootstrap ") for c in _launchctl_calls(paths)), (
        _launchctl_calls(paths)
    )


def test_drain_cap_aborts_prune_and_still_restores_runner(env_setup):
    env, paths, procs = env_setup
    env = dict(env, DRAIN_MAX_S="3")
    _start_runner(env, paths, procs, child=True)

    result = _run_script(env, paths)

    out = _read(paths)
    assert result.returncode == 1, out
    assert "still running after" in out, out
    assert "SIGKILL" not in out, out
    assert not paths["uv_log"].exists(), "prune must not run after an abort"
    assert any(c.startswith("bootstrap ") for c in _launchctl_calls(paths)), (
        _launchctl_calls(paths)
    )


def test_same_named_runner_of_another_job_is_ignored(env_setup):
    env, paths, procs = env_setup
    _start_runner(env, paths, procs, child=False)
    decoy = _start_decoy(env, paths, procs)

    result = _run_script(env, paths)

    out = _read(paths)
    assert result.returncode == 0, out
    assert decoy.poll() is None, "script killed a runner it does not own:\n" + out
    assert f"SIGKILL {env['LAUNCHCTL_RUNNER_PID']}" in out, out
    assert paths["uv_log"].exists(), "uv cache prune stub was not called"
