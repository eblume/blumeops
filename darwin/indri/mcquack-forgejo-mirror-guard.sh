#!/bin/sh
# Watches the bare repos under the forge root and ntfys ops-approvals on two
# conditions (eblume/blumeops#1629):
# - a remote_mirror_* remote with a fetch refspec targeting refs/heads/*:
#   an in-flight mirror sync would then write the local repo's own ref, which
#   is how an in-flight sync rewound blumeops main;
# - the newest main reflog entry whose old head is not an ancestor of the new
#   head: a non-fast-forward move of the ref itself, by any writer.
# launchd agent (mcquack.eblume.forgejo-mirror-guard); each alert re-posts
# until it lands, so a missed alert only ever duplicates, never loses (the
# seen-file pattern of mcquack-indri-rebuild-watcher.sh). One 0/1 metric per
# check per repo lands in the node_exporter textfile alongside forgejo.prom.
# FORGEJO_REPOS_DIR / GUARD_SEEN / GUARD_OUT / NTFY_TOPIC exist for tests.

set -eu

repos_dir="${FORGEJO_REPOS_DIR:-/Users/erichblume/forgejo/data/forgejo-repositories}"
seen="${GUARD_SEEN:-/opt/homebrew/var/log/mcquack.forgejo-mirror-guard.seen}"
out="${GUARD_OUT:-/opt/homebrew/var/node_exporter/textfile/forgejo-mirror-guard.prom}"
topic="${NTFY_TOPIC:-https://ntfy.ops.eblu.me/ops-approvals}"

# $1=title $2=body; 0 when the post landed.
post() {
  curl -fsS -m 10 -X POST \
    -H "Title: $1" \
    -H "Tags: heavy_exclamation_mark" \
    -H "Priority: high" \
    --data "$2" "$topic" >/dev/null 2>&1
}

# One alert per key; a key stays settled in the seen file while the condition
# persists, a failed post retries on the next pass.
tmp="$seen.tmp.$$"
: > "$tmp"
# A key survives the seen-file rebuild only if re-visited this pass - settled
# ones are carried over, a fresh one on successful post - so a fixed
# misconfig or an advanced main drops out.
alert() {
  # $1=key $2=title $3=body
  if [ -e "$seen" ] && grep -qxF "$1" "$seen"; then
    printf '%s\n' "$1" >> "$tmp"
    return 0
  fi
  echo "forgejo-mirror-guard: $2" >&2
  if post "$2" "$3"; then
    printf '%s\n' "$1" >> "$tmp"
  fi
}

refspec_violations=0
rewind_violations=0
metrics=""

for repo in "$repos_dir"/*/*.git; do
  [ -d "$repo" ] || continue
  owner=${repo%/*}; owner=${owner##*/}
  name=${repo##*/}; name=${name%.git}
  full="$owner/$name"

  # --- check 1: fetch refspecs on push-mirror remotes ---
  rsv=0
  specs=$(git -C "$repo" config --get-regexp '^remote\.remote_mirror_.*\.fetch$' 2>/dev/null || true)
  if [ -n "$specs" ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      key_name=${line%% *}
      spec=${line#* }
      target=${spec##*:}
      # refs/heads/* (incl. the incident's whole-refs refs/*) is the
      # local-ref overwrite territory; any other target (refs/remotes/...,
      # refs/tags/*) is inert for the local repo.
      if [ "${target#refs/heads/}" != "$target" ] || [ "$target" = "refs/*" ]; then
        rsv=1
        alert \
          "refspec:$full:${key_name#remote.}=$spec" \
          "forgejo mirror guard: fetch refspec on push-mirror remote" \
          "$full — $key_name = $spec — push-mirror remotes must never carry a fetch refspec targeting refs/heads/* (a sync in flight would rewrite the local ref). eblume/blumeops#1629"
      fi
    done <<EOF
$specs
EOF
  fi

  # --- check 2: newest main reflog entry is a fast-forward ---
  wsv=0
  reflog="$repo/logs/refs/heads/main"
  if [ -s "$reflog" ]; then
    last=$(tail -n 1 "$reflog")
    old=${last%% *}
    rest=${last#* }
    new=${rest%% *}
    case "$old" in
      0000000000000000000000000000000000000000)
        : # branch creation — no previous head to be an ancestor
        ;;
      *)
        # The mirrors/ pull mirrors legitimately carry non-FF entries (an
        # upstream force-push) - the local repos are the guard's target.
        if [ "$owner" != "mirrors" ] &&
          ! git -C "$repo" merge-base --is-ancestor "$old" "$new" 2>/dev/null; then
          wsv=1
          alert \
            "rewind:$full:$new" \
            "forgejo mirror guard: main rewound" \
            "$full — newest main reflog entry is not a fast-forward: $last"
        fi
        ;;
    esac
  fi

  refspec_violations=$((refspec_violations + rsv))
  rewind_violations=$((rewind_violations + wsv))
  metrics="${metrics}forgejo_mirror_bad_remote_mirror_fetch_refspec{repo=\"$full\"} $rsv
forgejo_mirror_main_rewind_nonfastforward{repo=\"$full\"} $wsv
"
done

mv -f "$tmp" "$seen"

{
  echo "# HELP forgejo_mirror_guard_up 1 if the forgejo mirror guard completed this pass; a stale file means the agent is dead"
  echo "# TYPE forgejo_mirror_guard_up gauge"
  echo "# HELP forgejo_mirror_bad_remote_mirror_fetch_refspec Push-mirror remote with a fetch refspec targeting refs/heads/* (an in-flight sync would rewrite the local ref)"
  echo "# TYPE forgejo_mirror_bad_remote_mirror_fetch_refspec gauge"
  echo "# HELP forgejo_mirror_main_rewind_nonfastforward Newest main reflog entry whose old head is not an ancestor of the new head"
  echo "# TYPE forgejo_mirror_main_rewind_nonfastforward gauge"
  echo "# HELP forgejo_mirror_violations Repos with a refspec or rewind violation on this pass"
  echo "# TYPE forgejo_mirror_violations gauge"
  echo "forgejo_mirror_guard_up 1"
  echo "forgejo_mirror_violations $((refspec_violations + rewind_violations))"
  printf '%s' "$metrics"
} > "$out.tmp.$$"
mv -f "$out.tmp.$$" "$out"
