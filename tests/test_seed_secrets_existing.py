"""The `existing` manifest kind of `mise-tasks/seed-secrets`: a declared-existing
host file is verified (presence, owner/group/mode, non-empty for --check) and
never written, repaired or restarted.

All offline: `Host.run` is monkeypatched over an in-memory filesystem, so
nothing sshs and nothing reads the vault.
"""

import hashlib
import importlib.machinery
import importlib.util
import json
import pathlib
import shlex

import pytest
import typer

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load_seed():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "seed_secrets_existing", str(ROOT / "mise-tasks" / "seed-secrets")
    )
    spec = importlib.util.spec_from_loader("seed_secrets_existing", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


seed = _load_seed()

PATH = "/Users/erichblume/.config/borgmatic-test/passphrase"
WRITE_MARKERS = ("cat >", "chown", "chmod", "install -d", "mv -f")


def existing_entry(path=PATH, **over):
    entry = {
        "path": path,
        "kind": "existing",
        "owner": "erichblume",
        "group": "staff",
        "mode": "0600",
    }
    entry.update(over)
    return entry


class FakeFS:
    """{path: (owner, group, mode, content_bytes)} behind a fake `Host.run`."""

    def __init__(self, files):
        self.files = dict(files)
        self.cmds: list[str] = []

    def run(self, host, cmd, input=None):
        self.cmds.append(cmd)
        if cmd.endswith("uname -s"):
            return _proc("Darwin\n")
        if cmd.startswith("ls -A1p"):
            dir_path = shlex.split(cmd)[2]
            names = sorted(
                pathlib.PurePosixPath(p).name
                for p in self.files
                if str(pathlib.PurePosixPath(p).parent) == dir_path
            )
            return _proc("".join(f"{n}\n" for n in names) + "__seed_secrets_ls_ok__\n")
        if cmd.startswith("stat -f"):
            path = shlex.split(cmd)[-1]
            if path in self.files:
                owner, group, mode, _ = self.files[path]
                return _proc(f"{owner} {group} {mode}\n")
            return _proc("", "stat: No such file or directory")
        if cmd.startswith("shasum -a 256"):
            path = shlex.split(cmd)[-1]
            if path in self.files:
                digest = hashlib.sha256(self.files[path][3]).hexdigest()
                return _proc(f"{digest}  {path}\n")
            return _proc("", "No such file or directory")
        return _proc("")


def _proc(stdout="", stderr=""):
    return type("P", (), {"stdout": stdout, "stderr": stderr, "returncode": 0})()


@pytest.fixture
def fake(monkeypatch):
    def install(files):
        fs = FakeFS(files)
        monkeypatch.setattr(
            seed.Host, "run", lambda self, cmd, input=None: fs.run(self, cmd, input)
        )
        return fs

    return install


@pytest.fixture
def manifest(tmp_path):
    def write(entries):
        p = tmp_path / "secrets.json"
        p.write_text(json.dumps({"secrets": entries}))
        return p

    return write


def _host():
    return seed.Host("indri", "Darwin")


def _no_writes(fs):
    assert not [c for c in fs.cmds if any(m in c for m in WRITE_MARKERS)]


# --- load_manifest -----------------------------------------------------------


def test_load_accepts_existing_without_ref(manifest):
    entries = seed.load_manifest(manifest([existing_entry()]), "Darwin")
    assert len(entries) == 1
    assert entries[0]["kind"] == "existing"


def test_load_rejects_existing_with_ref(manifest):
    with pytest.raises(typer.Exit):
        seed.load_manifest(
            manifest([existing_entry(ref="op://vault/item/field")]), "Darwin"
        )


def test_load_rejects_existing_with_restart(manifest):
    with pytest.raises(typer.Exit):
        seed.load_manifest(
            manifest([existing_entry(restart=["mcquack.eblume.x"])]), "Darwin"
        )


def test_load_rejects_existing_with_format(manifest):
    with pytest.raises(typer.Exit):
        seed.load_manifest(manifest([existing_entry(format="X={value}")]), "Darwin")


def test_load_still_rejects_generated_with_ref(manifest):
    entry = existing_entry(kind="generated", ref="op://vault/item/field")
    with pytest.raises(typer.Exit):
        seed.load_manifest(manifest([entry]), "Darwin")


# --- run_apply ---------------------------------------------------------------


def test_apply_present_matching_is_verified_without_writes_or_vault(fake, monkeypatch):
    fs = fake({PATH: ("erichblume", "staff", "0600", b"secret\n")})

    def no_vault(ref):
        raise AssertionError(f"op_read called for existing entry: {ref}")

    monkeypatch.setattr(seed, "op_read", no_vault)
    seed.run_apply(
        _host(), pathlib.Path("secrets.json"), [existing_entry()], dry_run=False
    )
    _no_writes(fs)


def test_apply_absent_fails_without_writes(fake):
    fs = fake({})
    with pytest.raises(typer.Exit) as exc:
        seed.run_apply(
            _host(), pathlib.Path("secrets.json"), [existing_entry()], dry_run=False
        )
    assert exc.value.exit_code == 1
    _no_writes(fs)


def test_apply_mode_drift_fails_without_repair(fake):
    fs = fake({PATH: ("erichblume", "staff", "0644", b"secret\n")})
    with pytest.raises(typer.Exit) as exc:
        seed.run_apply(
            _host(), pathlib.Path("secrets.json"), [existing_entry()], dry_run=False
        )
    assert exc.value.exit_code == 1
    _no_writes(fs)
    assert not [c for c in fs.cmds if "chown" in c or "chmod" in c]


# --- run_check ---------------------------------------------------------------


def test_check_absent_fails(fake, manifest):
    fake({})
    with pytest.raises(typer.Exit) as exc:
        seed.run_check(_host(), manifest([existing_entry()]), [existing_entry()])
    assert exc.value.exit_code == 1


def test_check_present_matching_passes(fake, manifest):
    fake({PATH: ("erichblume", "staff", "0600", b"secret\n")})
    seed.run_check(_host(), manifest([existing_entry()]), [existing_entry()])


def test_apply_empty_content_fails_without_writes(fake):
    fs = fake({PATH: ("erichblume", "staff", "0600", b"")})
    with pytest.raises(typer.Exit) as exc:
        seed.run_apply(
            _host(), pathlib.Path("secrets.json"), [existing_entry()], dry_run=False
        )
    assert exc.value.exit_code == 1
    _no_writes(fs)


def test_check_empty_content_fails(fake, manifest):
    fake({PATH: ("erichblume", "staff", "0600", b"")})
    with pytest.raises(typer.Exit) as exc:
        seed.run_check(_host(), manifest([existing_entry()]), [existing_entry()])
    assert exc.value.exit_code == 1
