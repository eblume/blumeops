#!/run/current-system/sw/bin/bash
# Root-side half of the ringtail-rebuild warrant workflow. Runs as the root
# template unit ringtail-apply@<sha>.service (nixos/ringtail/configuration.nix),
# which polkit lets the priv runner's horkos-runner user start — the runner
# runs with NoNewPrivileges, so sudo is not an option there.
# The instance name is the blumeops commit a human approved in Horkos. Checks
# out the bound SHA in /etc/blumeops and drives the detached
# blumeops-nixos-rebuild unit, the same pattern as ansible/playbooks/ringtail.yml.
# stdout/stderr are appended to /var/log/ringtail-apply/<sha>.log by the unit;
# the rebuild unit's journal is streamed into the same log while the job runs,
# so the log carries the rebuild's full output on every outcome, including one
# where the runner is killed mid-rebuild and nothing else writes.
# The verdict goes to /var/log/ringtail-apply/<sha>.status via the EXIT trap
# below; the ringtail-apply-watcher unit alerts on anything but success/superseded.

set -euo pipefail

sha="${1:-}"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || {
  status=usage
  echo "ringtail-apply: expected a 40-hex sha, got: ${sha:-<none>}" >&2
  exit 2
}

# A leftover sidecar from an earlier apply of this SHA would masquerade as this
# apply's verdict; the "started" sidecar below stands in for it and gets the
# watcher's no-verdict staleness alert if nothing ever overwrites it.
rm -f /var/log/ringtail-apply/"${sha}.status"
echo "started $(date +%s)" > /var/log/ringtail-apply/"${sha}.status.tmp"   && mv -f /var/log/ringtail-apply/"${sha}.status.tmp" /var/log/ringtail-apply/"${sha}.status"

status=interrupted
write_status() {
  # The usage exit above fires before the trap exists; nothing to record.
  [ "${#sha}" -eq 40 ] || return 0
  printf '%s\n' "$status" > /var/log/ringtail-apply/"${sha}.status.tmp" \
    && mv -f /var/log/ringtail-apply/"${sha}.status.tmp" /var/log/ringtail-apply/"${sha}.status" \
    || true
}
# One trap covers every path: kill the journal follower if it started, then
# record the sidecar verdict (status= is set right before each exit).
trap 'kill "${journal_pid:-}" 2>/dev/null || true; write_status' EXIT

# Exclusive flock so two applies can't overlap; skipped where flock is absent
# (the capacity-1 priv runner queue already prevents real overlap).
if command -v flock >/dev/null 2>&1; then
  exec 9>/var/lock/ringtail-apply.lock
  flock -n 9 || {
    status=busy
    echo "ringtail-apply: another apply holds the lock" >&2
    exit 5
  }
else
  echo "ringtail-apply: flock not found; skipping apply lock" >&2
fi

echo "=== ringtail-apply $(date -Is) sha=$sha"

[ -d /etc/blumeops/.git ] || {
  status=no-checkout
  echo "ringtail-apply: /etc/blumeops is not a git checkout; run provision-ringtail once from gilbert first" >&2
  exit 3
}

cd /etc/blumeops
git fetch origin
git cat-file -e "${sha}^{commit}" || {
  status=unknown-sha
  echo "ringtail-apply: ${sha} not found on origin" >&2
  exit 3
}
# The warrant contract is "apply a commit merged to main". Enforce it here,
# where the result is authoritative: the workflow pre-flights it, but the
# checkout nixos-rebuild actually runs is this one.
git merge-base --is-ancestor "${sha}^{commit}" origin/main || {
  status=not-on-main
  echo "ringtail-apply: ${sha} is not on origin/main; only merged commits can be applied" >&2
  exit 3
}
main_sha=$(git rev-parse origin/main)
# Main has moved past this SHA. Skip only when a newer run is coming: a
# trigger-paths merge already started one. A merge to anything else triggers
# nothing, so skipping there drops this apply for good; apply the bound,
# pre-flighted SHA instead. (Trigger paths mirror the push filter in
# .forgejo/workflows/ringtail-rebuild.yaml - keep them in sync.)
if [ "$main_sha" != "$sha" ]; then
  if git diff --quiet "$sha" origin/main -- nixos/ringtail/; then
    echo "ringtail-apply: origin/main ($main_sha) is ahead but nixos/ringtail/ is unchanged - no newer run is coming; applying the bound sha"
  else
    echo "ringtail-apply: ${sha} superseded by origin/main $main_sha; skipping"
    status=superseded
    exit 0
  fi
fi
git checkout --detach --quiet "$sha"

unit=blumeops-nixos-rebuild
since=$(date +%s)
# Transient units linger once they have run; reset any leftover failed state.
systemctl reset-failed "$unit" 2>/dev/null || true
# --no-block: without it systemd-run waits on the D-Bus job, and a mid-activation
# restart of dbus-broker kills the wait and aborts the wrapper while the rebuild
# runs on (the same incident ansible/playbooks/ringtail.yml documents).
systemd-run --no-block --unit="$unit" --service-type=oneshot --property=TimeoutStartSec=3300 \
  --setenv=PATH=/run/current-system/sw/bin:/usr/bin:/bin \
  --setenv=HOME=/root \
  /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/blumeops/nixos/ringtail#ringtail

# Stream the rebuild unit's journal into the per-sha log as it happens: the log
# must stay complete when the runner dies mid-rebuild, and the journal is where
# the rebuild's output goes. stdbuf -oL keeps the follower line-buffered so the
# last lines reach the log before the trap kills it.
stdbuf -oL journalctl --no-pager --output=cat --follow --unit="$unit" --since "@$since" \
  >> /var/log/ringtail-apply/"${sha}.log" &
journal_pid=$!

# Keep the wrapper's own deadline inside the job's 1-hour runner timeout (the
# priv instance sets timeout = "1h").
deadline=$(($(date +%s) + 3480))
while :; do
  state=$(systemctl show -p ActiveState --value "$unit" 2>/dev/null || echo unknown)
  case "$state" in
    inactive | failed) break ;;
  esac
  now=$(date +%s)
  if [ "$now" -ge "$deadline" ]; then
    status=timeout
    echo "ringtail-apply: timed out waiting for $unit" >&2
    journalctl --no-pager --unit="$unit" | tail -n 200
    exit 4
  fi
  sleep 10
done

result=$(systemctl show -p Result --value "$unit" 2>/dev/null || echo unknown)
if [ "$result" != "success" ]; then
  status="rebuild-$result"
  echo "ringtail-apply: rebuild unit finished with Result=$result" >&2
  journalctl --no-pager --unit="$unit" --since "@$since" | tail -n 400
  exit 1
fi

status=success
echo "ringtail-apply: ringtail now runs blumeops $sha"
systemctl reset-failed "$unit" 2>/dev/null || true
