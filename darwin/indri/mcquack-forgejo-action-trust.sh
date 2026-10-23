#!/bin/bash
# Reconciles the Forgejo "always trust" set (action_user rows) to the V5-65
# derived declaration (forge/action-trust.nix, eblume/blumeops#1846): creates
# missing rows, refreshes last_access daily, deletes every undeclared row.
#
# One short write transaction per run; the DELETE reaches ids only, never
# names. sqlite3 runs without -readonly here (unlike the metrics collector):
# this job's whole point is the write.

set -euo pipefail

FORGEJO_DB="${FORGEJO_DB:-/Users/erichblume/forgejo/data/forgejo.db}"
OUTPUT_FILE="${FORGEJO_ACTION_TRUST_PROM:-/opt/homebrew/var/node_exporter/textfile/forgejo-action-trust.prom}"
# /usr/bin/sqlite3 is macOS's; the in-pod tests point this at their own.
SQLITE3="${FORGEJO_ACTION_TRUST_SQLITE3:-/usr/bin/sqlite3}"
# Dry-run unless the nix bake flips @dryRun@ to false; tests override via the
# env so the un-baked copy still runs.
DEFAULT_DRY_RUN="@dryRun@"
FORGEJO_ACTION_TRUST_DRY_RUN="${FORGEJO_ACTION_TRUST_DRY_RUN_OVERRIDE:-$DEFAULT_DRY_RUN}"

TEMP_FILE="${OUTPUT_FILE}.tmp"
NOW=$(date +%s)

# Registered before any failure path: every abort, including usage errors,
# ships run_success 0 instead of leaving a stale last-good file behind.
trap abort_prom EXIT

TRUST_DECLARATION_FILE="${1:-}"
if [ -z "$TRUST_DECLARATION_FILE" ]; then
  echo "usage: $0 <trust-declaration.json>" >&2
  exit 2
fi

dry_run=1
case "$FORGEJO_ACTION_TRUST_DRY_RUN" in
  true | 1) dry_run=1 ;;
  false | 0) dry_run=0 ;;
  *)
    echo "error: FORGEJO_ACTION_TRUST_DRY_RUN=${FORGEJO_ACTION_TRUST_DRY_RUN} (override=${FORGEJO_ACTION_TRUST_DRY_RUN_OVERRIDE:-unset}) must be true/false or 1/0" >&2
    exit 2
    ;;
esac

mode=live
[ "$dry_run" -eq 1 ] && mode=dry-run

log() {
  echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') [action-trust] mode=$mode $*"
}

PROM_HELP_ROWS='# HELP forgejo_action_trust_rows action_user rows created/refreshed/removed by the last run (dry-run: planned, not applied); repo="skip" rows mark guard events'
PROM_TYPE_ROWS='# TYPE forgejo_action_trust_rows gauge'
PROM_HELP_SUCCESS='# HELP forgejo_action_trust_run_success 1 if the last reconcile run finished without error'
PROM_TYPE_SUCCESS='# TYPE forgejo_action_trust_run_success gauge'

write_prom() {
  local success=$1
  shift
  {
    echo "$PROM_HELP_ROWS"
    echo "$PROM_TYPE_ROWS"
    if [ "$#" -gt 0 ]; then
      printf '%s\n' "$@"
    fi
    echo "$PROM_HELP_SUCCESS"
    echo "$PROM_TYPE_SUCCESS"
    echo "forgejo_action_trust_run_success $success"
  } >"$TEMP_FILE"
  mv -f "$TEMP_FILE" "$OUTPUT_FILE"
}

# Aborted runs still ship a prom file: the textfile must not keep serving the
# last good run while the log shows failures.
abort_prom() {
  local status=$?
  [ "$status" -eq 0 ] && return
  write_prom 0 >/dev/null 2>&1 || true
}

COLLABORATOR=$(jq -r '.collaborator' "$TRUST_DECLARATION_FILE")
OWNER=$(jq -r '.owner' "$TRUST_DECLARATION_FILE")
repos_json=$(jq -r '.repos[]' "$TRUST_DECLARATION_FILE")

# while-read, not mapfile: macOS /bin/bash is 3.2 and has no mapfile.
REPOS=()
while IFS= read -r repo; do
  [ -n "$repo" ] && REPOS+=("$repo")
done <<<"$repos_json"

# Safety rail: an empty declared set must never read as "delete everything".
if [ "${#REPOS[@]}" -eq 0 ]; then
  log "SKIP: declared trust set is empty - refusing to touch action_user"
  write_prom 0 'forgejo_action_trust_rows{repo="skip",action="empty-set"} 1'
  exit 0
fi

# Names are interpolated into SELECTs only (single-quote escaped); the write
# path that follows takes ids and timestamps, nothing else.
sql_lit() {
  local s=${1//\'/\'\'}
  printf "'%s'" "$s"
}

collab_lit=$(sql_lit "$COLLABORATOR")
owner_lit=$(sql_lit "$OWNER")

user_count=$("$SQLITE3" -cmd ".timeout 5000" "$FORGEJO_DB" "SELECT count(*) FROM user WHERE lower(name) = lower($collab_lit)")
if [ "$user_count" -ne 1 ]; then
  echo "error: expected exactly 1 user row for '$COLLABORATOR', found $user_count" >&2
  exit 1
fi
USER_ID=$("$SQLITE3" -cmd ".timeout 5000" "$FORGEJO_DB" "SELECT id FROM user WHERE lower(name) = lower($collab_lit)")
if [[ ! "$USER_ID" =~ ^[0-9]+$ ]]; then
  echo "error: collaborator '$COLLABORATOR' resolved to non-integer id '$USER_ID'" >&2
  exit 1
fi

REPO_IDS=()
for repo in "${REPOS[@]}"; do
  repo_lit=$(sql_lit "$repo")
  count=$("$SQLITE3" -cmd ".timeout 5000" "$FORGEJO_DB" "SELECT count(*) FROM repository WHERE lower(owner_name) = lower($owner_lit) AND lower(name) = lower($repo_lit)")
  if [ "$count" -ne 1 ]; then
    echo "error: expected exactly 1 repository row for '$OWNER/$repo', found $count" >&2
    exit 1
  fi
  rid=$("$SQLITE3" -cmd ".timeout 5000" "$FORGEJO_DB" "SELECT id FROM repository WHERE lower(owner_name) = lower($owner_lit) AND lower(name) = lower($repo_lit)")
  if [[ ! "$rid" =~ ^[0-9]+$ ]]; then
    echo "error: '$OWNER/$repo' resolved to non-integer id '$rid'" >&2
    exit 1
  fi
  REPO_IDS+=("$rid")
done

declared_in=$(
  IFS=,
  printf '%s' "${REPO_IDS[*]}"
)
pairs="SELECT $USER_ID, ${REPO_IDS[0]}"
for rid in "${REPO_IDS[@]:1}"; do
  pairs="$pairs UNION ALL SELECT $USER_ID, $rid"
done

plan_lines=()
action_lines=()

for i in "${!REPO_IDS[@]}"; do
  rid=${REPO_IDS[$i]}
  repo=${REPOS[$i]}
  full="$OWNER/$repo"
  row=$("$SQLITE3" -cmd ".timeout 5000" "$FORGEJO_DB" "SELECT trusted_with_pull_requests || '|' || last_access FROM action_user WHERE user_id = $USER_ID AND repo_id = $rid")
  if [ -z "$row" ]; then
    trusted=0
    last_access=""
  else
    trusted=${row%%|*}
    last_access=${row#*|}
  fi
  if [ "$trusted" -eq 1 ]; then
    plan_lines+=("refresh user=$COLLABORATOR repo=$full (last_access=$last_access)")
    action_lines+=("forgejo_action_trust_rows{repo=\"$full\",action=\"refreshed\"} 1")
  else
    # No row, or a row that exists untrusted: the reconcile brings it up to
    # trusted=1 (the UPDATE below covers the latter; the INSERT upsert skips
    # it via ON CONFLICT DO NOTHING).
    plan_lines+=("create user=$COLLABORATOR repo=$full")
    action_lines+=("forgejo_action_trust_rows{repo=\"$full\",action=\"created\"} 1")
  fi
done

# Row-value NOT IN over the declared (user_id, repo_id) pairs: full reconcile,
# every action_user row of any user that is not in the declared set. The query
# is captured in a variable (not a substitution in the loop's heredoc string):
# the loop's exit status comes from the loop, so a failure there would be
# invisible under set -e and ship run_success 1 with a silently empty plan.
# Names go into a prom label, so they are escaped like the metrics collector's
# SQL does (backslash first, then quote, then newline).
plan_out=$(
  "$SQLITE3" -separator $'\t' -cmd ".timeout 5000" "$FORGEJO_DB" \
    "SELECT coalesce(u.name, ''),
         replace(replace(replace(coalesce(r.owner_name, ''), char(92), char(92) || char(92)), char(34), char(92) || char(34)), char(10), char(92) || 'n'),
         replace(replace(replace(coalesce(r.name, ''), char(92), char(92) || char(92)), char(34), char(92) || char(34)), char(10), char(92) || 'n')
    FROM action_user au LEFT JOIN user u ON u.id = au.user_id LEFT JOIN repository r ON r.id = au.repo_id
    WHERE (au.user_id, au.repo_id) NOT IN ($pairs)"
)
while IFS=$'\t' read -r uname oname rname; do
  # The heredoc string feeds one empty line when there are no removals.
  [ -z "$uname$oname$rname" ] && continue
  if [ -n "$oname" ] && [ -n "$rname" ]; then
    full="$oname/$rname"
  else
    full="unknown"
  fi
  plan_lines+=("remove user=${uname:-unknown} repo=$full")
  action_lines+=("forgejo_action_trust_rows{repo=\"$full\",action=\"removed\"} 1")
done <<<"$plan_out"

if [ "$dry_run" -eq 1 ]; then
  for line in "${plan_lines[@]}"; do
    log "DRY-RUN would $line"
  done
  write_prom 1 "${action_lines[@]}"
  exit 0
fi

values=""
for rid in "${REPO_IDS[@]}"; do
  if [ -z "$values" ]; then
    values="($USER_ID, $rid, 1, $NOW)"
  else
    values="$values, ($USER_ID, $rid, 1, $NOW)"
  fi
done

live_sql="BEGIN IMMEDIATE;
INSERT INTO action_user (user_id, repo_id, trusted_with_pull_requests, last_access)
VALUES $values
ON CONFLICT (user_id, repo_id) DO NOTHING;

UPDATE action_user SET trusted_with_pull_requests = 1, last_access = $NOW
WHERE user_id = $USER_ID AND repo_id IN ($declared_in);

DELETE FROM action_user
WHERE (user_id, repo_id) NOT IN ($pairs);

COMMIT;"

"$SQLITE3" -cmd ".timeout 5000" "$FORGEJO_DB" "$live_sql"

for line in "${plan_lines[@]}"; do
  log "$line"
done

write_prom 1 "${action_lines[@]}"
