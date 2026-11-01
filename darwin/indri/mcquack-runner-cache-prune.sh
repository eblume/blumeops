#!/bin/bash
# Monthly prune of orphaned wheel archives in ~/.cache/uv. The runner is
# booted out first: `uv cache prune` also removes per-script
# environments, which an in-flight job may be using (eblume/blumeops#1065).
set -euo pipefail

RUNNER_LABEL="mcquack.eblume.forgejo-runner"
RUNNER_PLIST="${HOME}/Library/LaunchAgents/mcquack.eblume.forgejo-runner.plist"
UV_CACHE="${UV_CACHE_DIR:-${HOME}/.cache/uv}"
# DRAIN_MAX_S caps the wait for in-flight jobs (the runner's 3 h job timeout).
DRAIN_MAX_S="${DRAIN_MAX_S:-10800}"
# A runner with no job children gets this long to exit before SIGKILL.
IDLE_GRACE_S="${IDLE_GRACE_S:-120}"
KILL_WAIT_S="${KILL_WAIT_S:-30}"
POLL_S="${POLL_S:-5}"

log() { printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"; }

# This job's runner, by launchd's pid, captured before bootout. `pgrep -x
# forgejo-runner` alone also matches the indri-build runner (another user, same
# binary), which must neither be waited on nor killed.
runner_pid="$(launchctl print "gui/$(id -u)/${RUNNER_LABEL}" 2>/dev/null | sed -n 's/^[[:space:]]*pid = //p' | head -n1 || true)"

if ! bootout_out="$(launchctl bootout "gui/$(id -u)/${RUNNER_LABEL}" 2>&1)"; then
  log "bootout: ${bootout_out}"
fi

restored=0
restore_runner() {
  if [ "${restored}" -eq 1 ]; then return; fi
  log "bootstrapping ${RUNNER_LABEL}"
  if launchctl bootstrap "gui/$(id -u)" "${RUNNER_PLIST}"; then
    restored=1
  else
    log "ERROR: runner bootstrap failed — reload it manually"
  fi
}
trap restore_runner EXIT

# A job step is a direct child of the runner; deeper descendants are not
# checked. Zombies hold no work, so they don't count.
has_job_children() {
  local child stat
  for child in $(pgrep -P "$1" 2>/dev/null || true); do
    stat="$(ps -o stat= -p "${child}" 2>/dev/null || true)"
    if [ -n "${stat}" ] && [ "${stat:0:1}" != "Z" ]; then return 0; fi
  done
  return 1
}

# The pids this script owns: its runner while alive. Without a launchd pid,
# fall back to this user's forgejo-runner processes.
owned_runner_pids() {
  if [ -n "${runner_pid}" ]; then
    if kill -0 "${runner_pid}" 2>/dev/null; then echo "${runner_pid}"; fi
  else
    pgrep -x -U "$(id -u)" forgejo-runner 2>/dev/null || true
  fi
}

# Wait for the runner process to actually exit before touching the cache.
# With jobs in flight, wait (up to DRAIN_MAX_S). Once it has no job children
# for IDLE_GRACE_S, it's hung in shutdown with nothing to drain: SIGKILL it.
# launchd has already booted it out, so KeepAlive won't respawn it.
elapsed=0
idle=0
killed=0
kill_elapsed=0
while runner_pids="$(owned_runner_pids)" && [ -n "${runner_pids}" ]; do
  if [ "${killed}" -eq 1 ]; then
    if [ "${kill_elapsed}" -ge "${KILL_WAIT_S}" ]; then
      log "ERROR: runner survived SIGKILL for ${KILL_WAIT_S}s; aborting prune"
      exit 1
    fi
    kill_elapsed=$((kill_elapsed + POLL_S))
  else
    if [ "${elapsed}" -ge "${DRAIN_MAX_S}" ]; then
      log "ERROR: runner still running after ${DRAIN_MAX_S}s; aborting prune"
      exit 1
    fi
    busy=0
    for pid in ${runner_pids}; do
      if has_job_children "${pid}"; then busy=1; fi
    done
    if [ "${busy}" -eq 1 ]; then
      idle=0
    else
      idle=$((idle + POLL_S))
    fi
    if [ "${idle}" -ge "${IDLE_GRACE_S}" ]; then
      log "runner idle for ${idle}s with no job children; SIGKILL ${runner_pids}"
      for pid in ${runner_pids}; do kill -KILL "${pid}" 2>/dev/null || true; done
      killed=1
    fi
    elapsed=$((elapsed + POLL_S))
  fi
  sleep "${POLL_S}"
done
if [ "${killed}" -eq 0 ]; then
  log "runner exited after ${elapsed}s"
fi

du_uv() { du -sm "${UV_CACHE}" 2>/dev/null | cut -f1 || true; }

before="$(du_uv)"
archive_before="$(du -sm "${UV_CACHE}/archive-v0" 2>/dev/null | cut -f1 || true)"
log "uv cache: ${before} MiB total, ${archive_before} MiB in archive-v0 — pruning"
uv cache prune
log "uv cache: ${before} MiB -> $(du_uv) MiB"
log "done"
