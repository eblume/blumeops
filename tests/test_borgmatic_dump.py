"""borgmatic-dump: the ringtail dump endpoint for indri's borgmatic k8s/PV
dumps (eblume/blumeops#1484, PR 1).

The script is repository bash that runs as root on ringtail; here it is
driven as a subprocess with BORGMATIC_K3S pointed at a stub `k3s`, so
nothing touches a cluster. The stub appends every invocation to a log
(K3S_LOG), answers `kubectl get pod/pvc/pv` from a canned JSON mapping
(env-named, keyed by a PREFIX of the joined args, longest key wins — same
shape as the flake-lock-check curl stub), and emulates `kubectl exec POD --
<cmd>` against a fake per-test pod filesystem (POD_FS_DIR). A missing
mapping key or an unrecognized in-pod command aborts the stub loudly: a
forgotten map must fail the test, not silently green the check.

Note the deliberate divergence from test_flake_lock_check: that script
shebangs `#!/usr/bin/env bash`, so it is invoked by path and exec'd. This
script shebangs the ringtail store path `/run/current-system/sw/bin/bash`,
which does not exist in this pod or CI, so we invoke it through an explicit
`bash` from PATH.
"""

import json
import os
import pathlib
import shutil
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "nixos" / "ringtail" / "borgmatic-dump.sh"
BASH = shutil.which("bash") or "bash"

SQLITE_BYTES = b"SQLITE-FIXTURE-BYTES\n"

# The k3s stub. Log lines are the raw "$*" join, so tests assert the exact
# kubectl argument sequence per dump kind.
K3S_STUB = """\
#!/usr/bin/env bash
# k3s stub for the borgmatic-dump tests: no cluster here. Logs every
# invocation to $K3S_LOG, answers `kubectl get pod/pvc/pv` from
# $K3S_STUB_MAPPING (JSON keyed by a PREFIX of the joined args; the longest
# matching key wins), and emulates `kubectl exec POD -- CMD` against the
# fake pod root $POD_FS_DIR. A missing mapping key or an unrecognized
# in-pod command aborts loudly: a forgotten map must fail the test, not
# silently green the check.
set -u

log="${K3S_LOG:?k3s stub: K3S_LOG is required}"
mapping="${K3S_STUB_MAPPING:?k3s stub: K3S_STUB_MAPPING is required}"
pod_fs="${POD_FS_DIR:?k3s stub: POD_FS_DIR is required}"

printf '%s\\n' "$*" >>"$log"

args=("$@")
dash=-1
for ((i = 0; i < ${#args[@]}; i++)); do
  [[ "${args[$i]}" == "--" ]] && dash="$i"
done

if ((dash >= 0)); then
  # kubectl ... exec POD -- CMD ...: emulate a tiny in-pod filesystem.
  cmd=("${args[@]:dash+1}")
  case "${cmd[0]}" in
    python3)
      # cmd = (python3 -c CODE)
      code="${cmd[2]}"
      case "$code" in
        "import sqlite3"*)
          # backup: sqlite3.connect('DB').backup(sqlite3.connect('TMP'))
          re="sqlite3\\.connect\\('([^']*)'\\)\\.backup\\(sqlite3\\.connect\\('([^']*)'\\)\\)"
          if [[ "$code" =~ $re ]]; then
            cp "$pod_fs/${BASH_REMATCH[1]}" "$pod_fs/${BASH_REMATCH[2]}"
          else
            echo "k3s stub: unparseable sqlite backup code: $code" >&2
            exit 1
          fi
          ;;
        "import sys, shutil"*)
          # stream: shutil.copyfileobj(open('TMP', 'rb'), sys.stdout.buffer)
          re="open\\('([^']*)'"
          if [[ "$code" =~ $re ]]; then
            cat "$pod_fs/${BASH_REMATCH[1]}"
          else
            echo "k3s stub: unparseable sqlite stream code: $code" >&2
            exit 1
          fi
          ;;
        "import os"*)
          # unlink: os.unlink('TMP')
          re="os\\.unlink\\('([^']*)'\\)"
          if [[ "$code" =~ $re ]]; then
            rm -f "$pod_fs/${BASH_REMATCH[1]}"
          else
            echo "k3s stub: unparseable sqlite unlink code: $code" >&2
            exit 1
          fi
          ;;
        *)
          echo "k3s stub: unrecognized python3 -c code: $code" >&2
          exit 1
          ;;
      esac
      ;;
    ls)
      # ls -1 DIR: listing comes from a per-test $DIR/.listing fixture.
      [[ "${cmd[1]:-}" == "-1" ]] || {
        echo "k3s stub: unexpected ls args: ${cmd[*]}" >&2
        exit 1
      }
      listing="$pod_fs${cmd[2]}/.listing"
      [[ -f "$listing" ]] || {
        echo "k3s stub: no .listing for ${cmd[2]}" >&2
        exit 1
      }
      cat "$listing"
      ;;
    cat)
      cat "$pod_fs/${cmd[1]}"
      ;;
    tar)
      # tar cf - -C A B
      [[ "${cmd[1]}" == cf && "${cmd[2]}" == "-" && "${cmd[3]}" == -C ]] || {
        echo "k3s stub: unexpected tar args: ${cmd[*]}" >&2
        exit 1
      }
      tar cf - -C "$pod_fs/${cmd[4]}" "${cmd[5]}"
      ;;
    *)
      echo "k3s stub: unrecognized in-pod command: ${cmd[*]}" >&2
      exit 1
      ;;
  esac
  exit $?
fi

if [[ "${1:-}" != "kubectl" ]]; then
  echo "k3s stub: unexpected top-level command: $*" >&2
  exit 1
fi
# kubectl get pod/pvc/pv: longest key prefix wins. An empty canned answer
# is a valid value (e.g. an unbound PVC) — only a MISSING key aborts.
joined="$*"
best=""
bestlen=0
while IFS= read -r k; do
  [[ -n "$k" ]] || continue
  if [[ "$joined" == "$k"* ]]; then
    if (( ${#k} > bestlen )); then
      best="$k"
      bestlen="${#k}"
    fi
  fi
done < <(jq -r 'keys[]' "$mapping" 2>/dev/null)
[[ -n "$best" ]] || {
  echo "k3s stub: no mapping prefix for: $joined" >&2
  exit 1
}
answer="$(jq -r --arg k "$best" '.[$k]' "$mapping")"
printf '%s\\n' "$answer"
"""


class Stubs:
    """Stub k3s executable + canned mapping + fake pod/host filesystems."""

    def __init__(self, tmp_path: pathlib.Path):
        bin = tmp_path / "bin"
        bin.mkdir()
        self.k3s = bin / "k3s"
        self.log = tmp_path / "k3s.log"
        self.mapping = tmp_path / "k3s-mapping.json"
        self.pod_fs = tmp_path / "podfs"
        self.pod_fs.mkdir()
        self.host_root = tmp_path / "pv-host"
        self.host_root.mkdir()
        self.k3s.write_text(K3S_STUB, encoding="utf-8")
        self.k3s.chmod(0o755)
        self.write_mapping({})

    def write_mapping(self, mapping: dict) -> None:
        self.mapping.write_text(json.dumps(mapping), encoding="utf-8")

    def env(self, **extra) -> dict[str, str]:
        env = dict(os.environ)
        env.update(
            BORGMATIC_K3S=str(self.k3s),
            K3S_LOG=str(self.log),
            K3S_STUB_MAPPING=str(self.mapping),
            POD_FS_DIR=str(self.pod_fs),
        )
        env.update(extra)
        return env

    def run(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [BASH, str(SCRIPT), *args],
            env=self.env(),
            capture_output=True,
            text=True,
            check=False,
        )

    def log_lines(self) -> list[str]:
        if not self.log.exists():
            return []
        return self.log.read_text(encoding="utf-8").splitlines()

    def pod_file(self, pod_path: str) -> pathlib.Path:
        """Host path in the fake pod fs for an in-pod path (parents made)."""
        host = self.pod_fs / pod_path.lstrip("/")
        host.parent.mkdir(parents=True, exist_ok=True)
        return host


@pytest.fixture
def stubs(tmp_path):
    return Stubs(tmp_path)


def get_pod_line(ns: str, sel: str) -> str:
    return (
        f"kubectl -n {ns} get pod -l {sel} "
        "--field-selector=status.phase=Running "
        "-o jsonpath={.items[0].metadata.name}"
    )


def get_pvc_line(ns: str, pvc: str) -> str:
    return f"kubectl -n {ns} get pvc {pvc} -o jsonpath={{.spec.volumeName}}"


def get_pv_line(pv: str) -> str:
    return f"kubectl get pv {pv} -o jsonpath={{.spec.local.path}}"


def sqlite_log(ns: str, sel: str, pod: str, db: str, name: str) -> list[str]:
    tmp = f"{pathlib.Path(db).parent}/.borgmatic-backup-{name}.db"
    return [
        get_pod_line(ns, sel),
        (
            f"kubectl -n {ns} exec {pod} -- python3 -c "
            f"import sqlite3; sqlite3.connect('{db}').backup(sqlite3.connect('{tmp}'))"
        ),
        (
            f"kubectl -n {ns} exec {pod} -- python3 -c "
            f"import sys, shutil; shutil.copyfileobj(open('{tmp}', 'rb'), sys.stdout.buffer)"
        ),
        (f"kubectl -n {ns} exec {pod} -- python3 -c import os; os.unlink('{tmp}')"),
    ]


def sqlite_stub(stubs: Stubs, ns: str, sel: str, db: str, name: str) -> str:
    pod = f"{name}-pod"
    stubs.pod_file(db).write_bytes(SQLITE_BYTES)
    stubs.write_mapping({f"kubectl -n {ns} get pod -l {sel}": pod})
    return pod


# --- usage ---------------------------------------------------------------


def test_usage_no_args(stubs):
    r = stubs.run()
    assert r.returncode == 2
    assert "usage: borgmatic-dump <name>" in r.stderr
    assert stubs.log_lines() == []


def test_usage_two_args(stubs):
    r = stubs.run("mealie", "extra")
    assert r.returncode == 2
    assert "usage: borgmatic-dump <name>" in r.stderr
    assert stubs.log_lines() == []


def test_unknown_name(stubs):
    r = stubs.run("nonesuch")
    assert r.returncode == 2
    assert "unknown dump name: nonesuch" in r.stderr
    assert stubs.log_lines() == []


# --- sqlite dumps (mealie, horkos) ---------------------------------------


def test_mealie_sqlite(stubs):
    pod = sqlite_stub(stubs, "mealie", "app=mealie", "/app/data/mealie.db", "mealie")

    r = stubs.run("mealie")
    assert r.returncode == 0, r.stderr
    # stdout is exactly the dump bytes (streaming guarantee), no diagnostics
    # leak onto it; sqlite success is otherwise quiet.
    assert r.stdout == "SQLITE-FIXTURE-BYTES\n"
    assert r.stderr == ""
    assert stubs.log_lines() == sqlite_log(
        "mealie", "app=mealie", pod, "/app/data/mealie.db", "mealie"
    )
    # the staged .borgmatic-backup-<name>.db must be gone after the run
    assert not (stubs.pod_fs / "app/data/.borgmatic-backup-mealie.db").exists()


def test_horkos_sqlite(stubs):
    pod = sqlite_stub(stubs, "horkos", "app=horkos", "/data/horkos.db", "horkos")

    r = stubs.run("horkos")
    assert r.returncode == 0, r.stderr
    assert r.stdout == "SQLITE-FIXTURE-BYTES\n"
    assert stubs.log_lines() == sqlite_log(
        "horkos", "app=horkos", pod, "/data/horkos.db", "horkos"
    )


# --- file ferries (navidrome, audiobookshelf) -----------------------------


def test_navidrome_file_newest_wins(stubs):
    pod = "navidrome-pod"
    stubs.write_mapping({"kubectl -n navidrome get pod -l app=navidrome": pod})
    backup_dir = stubs.pod_fs / "data/backup"
    backup_dir.mkdir(parents=True)
    (backup_dir / ".listing").write_text(
        "navidrome_backup_2026.06.18_14.59.15.db\n"
        "stray.txt\n"
        "navidrome_backup_2026.06.19_02.00.00.db\n"
    )
    (backup_dir / "navidrome_backup_2026.06.19_02.00.00.db").write_bytes(
        b"NAVIDROME-DB\n"
    )
    (backup_dir / "navidrome_backup_2026.06.18_14.59.15.db").write_bytes(b"OLDER\n")
    (backup_dir / "stray.txt").write_text("not a backup\n")

    r = stubs.run("navidrome")
    assert r.returncode == 0, r.stderr
    # lexical newest wins; the non-matching stray file is ignored
    assert r.stdout == "NAVIDROME-DB\n"
    assert "borgmatic-dump: navidrome -> navidrome_backup_2026.06.19_02.00.00.db" in (
        r.stderr
    )
    assert stubs.log_lines() == [
        get_pod_line("navidrome", "app=navidrome"),
        f"kubectl -n navidrome exec {pod} -- ls -1 /data/backup",
        f"kubectl -n navidrome exec {pod} -- cat /data/backup/navidrome_backup_2026.06.19_02.00.00.db",
    ]


def test_audiobookshelf_file(stubs):
    pod = "abs-pod"
    stubs.write_mapping(
        {"kubectl -n audiobookshelf get pod -l app=audiobookshelf": pod}
    )
    backups = stubs.pod_fs / "metadata/backups"
    backups.mkdir(parents=True)
    (backups / ".listing").write_text("2026.08.03T0415.audiobookshelf\n")
    (backups / "2026.08.03T0415.audiobookshelf").write_bytes(b"ABS-ZIP\n")

    r = stubs.run("audiobookshelf")
    assert r.returncode == 0, r.stderr
    assert r.stdout == "ABS-ZIP\n"
    assert stubs.log_lines() == [
        get_pod_line("audiobookshelf", "app=audiobookshelf"),
        f"kubectl -n audiobookshelf exec {pod} -- ls -1 /metadata/backups",
        f"kubectl -n audiobookshelf exec {pod} -- cat /metadata/backups/2026.08.03T0415.audiobookshelf",
    ]


def test_file_no_match_aborts(stubs):
    stubs.write_mapping(
        {"kubectl -n audiobookshelf get pod -l app=audiobookshelf": "abs-pod"}
    )
    backups = stubs.pod_fs / "metadata/backups"
    backups.mkdir(parents=True)
    (backups / ".listing").write_text("nothing-matches.txt\n")

    r = stubs.run("audiobookshelf")
    assert r.returncode == 1
    assert r.stdout == ""
    assert "no *.audiobookshelf in /metadata/backups" in r.stderr


# --- pv dumps (pulumi-tail8d86e-state, pulumi-eblu-me-state) --------------


def test_pulumi_tail8d86e_state_pv(stubs):
    pvc = "pulumi-stack-backup"
    pv = "pv-pulumi-stack-backup"
    export_dir = stubs.host_root / "tail8d86e"
    export_dir.mkdir(parents=True)
    (export_dir / "stack_20260618T120000Z.json").write_bytes(b'{"state": 1}\n')
    stubs.write_mapping(
        {
            f"kubectl -n {pvc} get pvc {pvc}": pv,
            f"kubectl get pv {pv}": str(stubs.host_root),
        }
    )

    r = stubs.run("pulumi-tail8d86e-state")
    assert r.returncode == 0, r.stderr
    assert r.stdout == '{"state": 1}\n'
    assert (
        f"borgmatic-dump: pulumi-tail8d86e-state -> stack_20260618T120000Z.json "
        f"(pv:{stubs.host_root})"
    ) in r.stderr
    # pv mode resolves PVC then PV — no pod exec at all
    assert stubs.log_lines() == [
        get_pvc_line(pvc, pvc),
        get_pv_line(pv),
    ]


def test_pulumi_eblu_me_state_pv(stubs):
    pvc = "pulumi-stack-backup"
    pv = "pv-eblu-me"
    export_dir = stubs.host_root / "eblu-me"
    export_dir.mkdir(parents=True)
    (export_dir / "stack_20260617T000000Z.json").write_bytes(b'{"state": 2}\n')
    stubs.write_mapping(
        {
            f"kubectl -n {pvc} get pvc {pvc}": pv,
            f"kubectl get pv {pv}": str(stubs.host_root),
        }
    )

    r = stubs.run("pulumi-eblu-me-state")
    assert r.returncode == 0, r.stderr
    # the subpath is appended to the PV host path, never repeating mountPath
    assert r.stdout == '{"state": 2}\n'
    assert "stack_20260617T000000Z.json" in r.stderr
    assert stubs.log_lines() == [
        get_pvc_line(pvc, pvc),
        get_pv_line(pv),
    ]


def test_pv_missing_export_keeps_previous(stubs):
    export_dir = stubs.host_root / "eblu-me"
    export_dir.mkdir(parents=True)
    (export_dir / "readme.txt").write_text("not an export\n")
    stubs.write_mapping(
        {
            "kubectl -n pulumi-stack-backup get pvc pulumi-stack-backup": "pv-pulumi",
            "kubectl get pv pv-pulumi": str(stubs.host_root),
        }
    )

    r = stubs.run("pulumi-eblu-me-state")
    # no export: contained — exit 0, empty stdout, previous staged export kept
    assert r.returncode == 0
    assert r.stdout == ""
    assert "no stack_*.json in" in r.stderr
    assert "keeping previous staged export" in r.stderr


def test_pv_empty_export_keeps_previous(stubs):
    export_dir = stubs.host_root / "tail8d86e"
    export_dir.mkdir(parents=True)
    (export_dir / "stack_20260618T120000Z.json").write_bytes(b"")
    stubs.write_mapping(
        {
            "kubectl -n pulumi-stack-backup get pvc pulumi-stack-backup": "pv-pulumi",
            "kubectl get pv pv-pulumi": str(stubs.host_root),
        }
    )

    r = stubs.run("pulumi-tail8d86e-state")
    assert r.returncode == 0
    assert r.stdout == ""
    assert "is empty" in r.stderr
    assert "keeping previous staged export" in r.stderr


def test_pv_unbound_pvc_aborts(stubs):
    # get pvc answers an empty volumeName: a real infra error, exit 1
    stubs.write_mapping(
        {"kubectl -n pulumi-stack-backup get pvc pulumi-stack-backup": ""}
    )

    r = stubs.run("pulumi-tail8d86e-state")
    assert r.returncode == 1
    assert "PVC pulumi-stack-backup not bound in pulumi-stack-backup" in r.stderr


def test_pv_pv_without_local_path_aborts(stubs):
    stubs.write_mapping(
        {
            "kubectl -n pulumi-stack-backup get pvc pulumi-stack-backup": "pv-pulumi",
            "kubectl get pv pv-pulumi": "",
        }
    )

    r = stubs.run("pulumi-eblu-me-state")
    assert r.returncode == 1
    assert "PV pv-pulumi has no local.path" in r.stderr


def test_pv_unlistable_subdir_aborts(stubs):
    # The PV root and subpath exist as a directory but ls cannot read it
    # (mode 000, non-root test user): that is a real host error and must
    # abort — not be swallowed into the keep-previous (exit 0) path.
    pv_root = stubs.host_root / "pv-root"
    sub = pv_root / "tail8d86e"
    sub.mkdir(parents=True)
    sub.chmod(0o000)
    stubs.write_mapping(
        {
            "kubectl -n pulumi-stack-backup get pvc pulumi-stack-backup": "pv-pulumi",
            "kubectl get pv pv-pulumi": str(pv_root),
        }
    )
    try:
        r = stubs.run("pulumi-tail8d86e-state")
        assert r.returncode == 1
        assert f"{sub}:" in r.stderr
        assert "keeping previous staged export" not in r.stderr
    finally:
        sub.chmod(0o755)


def test_pv_subpath_missing_keeps_previous(stubs):
    # A subpath that does not exist (or is not a directory) is the ordinary
    # "no export yet" case: exit 0, empty stdout, keep the previous staged
    # export — faithful to the indri helper's `test -d` guard.
    pv_root = stubs.host_root / "pv-root"
    pv_root.mkdir()
    (pv_root / "tail8d86e").write_text("not a dir")
    stubs.write_mapping(
        {
            "kubectl -n pulumi-stack-backup get pvc pulumi-stack-backup": "pv-pulumi",
            "kubectl get pv pv-pulumi": str(pv_root),
        }
    )

    r = stubs.run("pulumi-tail8d86e-state")
    assert r.returncode == 0
    assert r.stdout == ""
    assert "keeping previous staged export" in r.stderr


def test_pv_missing_host_dir_aborts(stubs):
    missing = stubs.host_root / "nope"  # never created on the host
    stubs.write_mapping(
        {
            "kubectl -n pulumi-stack-backup get pvc pulumi-stack-backup": "pv-pulumi",
            "kubectl get pv pv-pulumi": str(missing),
        }
    )

    r = stubs.run("pulumi-tail8d86e-state")
    assert r.returncode == 1
    assert f"{missing} missing on host" in r.stderr


# --- tar dumps (talos-data, paperless-media) ------------------------------


def test_talos_data_tar(stubs):
    pod = "talos-pod"
    stubs.write_mapping({"kubectl -n talos get pod -l app=talos": pod})
    data_dir = stubs.pod_fs / "home/talos/data"
    data_dir.mkdir(parents=True)
    (data_dir / "meta.json").write_text("{}")

    r = stubs.run("talos-data")
    assert r.returncode == 0, r.stderr
    assert stubs.log_lines() == [
        get_pod_line("talos", "app=talos"),
        f"kubectl -n talos exec {pod} -- tar cf - -C /home/talos data",
    ]
    # tar streams real ustar bytes on stdout (first header magic at 257)
    assert len(r.stdout) > 0
    assert r.stdout[257:262] == "ustar"


def test_paperless_media_tar_container(stubs):
    pod = "paperless-pod"
    stubs.write_mapping({"kubectl -n paperless get pod -l app=paperless": pod})
    media_dir = stubs.pod_fs / "usr/src/paperless/media"
    media_dir.mkdir(parents=True)
    (media_dir / "documents").mkdir()

    r = stubs.run("paperless-media")
    assert r.returncode == 0, r.stderr
    assert stubs.log_lines() == [
        get_pod_line("paperless", "app=paperless"),
        f"kubectl -n paperless exec -c web {pod} -- tar cf - -C /usr/src/paperless media",
    ]
    assert len(r.stdout) > 0


# --- fail-loudly guarantees ----------------------------------------------


def test_forgotten_map_fails_loudly(stubs):
    # empty mapping: the get pod call has no key, so the stub must abort and
    # take the whole run down — never a silently green empty dump
    r = stubs.run("mealie")
    assert r.returncode != 0
    assert "k3s stub: no mapping prefix for: kubectl -n mealie get pod" in r.stderr
    # the invocation was still logged before the abort
    assert stubs.log_lines() == [get_pod_line("mealie", "app=mealie")]
