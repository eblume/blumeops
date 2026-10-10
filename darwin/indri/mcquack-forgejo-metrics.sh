#!/bin/bash
# Collects Forgejo repository health and Actions CI metrics for the
# node_exporter textfile collector.
#
# Repo metrics come from the API. CI metrics (forgejo_ci_*) are read straight
# from Forgejo's sqlite DB, read-only: the API exposes no runner queue or job
# timing history, and Forgejo's own /metrics has no Actions metrics at all.

set -euo pipefail

FORGEJO_URL="http://localhost:3001"
FORGEJO_DB="/Users/erichblume/forgejo/data/forgejo.db"
API_KEY_FILE="/Users/erichblume/.forgejo-api-key"
OUTPUT_FILE="/opt/homebrew/var/node_exporter/textfile/forgejo.prom"
TEMP_FILE="${OUTPUT_FILE}.tmp"

TOKEN=$(cat "$API_KEY_FILE" 2>/dev/null | tr -d '\n' || true)

# Authenticated API request; returns empty string on failure
api() {
    curl -sf -H "Authorization: token ${TOKEN}" -H "Accept: application/json" \
        "${FORGEJO_URL}/api/v1${1}" 2>/dev/null || echo ""
}

# jq helper: convert ISO 8601 timestamp (with any tz offset) to epoch seconds
# jq's fromdate only handles Z, so we parse the offset and apply it manually
JQ_EPOCH='def epoch: sub("[.][0-9]+"; "") | if test("[+-][0-9]{2}:[0-9]{2}$") then capture("^(?<dt>.*)(?<sign>[+-])(?<h>[0-9]{2}):(?<m>[0-9]{2})$") | (.dt + "Z" | fromdate) as $base | ((.h | tonumber) * 3600 + (.m | tonumber) * 60) as $off | if .sign == "-" then $base + $off else $base - $off end else sub("Z$"; "") + "Z" | fromdate end;'

# The CI query. A function, not a heredoc inside $(...): bash 3.2 (macOS
# /bin/bash) mis-parses parentheses in a heredoc nested in a substitution.
ci_sql() {
cat << 'SQL'
-- Forgejo Actions CI metrics, read straight from Forgejo's sqlite DB.
-- Prints Prometheus text-format sample lines (HELP/TYPE live in the caller).
-- Forgejo enums: action status 1 success, 2 failure, 3 cancelled,
-- 4 skipped, 5 waiting, 6 running, 7 blocked.
WITH
nowts(ts) AS (SELECT CAST(strftime('%s', 'now') AS INTEGER)),
repo AS (SELECT id, owner_name || '/' || name AS full FROM repository),
-- One name per runner: re-registrations leave old rows under the same name.
runner AS (SELECT id, name FROM action_runner),
job AS (
  SELECT j.id, j.status, j.created, j.updated,
         coalesce(json_extract(j.runs_on, '$[0]'), '') AS label,
         r.repo_id, r.approved_by, r.need_approval, r.created AS run_created,
         replace(replace(r.workflow_id, '.yaml', ''), '.yml', '') AS workflow,
         -- A job with `needs` is ready once its last dependency stops.
         (SELECT max(s.stopped) FROM json_each(j.needs) n
            JOIN action_run_job s ON s.run_id = j.run_id AND s.job_id = n.value) AS needs_done
  FROM action_run_job j JOIN action_run r ON r.id = j.run_id
),
task AS (
  SELECT t.attempt, t.status, t.started, t.stopped, t.created,
         coalesce(ru.name, 'unknown') AS runner,
         job.label, job.workflow, coalesce(repo.full, 'unknown') AS repo,
         CASE WHEN job.approved_by > 0 THEN 'approval' ELSE 'none' END AS gate,
         max(job.created, coalesce(job.needs_done, 0)) AS ready
  FROM action_task t
  JOIN job ON job.id = t.job_id
  LEFT JOIN repo ON repo.id = job.repo_id
  LEFT JOIN runner ru ON ru.id = t.runner_id
),
done AS (SELECT * FROM task WHERE status IN (1, 2, 3, 4) AND stopped >= started AND started > 0),
-- Queue wait: ready -> picked up by a runner. First attempts only (a re-run
-- reuses the job row, so its `created` is the original run's). gate=approval
-- marks fork-PR runs that sat behind a human "Approve and run" click.
qw AS (SELECT label, gate, max(0, created - ready) AS v FROM task WHERE attempt = 1 AND ready > 0),
dur AS (SELECT label, stopped - started AS v FROM done),
qb(le) AS (VALUES (1), (2), (5), (10), (30), (60), (120), (300), (600), (1800), (3600), (7200), (21600), (86400)),
gated AS (
  SELECT coalesce(repo.full, 'unknown') AS repo, r.created, r.pull_request_id AS pr
  FROM action_run r
  LEFT JOIN repo ON repo.id = r.repo_id
  LEFT JOIN pull_request p ON p.id = r.pull_request_id
  LEFT JOIN issue i ON i.id = p.issue_id
  WHERE r.need_approval = 1 AND r.status = 7 AND coalesce(i.is_closed, 0) = 0
),
db(le) AS (VALUES (5), (10), (30), (60), (120), (300), (600), (1200), (1800), (3600), (7200), (10800))
SELECT line FROM (
  SELECT printf('forgejo_ci_jobs_total{repo="%s",workflow="%s",label="%s",status="%s"} %d',
                repo, workflow, label,
                CASE status WHEN 1 THEN 'success' WHEN 2 THEN 'failure' WHEN 3 THEN 'cancelled' ELSE 'skipped' END,
                count(*)) AS line
  FROM done GROUP BY repo, workflow, label, status

  UNION ALL
  SELECT printf('forgejo_ci_queue_wait_seconds_bucket{label="%s",gate="%s",le="%d"} %d', label, gate, le, sum(v <= le))
  FROM qw CROSS JOIN qb GROUP BY label, gate, le
  UNION ALL
  SELECT printf('forgejo_ci_queue_wait_seconds_bucket{label="%s",gate="%s",le="+Inf"} %d', label, gate, count(*)) FROM qw GROUP BY label, gate
  UNION ALL
  SELECT printf('forgejo_ci_queue_wait_seconds_sum{label="%s",gate="%s"} %d', label, gate, sum(v)) FROM qw GROUP BY label, gate
  UNION ALL
  SELECT printf('forgejo_ci_queue_wait_seconds_count{label="%s",gate="%s"} %d', label, gate, count(*)) FROM qw GROUP BY label, gate

  UNION ALL
  SELECT printf('forgejo_ci_job_duration_seconds_bucket{label="%s",le="%d"} %d', label, le, sum(v <= le))
  FROM dur CROSS JOIN db GROUP BY label, le
  UNION ALL
  SELECT printf('forgejo_ci_job_duration_seconds_bucket{label="%s",le="+Inf"} %d', label, count(*)) FROM dur GROUP BY label
  UNION ALL
  SELECT printf('forgejo_ci_job_duration_seconds_sum{label="%s"} %d', label, sum(v)) FROM dur GROUP BY label
  UNION ALL
  SELECT printf('forgejo_ci_job_duration_seconds_count{label="%s"} %d', label, count(*)) FROM dur GROUP BY label

  -- Busy time per runner, counting in-flight tasks up to now, so
  -- rate() is the runner's average number of occupied slots.
  UNION ALL
  SELECT printf('forgejo_ci_runner_busy_seconds_total{runner="%s"} %d', runner,
                sum(CASE WHEN status = 6 THEN (SELECT ts FROM nowts) - started ELSE stopped - started END))
  FROM task WHERE started > 0 AND (status = 6 OR stopped >= started) GROUP BY runner

  -- Current state. Queued = waiting for a runner; its age is measured from
  -- `updated`, which Forgejo stamps on the transition to waiting.
  UNION ALL
  SELECT printf('forgejo_ci_jobs_queued{label="%s"} %d', label, count(*)) FROM job WHERE status = 5 GROUP BY label
  UNION ALL
  SELECT printf('forgejo_ci_queue_oldest_age_seconds{label="%s"} %d', label, (SELECT ts FROM nowts) - min(updated))
  FROM job WHERE status = 5 GROUP BY label
  UNION ALL
  SELECT printf('forgejo_ci_jobs_running{label="%s",runner="%s"} %d', label, runner, count(*))
  FROM task WHERE status = 6 GROUP BY label, runner
  -- Fork-PR runs blocked on "Approve and run". Runs of closed PRs stay
  -- blocked forever, so only open PRs (or PR-less runs) count.
  UNION ALL
  SELECT printf('forgejo_ci_runs_awaiting_approval{repo="%s"} %d', repo, count(*)) FROM gated GROUP BY repo
  UNION ALL
  SELECT printf('forgejo_ci_prs_awaiting_approval{repo="%s"} %d', repo, count(DISTINCT pr)) FROM gated GROUP BY repo
  UNION ALL
  SELECT printf('forgejo_ci_approval_oldest_age_seconds{repo="%s"} %d', repo, (SELECT ts FROM nowts) - min(created))
  FROM gated GROUP BY repo

  -- Runners seen in the last 30 days (older rows are retired registrations).
  UNION ALL
  SELECT printf('forgejo_ci_runner_last_online_timestamp_seconds{runner="%s"} %d', name, max(last_online))
  FROM action_runner WHERE last_online > (SELECT ts FROM nowts) - 30 * 86400 AND coalesce(deleted, 0) = 0 GROUP BY name
  UNION ALL
  SELECT printf('forgejo_ci_runner_info{runner="%s",labels="%s",version="%s"} 1', a.name,
                (SELECT group_concat(value, ',') FROM json_each(a.agent_labels)), a.version)
  FROM action_runner a
  WHERE a.id = (SELECT max(b.id) FROM action_runner b WHERE b.name = a.name)
    AND a.last_online > (SELECT ts FROM nowts) - 30 * 86400 AND coalesce(a.deleted, 0) = 0
);
SQL
}

forgejo_up=0
if curl -sf "${FORGEJO_URL}/api/v1/version" >/dev/null 2>&1; then
    forgejo_up=1
fi

{
# --- Metric type declarations ---
cat << 'HEADER'
# HELP forgejo_up Forgejo server is up and responding
# TYPE forgejo_up gauge
# HELP forgejo_repo_open_pull_requests Number of open pull requests
# TYPE forgejo_repo_open_pull_requests gauge
# HELP forgejo_repo_open_issues Number of open issues
# TYPE forgejo_repo_open_issues gauge
# HELP forgejo_repo_language_bytes Repository language size in bytes
# TYPE forgejo_repo_language_bytes gauge
# HELP forgejo_repo_releases_total Total number of releases
# TYPE forgejo_repo_releases_total gauge
# HELP forgejo_repo_latest_release_timestamp_seconds Unix timestamp of the latest release
# TYPE forgejo_repo_latest_release_timestamp_seconds gauge
# HELP forgejo_repo_latest_commit_timestamp_seconds Unix timestamp of the latest commit on default branch
# TYPE forgejo_repo_latest_commit_timestamp_seconds gauge
# HELP forgejo_actions_last_success_timestamp_seconds Unix timestamp of last successful run per workflow
# TYPE forgejo_actions_last_success_timestamp_seconds gauge
# HELP forgejo_ci_collector_up 1 if the CI section read the Forgejo DB this cycle
# TYPE forgejo_ci_collector_up gauge
# HELP forgejo_ci_jobs_total Finished Actions job attempts (tasks) by repo, workflow, runner label and result
# TYPE forgejo_ci_jobs_total counter
# HELP forgejo_ci_queue_wait_seconds Time from a job becoming ready (created, or its needs finished) to a runner picking it up; first attempts only. gate="approval" runs include the wait for a human "Approve and run"
# TYPE forgejo_ci_queue_wait_seconds histogram
# HELP forgejo_ci_job_duration_seconds Runtime of finished Actions job attempts by runner label
# TYPE forgejo_ci_job_duration_seconds histogram
# HELP forgejo_ci_runner_busy_seconds_total Task-seconds a runner has spent running jobs (rate = mean occupied slots)
# TYPE forgejo_ci_runner_busy_seconds_total counter
# HELP forgejo_ci_runner_capacity Concurrent job slots configured on the runner (mirrors its config; see script)
# TYPE forgejo_ci_runner_capacity gauge
# HELP forgejo_ci_jobs_queued Jobs waiting for a runner, by label
# TYPE forgejo_ci_jobs_queued gauge
# HELP forgejo_ci_queue_oldest_age_seconds Age of the oldest job waiting for a runner, by label
# TYPE forgejo_ci_queue_oldest_age_seconds gauge
# HELP forgejo_ci_jobs_running Jobs running now, by label and runner
# TYPE forgejo_ci_jobs_running gauge
# HELP forgejo_ci_runs_awaiting_approval Fork-PR runs on open PRs blocked on "Approve and run"
# TYPE forgejo_ci_runs_awaiting_approval gauge
# HELP forgejo_ci_prs_awaiting_approval Open PRs with at least one run blocked on "Approve and run"
# TYPE forgejo_ci_prs_awaiting_approval gauge
# HELP forgejo_ci_approval_oldest_age_seconds Age of the oldest run blocked on "Approve and run"
# TYPE forgejo_ci_approval_oldest_age_seconds gauge
# HELP forgejo_ci_runner_last_online_timestamp_seconds Last time the runner polled Forgejo
# TYPE forgejo_ci_runner_last_online_timestamp_seconds gauge
# HELP forgejo_ci_runner_info Runner registration (labels, version); value is always 1
# TYPE forgejo_ci_runner_info gauge
HEADER

echo "forgejo_up ${forgejo_up}"

if [ "$forgejo_up" -eq 1 ] && [ -n "$TOKEN" ]; then
    # Discover all repos accessible to the token owner
    repos_json=$(api "/repos/search?limit=50")
    [ -z "$repos_json" ] && repos_json='{"data":[]}'

    repo_count=$(echo "$repos_json" | jq '.data | length' 2>/dev/null || echo "0")

    for i in $(seq 0 $((repo_count - 1))); do
        repo_data=$(echo "$repos_json" | jq ".data[$i]")
        full_name=$(echo "$repo_data" | jq -r '.full_name')
        [ -z "$full_name" ] || [ "$full_name" = "null" ] && continue

        r="$full_name"

        # Basic repo metrics (from search results — no extra API call)
        echo "forgejo_repo_open_pull_requests{repo=\"${r}\"} $(echo "$repo_data" | jq '.open_pr_counter // 0')"
        echo "forgejo_repo_open_issues{repo=\"${r}\"} $(echo "$repo_data" | jq '.open_issues_count // 0')"

        default_branch=$(echo "$repo_data" | jq -r '.default_branch // "main"')

        # --- Languages ---
        langs=$(api "/repos/${r}/languages")
        if [ -n "$langs" ] && echo "$langs" | jq -e 'type == "object" and length > 0' >/dev/null 2>&1; then
            echo "$langs" | jq -r --arg r "$r" \
                'to_entries[] | "forgejo_repo_language_bytes{repo=\"\($r)\",language=\"\(.key)\"} \(.value)"' \
                2>/dev/null || true
        fi

        # --- Releases ---
        releases=$(api "/repos/${r}/releases?limit=50")
        if [ -n "$releases" ] && echo "$releases" | jq -e 'type == "array"' >/dev/null 2>&1; then
            echo "forgejo_repo_releases_total{repo=\"${r}\"} $(echo "$releases" | jq 'length')"
            # Latest release timestamp and version
            echo "$releases" | jq -r --arg r "$r" "${JQ_EPOCH}"'
                if length > 0 then
                    .[0] |
                    "forgejo_repo_latest_release_timestamp_seconds{repo=\"\($r)\",version=\"\(.tag_name)\"} \((.published_at // .created_at // .created) | epoch)"
                else empty end' 2>/dev/null || true
        else
            echo "forgejo_repo_releases_total{repo=\"${r}\"} 0"
        fi

        # --- Latest commit on default branch ---
        commits=$(api "/repos/${r}/commits?limit=1&sha=${default_branch}")
        if [ -n "$commits" ] && echo "$commits" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
            echo "$commits" | jq -r --arg r "$r" "${JQ_EPOCH}"'
                .[0] |
                "forgejo_repo_latest_commit_timestamp_seconds{repo=\"\($r)\"} \((.created // .commit.committer.date) | epoch)"' \
                2>/dev/null || true
        fi

        # --- Action runs: last success per workflow (all other CI metrics
        # come from the DB section below) ---
        runs_json=$(api "/repos/${r}/actions/runs?limit=30")
        if [ -n "$runs_json" ] && echo "$runs_json" | jq -e '.workflow_runs | type == "array"' >/dev/null 2>&1; then
            # Discover current workflow files on the default branch (.forgejo/ or .github/)
            current_wfs=""
            for wf_dir in .forgejo/workflows .github/workflows; do
                wf_list=$(api "/repos/${r}/contents/${wf_dir}?ref=${default_branch}")
                if [ -n "$wf_list" ] && echo "$wf_list" | jq -e 'type == "array"' >/dev/null 2>&1; then
                    current_wfs=$(echo "$wf_list" | jq -r '[.[].name] | join(",")' 2>/dev/null || true)
                    break
                fi
            done

            # Per-workflow last success timestamp, for workflows that
            # currently exist on the default branch.
            # Forgejo fields: workflow_id (filename), created/stopped
            if [ -n "$current_wfs" ]; then
                echo "$runs_json" | jq -r --arg r "$r" --arg wfs "$current_wfs" "${JQ_EPOCH}"'
                    ($wfs | split(",")) as $current |
                    [.workflow_runs[] | select((.status == "success" or .status == "failure") and (.workflow_id | IN($current[])))] |
                    if length > 0 then
                        group_by(.workflow_id) | .[] |
                        (sort_by(.created) | reverse) as $sorted |
                        ($sorted[0].workflow_id | sub("[.]ya?ml$"; "")) as $wf |
                        ([$sorted[] | select(.status == "success")] |
                            if length > 0 then
                                .[0] as $last_ok |
                                "forgejo_actions_last_success_timestamp_seconds{repo=\"\($r)\",workflow=\"\($wf)\"} \($last_ok.stopped | epoch)"
                            else empty end)
                    else empty end' 2>/dev/null || true
            fi
        fi
    done
fi

# --- CI metrics from the Forgejo DB (read-only) ---
# Slots per runner, mirrored from each runner's config: indri-runner and
# indri-build from ansible/roles/forgejo_runner (forgejo_runner_capacity),
# the ringtail pair from nixos/ringtail/configuration.nix. Keep in step.
cat << 'CAPACITY'
forgejo_ci_runner_capacity{runner="indri-runner"} 2
forgejo_ci_runner_capacity{runner="indri-build"} 2
forgejo_ci_runner_capacity{runner="ringtail-nix-builder"} 1
forgejo_ci_runner_capacity{runner="ringtail-priv-runner"} 1
CAPACITY

if ci_lines=$(ci_sql | /usr/bin/sqlite3 -readonly -cmd ".timeout 5000" "$FORGEJO_DB" 2>/dev/null); then
    echo "forgejo_ci_collector_up 1"
    if [ -n "$ci_lines" ]; then echo "$ci_lines"; fi
else
    echo "forgejo_ci_collector_up 0"
fi
} > "$TEMP_FILE"

# Atomic move
mv "$TEMP_FILE" "$OUTPUT_FILE"
