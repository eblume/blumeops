#!/run/current-system/sw/bin/bash
# Ringtail-side endpoint for indri's borgmatic k8s/PV dumps
# (eblume/blumeops#1484). Run as root via sudo by the dedicated `borgmatic`
# user (its only privilege) with exactly one argument: a name from the fixed
# table at the bottom. The dump streams to stdout; diagnostics go to stderr.
#
# The table mirrors the remote halves of indri's borgmatic role
# (ansible/roles/borgmatic/defaults/main.yml + k8s-{sqlite,file,tar}-dump.sh.j2);
# the indri side switches to call this by name in eblume/blumeops#1484 PR 2.
set -euo pipefail

# Pinned store path under root (the sudo path); the env override exists for
# tests and dry-runs only and must stay inert when the script runs as root.
K3S=/run/current-system/sw/bin/k3s
if [[ ${EUID:-0} -ne 0 && -n "${BORGMATIC_K3S:-}" ]]; then
  K3S="$BORGMATIC_K3S"
fi

# Online SQLite backup: stage the file next to the source DB (minimal nix
# images have no /tmp), read it back, delete. Pod image must ship python3.
# Only a Running pod: an Evicted/Failed pod lingers as an object, sorts first
# by name, and exec into it aborts the run.
dump_sqlite() { # <namespace> <selector> <db_path> <name>
  local ns=$1 sel=$2 db=$3 name=$4 pod
  local pod_tmp
  pod_tmp="$(dirname "$db")/.borgmatic-backup-${name}.db"
  pod=$($K3S kubectl -n "$ns" get pod -l "$sel" --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}')
  $K3S kubectl -n "$ns" exec "$pod" -- python3 -c \
    "import sqlite3; sqlite3.connect('$db').backup(sqlite3.connect('$pod_tmp'))" 1>&2
  $K3S kubectl -n "$ns" exec "$pod" -- python3 -c \
    "import sys, shutil; shutil.copyfileobj(open('$pod_tmp', 'rb'), sys.stdout.buffer)"
  $K3S kubectl -n "$ns" exec "$pod" -- python3 -c \
    "import os; os.unlink('$pod_tmp')" 1>&2
}

# Stream the pod's data dir as tar. Container named for multi-container pods
# (kubectl exec without -c refuses them); pod image must ship tar.
dump_tar() { # <namespace> <selector> <dir> <name> [<container>]
  local ns=$1 sel=$2 dir=$3 name=$4 pod
  local container=${5:-}
  pod=$($K3S kubectl -n "$ns" get pod -l "$sel" --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}')
  if [[ -n "$container" ]]; then
    $K3S kubectl -n "$ns" exec -c "$container" "$pod" -- tar cf - \
      -C "$(dirname "$dir")" "$(basename "$dir")"
  else
    $K3S kubectl -n "$ns" exec "$pod" -- tar cf - \
      -C "$(dirname "$dir")" "$(basename "$dir")"
  fi
}

# Ferry the pod's own newest backup file matching <glob>. Pod image must ship
# coreutils (ls/cat). A missing match is a hard error — a live service should
# have a backup.
dump_file() { # <namespace> <selector> <dir> <glob> <name>
  local ns=$1 sel=$2 dir=$3 glob=$4 name=$5 pod
  local newest="" f
  pod=$($K3S kubectl -n "$ns" get pod -l "$sel" --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}')
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    # shellcheck disable=SC2053  # glob match on purpose, like the indri helpers
    [[ "$f" == $glob ]] || continue
    [[ "$f" > "$newest" ]] && newest="$f"
  done < <($K3S kubectl -n "$ns" exec "$pod" -- ls -1 "$dir")
  if [[ -z "$newest" ]]; then
    echo "borgmatic-dump: no $glob in $dir ($name)" >&2
    exit 1
  fi
  echo "borgmatic-dump: $name -> $newest" >&2
  $K3S kubectl -n "$ns" exec "$pod" -- cat "$dir/$newest"
}

# Read the newest export off a local-path PV's host dir (no pod exec: the
# source CronJob's pod is Succeeded by ferry time). A missing or empty export
# keeps the previous staged export: no output, exit 0. An unresolvable PVC/PV
# or a missing PV dir is a real error and aborts.
dump_pv() { # <namespace> <pvc> <subpath> <glob> <name>
  local ns=$1 pvc=$2 dir=$3 glob=$4 name=$5
  local pv_name pv_path src
  local newest="" f
  pv_name=$($K3S kubectl -n "$ns" get pvc "$pvc" -o jsonpath='{.spec.volumeName}')
  if [[ -z "$pv_name" ]]; then
    echo "borgmatic-dump: PVC $pvc not bound in $ns ($name)" >&2
    exit 1
  fi
  pv_path=$($K3S kubectl get pv "$pv_name" -o jsonpath='{.spec.local.path}')
  if [[ -z "$pv_path" ]]; then
    echo "borgmatic-dump: PV $pv_name has no local.path ($name)" >&2
    exit 1
  fi
  if [[ ! -d "$pv_path" ]]; then
    echo "borgmatic-dump: PV dir $pv_path missing on host or not a directory ($name)" >&2
    exit 1
  fi
  local listing
  if [[ -d "$pv_path$dir" ]]; then
    if ! listing="$(ls -1 "$pv_path$dir" 2>&1)"; then
      # An existing dir we cannot list is a real host error — it must not
      # fall into the keep-previous path below.
      echo "borgmatic-dump: $pv_path$dir: $listing ($name)" >&2
      exit 1
    fi
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      # shellcheck disable=SC2053  # glob match on purpose, like the indri helpers
      [[ "$f" == $glob ]] || continue
      [[ "$f" > "$newest" ]] && newest="$f"
    done <<<"$listing"
  fi
  if [[ -z "$newest" ]]; then
    echo "borgmatic-dump: no $glob in $pv_path$dir yet ($name); keeping previous staged export" >&2
    exit 0
  fi
  src="$pv_path$dir/$newest"
  if [[ ! -s "$src" ]]; then
    echo "borgmatic-dump: newest $glob ($newest) is empty ($name); keeping previous staged export" >&2
    exit 0
  fi
  echo "borgmatic-dump: $name -> $newest (pv:$pv_path)" >&2
  cat "$src"
}

if [[ $# -ne 1 ]]; then
  echo "borgmatic-dump: usage: borgmatic-dump <name>" >&2
  echo "  names: mealie horkos navidrome audiobookshelf pulumi-tail8d86e-state" \
    " pulumi-eblu-me-state talos-data paperless-media" >&2
  exit 2
fi

case $1 in
  # k8s-sqlite: online .backup via in-pod python3.
  mealie)
    dump_sqlite mealie app=mealie /app/data/mealie.db mealie
    ;;
  horkos)
    dump_sqlite horkos app=horkos /data/horkos.db horkos
    ;;
  # k8s-file: the service's own newest backup file, ferried out of a pod.
  navidrome)
    dump_file navidrome app=navidrome /data/backup 'navidrome_backup_*.db' navidrome
    ;;
  audiobookshelf)
    dump_file audiobookshelf app=audiobookshelf /metadata/backups '*.audiobookshelf' audiobookshelf
    ;;
  # k8s-file, pv mode: export read off the PVC's host dir.
  pulumi-tail8d86e-state)
    dump_pv pulumi-stack-backup pulumi-stack-backup /tail8d86e 'stack_*.json' pulumi-tail8d86e-state
    ;;
  pulumi-eblu-me-state)
    dump_pv pulumi-stack-backup pulumi-stack-backup /eblu-me 'stack_*.json' pulumi-eblu-me-state
    ;;
  # k8s-tar: pod data dir tarred in-pod.
  talos-data)
    dump_tar talos app=talos /home/talos/data talos-data
    ;;
  paperless-media)
    dump_tar paperless app=paperless /usr/src/paperless/media paperless-media web
    ;;
  *)
    echo "borgmatic-dump: unknown dump name: $1" >&2
    exit 2
    ;;
esac
