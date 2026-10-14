#!/bin/sh
# Watches indri-rebuild sidecars and ntfys ops-approvals on two conditions:
# any verdict other than 0/superseded, and a "started" sidecar that never
# reached a verdict (a hung or killed switch, a reboot, a power loss) - a
# launch with no verdict is otherwise silence. Launchd agent
# (mcquack.eblume.indri-rebuild-watcher); a verdict is re-posted until the
# post lands, so a missed alert only ever duplicates, never loses. A failed
# verdict alerts once per sidecar and again only if the sidecar itself
# changes. STATUS_DIR / WATCHER_SEEN / NTFY_TOPIC exist for tests.

set -eu

dir="${STATUS_DIR:-/var/log/indri-rebuild}"
seen="${WATCHER_SEEN:-/opt/homebrew/var/log/mcquack.indri-rebuild-watcher.seen}"
topic="${NTFY_TOPIC:-https://ntfy.ops.eblu.me/ops-approvals}"
now=$(date +%s)
# A sidecar in flight past this with no verdict is presumed dead.
stale=$((90 * 60))

# mtime epoch of $1: GNU stat, falling back to darwin's, so the
# watcher also runs in CI on a macOS act host (and survives a
# homebrew coreutils `stat` shadowing /usr/bin/stat).
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

# Key every sidecar by name+mtime so a re-run of the same SHA
# or of "main" writes a new file and re-alerts on a second failure. A key
# stays in the new seen file once settled; a failed post is retried next
# pass. "started <epoch>" sidecars stay out of the seen file while fresh -
# an in-flight switch must not alert - and once stale the staleness post
# settles them until the sidecar changes.
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
    0 | superseded)
      printf '%s\n' "$key" >> "$tmp"
      ;;
    "started "*)
      age=$((now - $(mtime "$f")))
      if [ "$age" -lt "$stale" ]; then
        continue
      fi
      echo "indri switch has no verdict $((age / 60)) min after launch: $key" >&2
      if post "indri switch stalled: $name" "sha ${name%.status} - started sidecar has no verdict after $((age / 60)) min (log: $dir/${name%.status}.log)"; then
        printf '%s\n' "$key" >> "$tmp"
      fi
      ;;
    *)
      if [ -n "$value" ]; then
        echo "indri switch verdict $value: $key" >&2
        if post "indri switch failed: $name" "sha ${name%.status} status=$value
$(tail -c 1500 "$dir/${name%.status}.log" 2>/dev/null || true)"; then
          printf '%s\n' "$key" >> "$tmp"
        fi
      else
        # An empty sidecar is a torn write from a crash; leave it for the
        # next pass, but do not alert on empty text.
        :
      fi
      ;;
  esac
done
mv -f "$tmp" "$seen"
