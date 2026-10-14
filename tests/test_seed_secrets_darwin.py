"""The darwin write/restart legs of `mise-tasks/seed-secrets`
(eblume/blumeops#1528): a non-empty darwin manifest must load (restart
entries are launchd labels), `Host.restart` must kickstart and confirm in
the gui domain, and `main` must dispatch a non-empty darwin manifest to the
check/apply path instead of refusing it.

All offline: `Host.run` is monkeypatched, so nothing sshs and nothing reads
the vault.
"""

import importlib.machinery
import importlib.util
import json
import pathlib
from types import SimpleNamespace

import pytest
import typer

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load_seed():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "seed_secrets_darwin", str(ROOT / "mise-tasks" / "seed-secrets")
    )
    spec = importlib.util.spec_from_loader("seed_secrets_darwin", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


seed = _load_seed()


def _op_entry(path: str, restart: list[str] | None = None) -> dict:
    return {
        "path": path,
        "kind": "op",
        "ref": "op://vault/item/field",
        "owner": "erichblume",
        "group": "staff",
        "mode": "0600",
        **({"restart": restart} if restart is not None else {}),
    }


def _write_manifest(tmp_path, entries: list[dict]) -> pathlib.Path:
    manifest = tmp_path / "secrets.json"
    manifest.write_text(json.dumps({"secrets": entries}), encoding="utf-8")
    return manifest


def test_darwin_manifest_with_entries_and_restart_labels_is_accepted(tmp_path):
    manifest = _write_manifest(
        tmp_path,
        [
            _op_entry(
                "/Users/erichblume/forgejo-runner/identity/token",
                ["mcquack.eblume.forgejo-runner"],
            ),
            _op_entry(
                "/Users/erichblume/forgejo-runner/identity/mise-github-token",
                ["mcquack.eblume.forgejo-runner"],
            ),
        ],
    )
    entries = seed.load_manifest(manifest, "Darwin")
    assert len(entries) == 2


def test_darwin_restart_entry_must_be_launchd_label(tmp_path):
    # a systemd template unit (@) can't be a launchd label: LABEL_RE allows
    # only [A-Za-z0-9._:-]
    manifest = _write_manifest(
        tmp_path,
        [
            _op_entry(
                "/Users/erichblume/forgejo-runner/identity/token",
                ["forgejo-runner@main.service"],
            )
        ],
    )
    with pytest.raises(typer.Exit):
        seed.load_manifest(manifest, "Darwin")


class _FakeRun:
    """Records every command `Host.run` is asked for; the route gate's probe
    (a command whose text ends with `uname -s`) must answer the declared OS or
    `Host.os()` returns None, so that one command is answered with the OS name
    and everything else gets `stdout`."""

    def __init__(self, os_name: str, stdout: str):
        self.calls: list[str] = []
        self.os_name = os_name
        self.stdout = stdout

    def __call__(self, cmd, input=None):
        self.calls.append(cmd)
        response = self.os_name if cmd.endswith("uname -s") else self.stdout
        return SimpleNamespace(stdout=response, returncode=0)


def test_restart_darwin_kicks_and_confirms(monkeypatch):
    host = seed.Host("indri", "Darwin")
    fake = _FakeRun("Darwin", "seed-secrets state: running\n")
    monkeypatch.setattr(host, "run", fake)
    assert host.restart(["mcquack.eblume.forgejo-runner"], "erichblume") is None
    (kick,) = [c for c in fake.calls if "launchctl kickstart" in c]
    assert kick.startswith("uid=$(id -u erichblume) && ")
    assert "launchctl kickstart -k gui/$uid/mcquack.eblume.forgejo-runner" in kick
    assert "launchctl print gui/$uid/mcquack.eblume.forgejo-runner" in kick


def test_restart_darwin_reports_unloaded_label(monkeypatch):
    host = seed.Host("indri", "Darwin")
    fake = _FakeRun("Darwin", "seed-secrets state: none\n")
    monkeypatch.setattr(host, "run", fake)
    result = host.restart(["mcquack.eblume.forgejo-runner"], "erichblume")
    assert result is not None
    assert "gui domain" in result


def test_restart_darwin_reports_wrong_state(monkeypatch):
    host = seed.Host("indri", "Darwin")
    fake = _FakeRun("Darwin", "seed-secrets state: exiting\n")
    monkeypatch.setattr(host, "run", fake)
    result = host.restart(["mcquack.eblume.forgejo-runner"], "erichblume")
    assert result is not None
    assert "exiting" in result


def test_restart_linux_path_unchanged(monkeypatch):
    host = seed.Host("ringtail", "Linux")
    fake = _FakeRun("Linux", "active\n")
    monkeypatch.setattr(host, "run", fake)
    assert host.restart(["forgejo-runner.service"], "root") is None
    assert any("systemctl restart forgejo-runner.service" in c for c in fake.calls)
    assert any("systemctl is-active forgejo-runner.service" in c for c in fake.calls)


def test_main_dispatch_accepts_nonempty_darwin_manifest(tmp_path, monkeypatch, capsys):
    manifest = _write_manifest(
        tmp_path,
        [
            _op_entry(
                "/Users/erichblume/forgejo-runner/identity/token",
                ["mcquack.eblume.forgejo-runner"],
            )
        ],
    )
    monkeypatch.setattr(seed, "HOSTS", {"indri": ("indri", manifest, "Darwin")})

    constructed = []

    class _DummyHost:
        def __init__(self, target, os_name, local=False):
            constructed.append((target, os_name, local))

    monkeypatch.setattr(seed, "Host", _DummyHost)

    called = []

    def fake_run_check(host_obj, manifest_path, entries):
        called.append((host_obj, manifest_path, entries))

    monkeypatch.setattr(seed, "run_check", fake_run_check)

    seed.main("indri", check=True, dry_run=False, only=None, local=False)

    err = capsys.readouterr().err
    assert "not implemented" not in err
    assert constructed == [("indri", "Darwin", False)]
    assert called, (
        "run_check was never reached — a non-empty darwin manifest was refused"
    )


def test_main_dispatch_accepts_nonempty_darwin_manifest_apply(
    tmp_path, monkeypatch, capsys
):
    manifest = _write_manifest(
        tmp_path,
        [
            _op_entry(
                "/Users/erichblume/forgejo-runner/identity/token",
                ["mcquack.eblume.forgejo-runner"],
            )
        ],
    )
    monkeypatch.setattr(seed, "HOSTS", {"indri": ("indri", manifest, "Darwin")})

    constructed = []

    class _DummyHost:
        def __init__(self, target, os_name, local=False):
            constructed.append((target, os_name, local))

    monkeypatch.setattr(seed, "Host", _DummyHost)

    called = []

    def fake_run_apply(host_obj, manifest_path, entries, dry_run):
        called.append((host_obj, manifest_path, entries, dry_run))

    monkeypatch.setattr(seed, "run_apply", fake_run_apply)

    seed.main("indri", check=False, dry_run=True, only=None, local=False)

    err = capsys.readouterr().err
    assert "not implemented" not in err
    assert constructed == [("indri", "Darwin", False)]
    assert called, (
        "run_apply was never reached — a non-empty darwin manifest was refused"
    )
    assert called[0][2] is not None  # the manifest's entries reached the apply path


def test_restart_darwin_accepts_spawn_scheduled(monkeypatch):
    host = seed.Host("indri", "Darwin")
    fake = _FakeRun("Darwin", "seed-secrets state: spawn scheduled\n")
    monkeypatch.setattr(host, "run", fake)
    assert host.restart(["mcquack.eblume.forgejo-runner"], "erichblume") is None
    (kick,) = [c for c in fake.calls if "launchctl kickstart" in c]
    # the retry loop: transient states wait, terminal states break out
    assert (
        'case "$state" in ""|waiting|"spawn scheduled") sleep 1;; *) break;; esac;'
        in kick
    )
    assert 'echo "seed-secrets state: ${state:-none}"' in kick


def test_restart_darwin_rejects_root_owner_at_load(tmp_path):
    manifest = _write_manifest(
        tmp_path,
        [
            _op_entry(
                "/Users/erichblume/forgejo-runner/identity/token",
                ["mcquack.eblume.forgejo-runner"],
            )
        ],
    )
    json_data = json.loads(manifest.read_text())
    json_data["secrets"][0]["owner"] = "root"
    manifest.write_text(json.dumps(json_data), encoding="utf-8")
    with pytest.raises(typer.Exit):
        seed.load_manifest(manifest, "Darwin")


def test_restart_darwin_ignores_root_owner_on_linux(tmp_path):
    # the root-owner rule is darwin-only: linux units are system units,
    # restarted as root by design
    manifest = _write_manifest(
        tmp_path,
        [
            {
                "path": "/etc/forgejo-runner/priv.env",
                "kind": "op",
                "ref": "op://vault/item/field",
                "owner": "root",
                "group": "root",
                "mode": "0600",
                "restart": ["forgejo-runner.service"],
            }
        ],
    )
    entries = seed.load_manifest(manifest, "Linux")
    assert entries[0]["restart"] == ["forgejo-runner.service"]


def test_restart_darwin_refuses_root_uid(monkeypatch):
    host = seed.Host("indri", "Darwin")
    fake = _FakeRun("Darwin", "")
    monkeypatch.setattr(host, "run", fake)
    result = host.restart(["mcquack.eblume.forgejo-runner"], "root")
    assert result is not None
    assert "non-root" in result
    (cmd,) = [c for c in fake.calls if "launchctl" in c]
    # the uid guard short-circuits the kickstart when the owner resolves to
    # root, so the label is never actually kicked on the host
    assert '[ "$uid" -ne 0 ] && { launchctl kickstart' in cmd


def test_apply_dedupes_shared_restart_labels(tmp_path, monkeypatch):
    # two files share one label: the label is kicked once, after both files
    # are seated and read back
    entries = [
        _op_entry(
            "/Users/erichblume/forgejo-runner/identity/token",
            ["mcquack.eblume.forgejo-runner"],
        ),
        _op_entry(
            "/Users/erichblume/forgejo-runner/identity/mise-github-token",
            ["mcquack.eblume.forgejo-runner"],
        ),
    ]
    manifest = _write_manifest(tmp_path, entries)
    monkeypatch.setattr(seed, "op_read", lambda ref: "value")
    monkeypatch.setattr(seed, "read_back", lambda *a, **k: None)

    restarts = []

    class _DummyHost:
        def __init__(self, target, os_name, local=False):
            self.local = local
            self.target = target

        def probe(self, path):
            return "absent", ""

        def stat(self, path):
            return None

        def write(self, *a, **k):
            return True

        def restart(self, units, owner):
            restarts.append((units, owner))

    seed.run_apply(_DummyHost("indri", "Darwin"), manifest, entries, dry_run=False)
    assert restarts == [(["mcquack.eblume.forgejo-runner"], "erichblume")]


def test_restart_darwin_executes_the_one_liner(tmp_path, monkeypatch):
    # behavioral: execute the generated remote command in a local sh with fake
    # id/launchctl on PATH, pinning the guard, the marker, and the retry loop
    import os as _os
    import subprocess as _subprocess

    label = "mcquack.eblume.forgejo-runner"
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    state_file = tmp_path / "state"
    seen = tmp_path / "seen"
    (bin_dir / "id").write_text(
        "#!/bin/sh\n"
        'case "$1" in -u) u="$2";; esac\n'
        'case "$u" in erichblume) echo 501;; root) echo 0;; *) echo "id: unknown user" >&2; exit 1;; esac\n'
    )
    # print stub: a two-line state file reports line 1 (the transient state)
    # until the first print, then line 2 — simulating an async spawn
    (bin_dir / "launchctl").write_text(
        f"""#!/bin/sh
if [ "$1" = "kickstart" ]; then exit ${{KICK:-0}}; fi
if [ "$1" != "print" ]; then exit 1; fi
if [ ! -f '{state_file}' ]; then echo 'Could not find service: 2' >&2; exit 2; fi
if [ -f '{seen}' ] || [ "$(wc -l < '{state_file}')" -lt 2 ]; then s=$(tail -n1 '{state_file}'); else s=$(head -n1 '{state_file}'); fi
touch '{seen}'
printf 'label = {{\\n\\tstate = %s\\n}}\\n' "$s"
"""
    )
    bin_dir.joinpath("id").chmod(0o755)
    bin_dir.joinpath("launchctl").chmod(0o755)

    def generated_cmd(owner):
        host = seed.Host("indri", "Darwin")
        calls = []
        monkeypatch.setattr(
            host,
            "run",
            lambda cmd, input=None: (
                calls.append(cmd),
                SimpleNamespace(stdout="", returncode=0),
            )[1],
        )
        host._os_ok = True
        host.restart([label], owner)
        return calls[0]

    def run_cmd(cmd, **env_extra):
        env = dict(_os.environ)
        env["PATH"] = f"{bin_dir}:{env['PATH']}"
        env.update(env_extra)
        seen.unlink(missing_ok=True)
        return _subprocess.run(
            ["sh", "-c", cmd],
            capture_output=True,
            text=True,
            timeout=60,
            env=env,
            check=False,
        )

    # transient spawn scheduled, then running: the loop waits once and accepts
    state_file.write_text("spawn scheduled\nrunning\n")
    out = run_cmd(generated_cmd("erichblume"))
    assert out.stdout.strip() == "seed-secrets state: running"
    # a stuck transient state is accepted (spawn still in flight is fine)
    state_file.write_text("spawn scheduled\n")
    out = run_cmd(generated_cmd("erichblume"))
    assert out.stdout.strip() == "seed-secrets state: spawn scheduled"
    # a dead state is reported verbatim
    state_file.write_text("exited\n")
    out = run_cmd(generated_cmd("erichblume"))
    assert out.stdout.strip() == "seed-secrets state: exited"
    # an unloaded label: print fails, every read is empty -> none
    state_file.unlink()
    out = run_cmd(generated_cmd("erichblume"))
    assert out.stdout.strip() == "seed-secrets state: none"
    # kickstart itself failing is reported, not papered over by a live print
    state_file.write_text("running\n")
    out = run_cmd(generated_cmd("erichblume"), KICK="1")
    assert out.stdout.strip() == "seed-secrets state: kickstart-failed"
    # a root owner: the guard short-circuits, so there is no marker at all
    out = run_cmd(generated_cmd("root"))
    assert "seed-secrets state:" not in out.stdout
