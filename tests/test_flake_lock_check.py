"""flake-lock-check: the deterministic battery for ringtail flake-lock PRs.

The script is bash + jq + curl + git + nix; these tests drive it as a
subprocess with FLAKELOCK_CURL/FLAKELOCK_NIX/FLAKELOCK_GIT pointed at tiny
bash stubs, so nothing here touches a network or a nix store. The stubs read
canned data from per-test JSON files (env-named, no PATH fiddling); a curl
stub key "__exit__" models a network failure.

Fixtures are the real old/new locks of eblume/blumeops@576cc2a9 (the weekly
nixpkgs + home-manager update, where disko and nixpkgs-services did not
move). Tampered variants are rewritten at test time, never checked in.
"""

import itertools
import json
import os
import pathlib
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "nixos" / "ringtail" / "flake-lock-check"
FIX = ROOT / "tests" / "fixtures" / "flake-lock-check"
OLD = FIX / "old.lock"
NEW = FIX / "new.lock"
HEADS = FIX / "heads.json"

AHEAD = {"status": "ahead", "ahead_by": 1, "behind_by": 0}

CURL_STUB = """\
#!/usr/bin/env bash
set -u
mapping="${CURL_STUB_RESPONSES:?}"
out=""
i=0
args=("$@")
while (( i < ${#args[@]} )); do
  [[ "${args[$i]}" == "-o" ]] && out="${args[$((i+1))]}"
  (( i += 1 ))
done
url="${args[${#args[@]}-1]}"
if [[ -s "$mapping" ]]; then
  exit_code="$(jq -r '."__exit__" // 0' "$mapping")"
else
  exit_code="0"
fi
[[ "$exit_code" != "0" ]] && exit "$exit_code"
match="$(jq -c --arg u "$url" 'del(."__exit__") | to_entries[] | . as $e | select($u | contains($e.key)) | $e.value' "$mapping" 2>/dev/null | head -n 1)"
if [[ -z "${match:-}" || "$match" == "null" ]]; then
  # A forgotten map must fail the test, not silently green the check.
  code="404"
  body=""
else
  code="$(printf '%s' "$match" | jq -r '.code // 200')"
  body="$(printf '%s' "$match" | jq -r '.body // empty')"
fi
[[ -n "$out" ]] && printf '%s' "$body" > "$out"
printf '%s' "$code"
"""

NIX_STUB = """\
#!/usr/bin/env bash
set -u
sris="${NIX_STUB_SRIS:?}"
if [[ "${1:-}" == flake && "${2:-}" == metadata && "${3:-}" == --json ]]; then
  rev="${4:?}"
  rev="${rev##*/}"
  printf '{"path":"/nix/store/fake-%s-source"}\\n' "${rev:0:7}"
  exit 0
fi
if [[ "${1:-}" == hash && "${2:-}" == path && "${3:-}" == --sri ]]; then
  path="${4:?}"
  name="${path##*/}"
  prefix="${name#fake-}"
  prefix="${prefix%-source}"
  sri="$(jq -r --arg p "$prefix" '.[$p] // empty' "$sris")"
  [[ -n "$sri" ]] || { echo "nix stub: no SRI for $prefix" >&2; exit 1; }
  printf '%s' "$sri"
  exit 0
fi
echo "nix stub: unexpected args: $*" >&2
exit 1
"""

GIT_STUB = """\
#!/usr/bin/env bash
set -u
map="${GIT_STUB_LSREMOTE:?}"
[[ "${1:-}" == ls-remote ]] || { echo "git stub: expected ls-remote" >&2; exit 1; }
ref="${3:?}"
sha="$(jq -r --arg r "$ref" '.[$r] // empty' "$map")"
[[ -n "$sha" ]] || { echo "git stub: no rev for $ref" >&2; exit 1; }
printf '%s\\t%s\\n' "$sha" "$ref"
"""


class Stubs:
    """Stub executables + per-test canned data, env-named explicitly."""

    def __init__(self, tmp_path: pathlib.Path):
        bin = tmp_path / "bin"
        bin.mkdir()
        self.responses = tmp_path / "curl-responses.json"
        self.sris = tmp_path / "nix-sris.json"
        self.lsremote = tmp_path / "git-lsremote.json"
        self.curl = bin / "curl"
        self.nix = bin / "nix"
        self.git = bin / "git"
        for path, body in (
            (self.curl, CURL_STUB),
            (self.nix, NIX_STUB),
            (self.git, GIT_STUB),
        ):
            path.write_text(body, encoding="utf-8")
            path.chmod(0o755)

    def env(self, **extra) -> dict[str, str]:
        env = dict(os.environ)
        env.update(
            FLAKELOCK_CURL=str(self.curl),
            FLAKELOCK_NIX=str(self.nix),
            FLAKELOCK_GIT=str(self.git),
            CURL_STUB_RESPONSES=str(self.responses),
            NIX_STUB_SRIS=str(self.sris),
            GIT_STUB_LSREMOTE=str(self.lsremote),
        )
        env.update(extra)
        return env

    def run(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(
            [str(SCRIPT), *args],
            env=self.env(),
            capture_output=True,
            text=True,
            check=False,
        )

    def write_curl(self, mapping: dict) -> None:
        self.responses.write_text(json.dumps(mapping), encoding="utf-8")


@pytest.fixture
def stubs(tmp_path):
    return Stubs(tmp_path)


def lock_data(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def green_mapping(stubs: Stubs, new: pathlib.Path = NEW) -> tuple[dict, dict]:
    """Canned curl compare + nix nar responses the green run expects."""
    data = lock_data(new)
    curl = {}
    sris = {}
    for name in ("nixpkgs", "home-manager"):
        node = data["nodes"][name]
        original = node["original"]
        curl[f"{original['owner']}/{original['repo']}"] = {"body": AHEAD}
        sris[node["locked"]["rev"][:7]] = node["locked"]["narHash"]
    return curl, sris


_tamper_seq = itertools.count()


def tampered(
    tmp_path: pathlib.Path, lock: pathlib.Path, **changes: object
) -> pathlib.Path:
    """Copy of a lock with dotted paths rewritten, e.g. version=6."""
    data = lock_data(lock)
    for dotted, value in changes.items():
        node = data
        *parts, leaf = dotted.split(".")
        for part in parts:
            node = node[part]
        node[leaf] = value
    out = tmp_path / f"tampered-{next(_tamper_seq)}.lock"
    out.write_text(json.dumps(data), encoding="utf-8")
    return out


def test_green(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")

    r = stubs.run("check", str(OLD), str(NEW), "--heads", str(HEADS))
    assert r.returncode == 0, r.stdout + r.stderr
    for check in ("scope", "originals", "ff-head", "ff-ancestor", "nar-hash"):
        assert f"PASS {check}" in r.stdout
    assert "RESULT: PASS (5/5 checks)" in r.stdout


def test_check_json_mode(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")

    r = stubs.run("check", str(OLD), str(NEW), "--heads", str(HEADS), "--json")
    assert r.returncode == 0, r.stdout + r.stderr
    payload = json.loads(r.stdout)
    assert [c["name"] for c in payload["checks"]] == [
        "scope",
        "originals",
        "ff-head",
        "ff-ancestor",
        "nar-hash",
    ]
    assert all(c["status"] == "PASS" and c["detail"] == "" for c in payload["checks"])
    assert "PASS scope" in r.stderr  # human lines go to stderr in json mode


def test_scope_catches_pinned_rev_move(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")
    new = tampered(tmp_path, NEW, **{"nodes.nixpkgs-services.locked.rev": "9" * 40})

    r = stubs.run("check", str(OLD), str(new), "--heads", str(HEADS))
    assert r.returncode == 1
    assert "FAIL scope" in r.stdout
    assert "nixpkgs-services: node object not identical" in r.stdout


def test_scope_catches_extra_node(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")
    data = lock_data(NEW)
    data["nodes"]["evil"] = {"inputs": {}, "locked": None, "original": None}
    extra = tmp_path / "extra.lock"
    extra.write_text(json.dumps(data), encoding="utf-8")

    r = stubs.run("check", str(OLD), str(extra), "--heads", str(HEADS))
    assert r.returncode == 1
    assert "FAIL scope" in r.stdout
    assert "node set differs" in r.stdout


def test_scope_catches_locked_owner_change(stubs, tmp_path):
    # A moved input may change only rev/narHash/lastModified in locked.
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")
    new = tampered(tmp_path, NEW, **{"nodes.nixpkgs.locked.owner": "evil-corp"})

    r = stubs.run("check", str(OLD), str(new), "--heads", str(HEADS))
    assert r.returncode == 1
    assert "FAIL scope" in r.stdout
    assert "locked differs beyond rev/narHash/lastModified" in r.stdout


def test_ff_head_fails_closed_without_heads_file(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")

    r = stubs.run("check", str(OLD), str(NEW))
    assert r.returncode == 1
    assert "FAIL ff-head" in r.stdout
    assert "no --heads file" in r.stdout


def test_ff_head_fails_closed_on_invalid_heads_json(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")
    heads = tmp_path / "heads.json"
    heads.write_text("not json", encoding="utf-8")

    r = stubs.run("check", str(OLD), str(NEW), "--heads", str(heads))
    assert r.returncode == 1
    assert "FAIL ff-head" in r.stdout
    assert "not valid JSON" in r.stdout


def test_originals_catches_redirect(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")
    new = tampered(tmp_path, NEW, **{"nodes.home-manager.original.owner": "evil-corp"})

    r = stubs.run("check", str(OLD), str(new), "--heads", str(HEADS))
    assert r.returncode == 1
    # Overlaps scope by design; the precise "input redirected" failure is originals.
    assert "FAIL scope" in r.stdout
    assert "FAIL originals" in r.stdout
    assert "home-manager: original.owner changed" in r.stdout


def test_ff_ancestor_catches_diverged(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    for key in curl:
        curl[key] = {"body": {"status": "diverged", "ahead_by": 2, "behind_by": 1}}
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")

    r = stubs.run("check", str(OLD), str(NEW), "--heads", str(HEADS))
    assert r.returncode == 1
    assert "FAIL ff-ancestor" in r.stdout
    assert "not a strict fast-forward" in r.stdout


def test_ff_head_catches_wrong_head(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")
    heads = tmp_path / "heads.json"
    heads.write_text(
        json.dumps(
            {
                "nixpkgs": {"head": "0" * 40},
                "home-manager": {"head": "a6631107a83ceab5872f298a2ea710859c80c4cb"},
            }
        ),
        encoding="utf-8",
    )

    r = stubs.run("check", str(OLD), str(NEW), "--heads", str(heads))
    assert r.returncode == 1
    assert "FAIL ff-head" in r.stdout
    assert (
        "recorded head 0000000000000000000000000000000000000000 != new rev" in r.stdout
    )


def test_ff_head_catches_missing_entry(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")
    heads = tmp_path / "heads.json"
    heads.write_text(
        json.dumps({"nixpkgs": {"head": "cf5e76507c6e23b59f7e0ffcc7baa2a39ddd8442"}}),
        encoding="utf-8",
    )

    r = stubs.run("check", str(OLD), str(NEW), "--heads", str(heads))
    assert r.returncode == 1
    assert "FAIL ff-head" in r.stdout
    assert "home-manager: no recorded head (missing entry)" in r.stdout


def test_nar_hash_catches_sri_mismatch(stubs, tmp_path):
    curl, sris = green_mapping(stubs)
    stubs.write_curl(curl)
    sris["cf5e765"] = "sha256-" + "A" * 43 + "="
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")

    r = stubs.run("check", str(OLD), str(NEW), "--heads", str(HEADS))
    assert r.returncode == 1
    assert "FAIL nar-hash" in r.stdout
    assert "!= fetched" in r.stdout


def test_ff_ancestor_fails_closed_on_network_error(stubs, tmp_path):
    # A flaky network must never produce green: model with a curl exit code.
    stubs.write_curl({"__exit__": 60})
    _, sris = green_mapping(stubs)
    stubs.sris.write_text(json.dumps(sris), encoding="utf-8")

    r = stubs.run("check", str(OLD), str(NEW), "--heads", str(HEADS))
    assert r.returncode == 1
    assert "FAIL ff-ancestor" in r.stdout
    assert "compare API unreachable" in r.stdout
    assert "RESULT: FAIL (1 failed: ff-ancestor)" in r.stdout


def test_usage_errors(stubs, tmp_path):
    r = stubs.run("check", str(OLD))  # missing NEW_LOCK
    assert r.returncode == 2

    garbage = tmp_path / "garbage.lock"
    garbage.write_text("this is not json", encoding="utf-8")
    r = stubs.run("check", str(OLD), str(garbage))
    assert r.returncode == 2

    r = stubs.run("check", str(OLD), str(tampered(tmp_path, NEW, version=6)))
    assert r.returncode == 2

    r = stubs.run("nonesuch")
    assert r.returncode == 2


def test_record_heads(stubs, tmp_path):
    stubs.lsremote.write_text(
        json.dumps(
            {
                "refs/heads/nixos-26.05": "cf5e76507c6e23b59f7e0ffcc7baa2a39ddd8442",
                "refs/heads/release-26.05": "a6631107a83ceab5872f298a2ea710859c80c4cb",
                "HEAD": "725ea35e410ad83be4931d1bff7e090eacaf3563",
            }
        ),
        encoding="utf-8",
    )
    out = tmp_path / "heads.json"

    r = stubs.run("record-heads", str(NEW), "--out", str(out))
    assert r.returncode == 0, r.stdout + r.stderr
    recorded = json.loads(out.read_text(encoding="utf-8"))
    assert set(recorded) == {"nixpkgs", "home-manager", "disko"}
    for name, owner, repo, branch, head in (
        (
            "nixpkgs",
            "NixOS",
            "nixpkgs",
            "nixos-26.05",
            "cf5e76507c6e23b59f7e0ffcc7baa2a39ddd8442",
        ),
        (
            "home-manager",
            "nix-community",
            "home-manager",
            "release-26.05",
            "a6631107a83ceab5872f298a2ea710859c80c4cb",
        ),
        (
            "disko",
            "nix-community",
            "disko",
            "HEAD",
            "725ea35e410ad83be4931d1bff7e090eacaf3563",
        ),
    ):
        entry = recorded[name]
        assert entry["owner"] == owner
        assert entry["repo"] == repo
        assert entry["branch"] == branch
        assert entry["head"] == head
        assert isinstance(entry["recorded_at"], int)
    stamp = recorded["nixpkgs"]["recorded_at"]
    assert recorded["home-manager"]["recorded_at"] == stamp
    assert recorded["disko"]["recorded_at"] == stamp


def test_record_heads_ls_remote_failure_no_partial_output(stubs, tmp_path):
    # No canned rev for home-manager: git stub exits 1 on the second call.
    stubs.lsremote.write_text(
        json.dumps(
            {"refs/heads/nixos-26.05": "cf5e76507c6e23b59f7e0ffcc7baa2a39ddd8442"}
        ),
        encoding="utf-8",
    )
    out = tmp_path / "heads.json"

    r = stubs.run("record-heads", str(NEW), "--out", str(out))
    assert r.returncode == 2
    assert not out.exists()  # no partial output


def test_kernel_version(stubs, tmp_path):
    top = tmp_path / "toplevel"
    top.mkdir()
    target = top / "linux-6.12.44-dirty"
    target.write_text("x", encoding="utf-8")
    (top / "kernel").symlink_to(target)

    r = stubs.run("kernel-version", str(top))
    assert r.returncode == 0
    assert r.stdout == "6.12.44\n"


def test_kernel_version_missing(stubs, tmp_path):
    empty = tmp_path / "empty"
    empty.mkdir()

    r = stubs.run("kernel-version", str(empty))
    assert r.returncode == 2
