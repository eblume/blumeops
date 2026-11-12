#!/usr/bin/env bash
# Pre-merge dry start of forgejo on indri (V5-83 PR 1). Runs ON indri, fed on stdin:
#   PIN=$(sed -n 's/^forgejo_version: "\(.*\)"/\1/p' darwin/indri/forgejo-pins.yaml)
#   ssh indri "bash -s -- $PIN" < darwin/indri/forgejo-dry-start.sh
# The pin is an argument because the script arrives on stdin and cannot read the repo.
# Touches the live tree only to READ the three secret files; everything it writes
# lives in a mktemp scratch dir removed on exit. Port 13099, never the live 3001.
set -euo pipefail

expected="${1:?usage: bash -s -- <forgejo_version from darwin/indri/forgejo-pins.yaml, e.g. v16.0.6>}"
binary=/Users/erichblume/code/3rd/forgejo/forgejo
live_secrets=/Users/erichblume/forgejo/secrets
live_db=/Users/erichblume/forgejo/data/forgejo.db
port=13099

fail() { printf 'FAIL: %s\n' "$*"; exit 1; }

# (a) version: same parse as the role and the nix checks slot - the bare version
# followed by "+", so 16.0.6 does not match 16.0.60.
[[ -x "$binary" ]] || fail "forgejo binary missing or not executable at $binary"
version_line=$("$binary" --version 2> /dev/null || true)
printf 'forgejo --version: %s\n' "$version_line"
needle="${expected#v}+"
grep -qF "$needle" <<< "$version_line" || fail "binary does not report $expected (wanted '$needle')"
echo "version: OK ($expected)"

for f in lfs-jwt-secret internal-token oauth2-jwt-secret; do
  [[ -r "$live_secrets/$f" && -s "$live_secrets/$f" ]] || fail "secret file missing or empty: $live_secrets/$f"
done
echo "secrets: present (read-only use)"

scratch=$(mktemp -d "${TMPDIR:-/tmp}/forgejo-dry-start.XXXXXX")
pid=
cleanup() {
  if [[ -n "$pid" ]] && kill -0 "$pid" 2> /dev/null; then
    kill "$pid" 2> /dev/null || true
    wait "$pid" 2> /dev/null || true
  fi
  rm -rf "$scratch"
}
trap cleanup EXIT

# (b) scratch config: only the sections under test. Secrets are *_URI references
# to the REAL files (read by forgejo, never copied or printed). Everything else
# points into $scratch.
ini="$scratch/app.ini"
mkdir -p "$scratch/data/repos" "$scratch/data/lfs" "$scratch/log"
cat > "$ini" <<INI
APP_NAME = Forgejo dry start
RUN_MODE = prod
WORK_PATH = $scratch

[server]
HTTP_ADDR = 127.0.0.1
HTTP_PORT = $port
DOMAIN = 127.0.0.1
ROOT_URL = http://127.0.0.1:$port/
APP_DATA_PATH = $scratch/data
START_SSH_SERVER = false
DISABLE_SSH = true
LFS_START_SERVER = true
LFS_JWT_SECRET_URI = file:$live_secrets/lfs-jwt-secret
OFFLINE_MODE = true

[database]
DB_TYPE = sqlite3
PATH = $scratch/data/forgejo.db

[repository]
ROOT = $scratch/data/repos

[lfs]
PATH = $scratch/data/lfs

[security]
INSTALL_LOCK = true
INTERNAL_TOKEN_URI = file:$live_secrets/internal-token

[oauth2]
JWT_SECRET_URI = file:$live_secrets/oauth2-jwt-secret

[mailer]
ENABLED = false

[packages]
ENABLED = false

[cron.update_mirrors]
ENABLED = false

[cron.archive_cleanup]
ENABLED = false

[cron.cleanup_actions]
ENABLED = false

[log]
MODE = console
LEVEL = info
ROOT_PATH = $scratch/log
INI

# The scratch config must not name the live database.
if grep -qF "$live_db" "$ini"; then
  fail "scratch config references the live database path $live_db"
fi
echo "scratch config: $ini (no live database path)"

out="$scratch/forgejo.out"
"$binary" -w "$scratch" -c "$ini" web > "$out" 2>&1 &
pid=$!

healthy=0
for _ in $(seq 1 60); do
  if ! kill -0 "$pid" 2> /dev/null; then
    break
  fi
  if curl -fsS "http://127.0.0.1:$port/api/healthz" > /dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 1
done

if [[ $healthy -ne 1 ]]; then
  tail -n 40 "$out" || true
  fail "healthz did not answer on 127.0.0.1:$port within 60s"
fi
echo "healthz: OK"

# Secret/URI load errors surface in the log; match them without printing values.
if grep -iE '(secret|_uri|jwt|token|file:).*(error|fail|fatal|panic)|(error|fatal|panic).*(secret|_uri|jwt|token|file:)' "$out" > "$scratch/hits" ; then
  fail "log reports $(wc -l < "$scratch/hits" | tr -d ' ') secret/URI load error line(s); the scratch log is not printed (it may echo values)"
fi
echo "log: no secret/URI errors"

kill -0 "$pid" 2> /dev/null || fail "forgejo process exited after healthz"
echo "process: alive"

printf 'PASS: forgejo %s starts from the nix-style URI config on 127.0.0.1:%s\n' "$expected" "$port"
