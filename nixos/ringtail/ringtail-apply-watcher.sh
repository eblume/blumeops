#!/run/current-system/sw/bin/bash
# Watches ringtail-apply verdict sidecars and ntfys ops-approvals on any
# outcome other than success/superseded, so a failed apply alerts on its own.
# Timer-triggered (ringtail-apply-watcher.timer); a verdict is re-posted until
# the post lands, so a missed alert only ever duplicates, never loses.

set -euo pipefail

dir=/var/log/ringtail-apply
seen="$dir/.watcher-seen"
topic=https://ntfy.ops.eblu.me/ops-approvals

# First run after install: seed with the existing sidecars so pre-existing
# verdicts don't raise a retroactive alert.
if [ ! -e "$seen" ]; then
  : > "$seen"
  for f in "$dir"/*.status; do
    [ -e "$f" ] || continue
    printf '%s\n' "${f##*/}" >> "$seen"
  done
  exit 0
fi

# Rewrite seen each pass, pruning names whose sidecar is gone - a re-applied
# sha is a new verdict and must alert again if it fails. A name is settled
# (recorded in the new seen file) once its verdict is silent or its post
# landed; a failed post is retried next pass.
tmp="$dir/.watcher-seen.tmp.$$"
: > "$tmp"
for f in "$dir"/*.status; do
  [ -e "$f" ] || continue
  name=${f##*/}
  # Carried over by default; a not-yet-seen name must settle (silent verdict
  # or landed post) this pass or it is retried.
  settled=1
  if ! grep -qxF "$name" "$seen"; then
    settled=0
    value=$(cat "$f" 2>/dev/null || true)
    case "$value" in
      success | superseded) settled=1 ;;
      *)
        if [ -n "$value" ]; then
          data="sha ${name%.status} status=$value
$(tail -c 1500 "$dir/${name%.status}.log" 2>/dev/null || true)"
          if curl -fsS -m 10 -X POST \
            -H "Title: ringtail apply failed: $name" \
            -H "Tags: heavy_exclamation_mark" \
            -H "Priority: high" \
            --data "$data" "$topic" >/dev/null 2>&1; then
            settled=1
          else
            echo "ringtail-apply-watcher: ntfy post failed for $name; retrying" >&2
          fi
        fi
        ;;
    esac
  fi
  if [ "$settled" -eq 1 ]; then
    printf '%s\n' "$name" >> "$tmp"
  fi
done
mv -f "$tmp" "$seen"
