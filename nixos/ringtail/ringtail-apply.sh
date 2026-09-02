#!/run/current-system/sw/bin/bash
# Root-side half of the ringtail-rebuild warrant workflow. Invoked only via
# the sudoers rule for gitea-runner (the priv runner); the SHA argument is
# the blumeops commit a human approved in Horkos. Checks out the bound SHA
# in /etc/blumeops and drives the detached blumeops-nixos-rebuild unit, the
# same pattern as ansible/playbooks/ringtail.yml.

set -euo pipefail

sha="${1:-}"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || {
  echo "ringtail-apply: expected a 40-hex sha, got: ${sha:-<none>}" >&2
  exit 2
}

[ -d /etc/blumeops/.git ] || {
  echo "ringtail-apply: /etc/blumeops is not a git checkout; run provision-ringtail once from gilbert first" >&2
  exit 3
}

cd /etc/blumeops
git fetch origin
git cat-file -e "${sha}^{commit}" || {
  echo "ringtail-apply: ${sha} not found on origin" >&2
  exit 3
}
# The warrant contract is "apply a commit merged to main". Enforce it here,
# where the result is authoritative: the workflow pre-flights it, but the
# checkout nixos-rebuild actually runs is this one.
git merge-base --is-ancestor "${sha}^{commit}" origin/main || {
  echo "ringtail-apply: ${sha} is not on origin/main; only merged commits can be applied" >&2
  exit 3
}
git checkout --detach --quiet "$sha"

unit=blumeops-nixos-rebuild
since=$(date +%s)
# Transient units linger once they have run; reset any leftover failed state.
systemctl reset-failed "$unit" 2>/dev/null || true
systemd-run --unit="$unit" --service-type=oneshot --property=TimeoutStartSec=3300 \
  --setenv=PATH=/run/current-system/sw/bin:/usr/bin:/bin \
  --setenv=HOME=/root \
  /run/current-system/sw/bin/nixos-rebuild switch --flake /etc/blumeops/nixos/ringtail#ringtail

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
    echo "ringtail-apply: timed out waiting for $unit" >&2
    journalctl --no-pager --unit="$unit" | tail -n 200
    exit 4
  fi
  sleep 10
done

result=$(systemctl show -p Result --value "$unit" 2>/dev/null || echo unknown)
if [ "$result" != "success" ]; then
  echo "ringtail-apply: rebuild unit finished with Result=$result" >&2
  journalctl --no-pager --unit="$unit" --since "@$since" | tail -n 400
  exit 1
fi

echo "ringtail-apply: ringtail now runs blumeops $sha"
systemctl reset-failed "$unit" 2>/dev/null || true
