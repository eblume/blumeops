#!/run/current-system/sw/bin/bash
# Watches ringtail-apply sidecars and ntfys ops-approvals on two conditions:
# any verdict other than success/superseded, and a "started" sidecar that
# never reached a verdict (a hung or killed apply, a power loss) - a launch
# with no verdict is otherwise silence. Timer-triggered
# (ringtail-apply-watcher.timer); a verdict is re-posted until the post
# lands, so a missed alert only ever duplicates, never loses. A failed
# verdict alerts once per sidecar and again only if the sidecar itself
# changes. STATUS_DIR / WATCHER_SEEN / NTFY_TOPIC exist for tests.

set -euo pipefail

dir="${STATUS_DIR:-/var/log/ringtail-apply}"
seen="${WATCHER_SEEN:-$dir/.watcher-seen}"
topic="${NTFY_TOPIC:-https://ntfy.ops.eblu.me/ops-approvals}"
now=$(date +%s)
# A sidecar in flight past this with no verdict is presumed dead.
stale=$((90 * 60))

# mtime epoch of $1: GNU stat, falling back to darwin's, so the
# watcher also runs in CI on a macOS act host.
mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"
}

# $1=title $2=body; 0 when the post landed.
post() {
  curl -fsS -m 10 -X POST \
    -H "Title: $1" \
    -H "Tags: heavy_exclamation_mark" \
    -H "Priority: high" \
    --data "$2" "$topic" >/dev/null 2>&1
}

# Key every sidecar by name+mtime: a re-run of the same SHA writes a new
# file, so a second failure re-alerts, and a re-applied SHA is a new
# verdict. A key stays in the new seen file once settled (silent verdict,
# or post landed, or staleness posted); a failed post is retried next pass.
# "started <epoch>" sidecars stay out of the seen file while fresh - an
# in-flight apply must not alert - and once they go stale the staleness
# post settles them until the sidecar changes.
tmp="$seen.tmp.$$"
: > "$tmp"
for f in "$dir"/*.status; do
  [ -e "$f" ] || continue
  name=${f##*/}
  key="$name:$(mtime "$f")"
  if [ -e "$seen" ] && grep -qxF "$key" "$seen"; then
    # Settled on a previous pass - carry it over so it stays settled.
    printf '%s\n' "$key" >> "$tmp"
    continue
  fi
  value=$(cat "$f" 2>/dev/null || true)
  case "$value" in
    success | superseded)
      printf '%s\n' "$key" >> "$tmp"
      ;;
    "started "*)
      age=$((now - $(mtime "$f")))
      if [ "$age" -lt "$stale" ]; then
        continue
      fi
      echo "ringtail apply has no verdict $((age / 60)) min after launch: $key" >&2
      if post "ringtail apply stalled: $name" "sha ${name%.status} - started sidecar has no verdict after $((age / 60)) min (log: $dir/${name%.status}.log)"; then
        printf '%s\n' "$key" >> "$tmp"
      fi
      ;;
    *)
      if [ -n "$value" ]; then
        echo "ringtail apply verdict $value: $key" >&2
        if post "ringtail apply failed: $name" "sha ${name%.status} status=$value
$(tail -c 1500 "$dir/${name%.status}.log" 2>/dev/null || true)"; then
          printf '%s\n' "$key" >> "$tmp"
        fi
      else
        # An empty sidecar is a torn write from a crash; leave it so the
        # next pass sees it, but do not alert on empty text.
        :
      fi
      ;;
  esac
done
mv -f "$tmp" "$seen"
