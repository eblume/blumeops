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
    """Records every command `Host.run` is asked for; the route probe's
    `uname -s` must answer the declared OS or `Host.os()` returns None, so
    that one command is special-cased and everything else gets `stdout`."""

    def __init__(self, os_name: str, stdout: str):
        self.calls: list[str] = []
        self.os_name = os_name
        self.stdout = stdout

    def __call__(self, cmd, input=None):
        self.calls.append(cmd)
        response = self.os_name if cmd == "uname -s" else self.stdout
        return SimpleNamespace(stdout=response, returncode=0)


def test_restart_darwin_kicks_and_confirms(monkeypatch):
    host = seed.Host("indri", "Darwin")
    fake = _FakeRun(
        "Darwin", "mcquack.eblume.forgejo-runner = {\n  state = running\n}\n"
    )
    monkeypatch.setattr(host, "run", fake)
    assert host.restart(["mcquack.eblume.forgejo-runner"], "erichblume") is None
    (kick,) = [c for c in fake.calls if "launchctl kickstart" in c]
    assert kick.startswith("uid=$(id -u erichblume) && ")
    assert "launchctl kickstart -k gui/$uid/mcquack.eblume.forgejo-runner" in kick
    assert "launchctl print gui/$uid/mcquack.eblume.forgejo-runner" in kick


def test_restart_darwin_reports_unloaded_label(monkeypatch):
    host = seed.Host("indri", "Darwin")
    fake = _FakeRun("Darwin", "")
    monkeypatch.setattr(host, "run", fake)
    result = host.restart(["mcquack.eblume.forgejo-runner"], "erichblume")
    assert result is not None
    assert "gui domain" in result


def test_restart_darwin_reports_wrong_state(monkeypatch):
    host = seed.Host("indri", "Darwin")
    fake = _FakeRun("Darwin", "state = exiting\n")
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
