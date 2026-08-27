"""--script mode: the one-off script travels as the (script, script_sha256)
input pair, and horkos binds the pair at filing time (hash must match the
body) so the warrant freezes exactly what the approver read.

`load_script` is the whole client-side decision: where the body comes from,
what makes the pair ambiguous, and the digest the pair must carry.
"""

import hashlib
import importlib.machinery
import importlib.util
import pathlib

import pytest
import typer

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load_request_run():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "request_run", str(ROOT / "mise-tasks" / "request-run")
    )
    spec = importlib.util.spec_from_loader("request_run", loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


request_run = _load_request_run()
FIXTURE = ROOT / "tests" / "_script_fixture.sh"
SCRIPT_BODY = FIXTURE.read_text(encoding="utf-8")


def _inputs_from(pairs: list[str]) -> dict[str, str]:
    return dict(p.split("=", 1) for p in pairs)


def test_digest_matches_horkos_expectation():
    """The pair must hash the way horkos re-hashes it: sha256 of the utf-8
    body, hex."""
    pairs = request_run.load_script(str(FIXTURE), "run-script.yaml", [])
    script, digest = _inputs_from(pairs)["script"], _inputs_from(pairs)["script_sha256"]
    assert script == FIXTURE.read_text(encoding="utf-8")
    assert digest == hashlib.sha256(script.encode("utf-8")).hexdigest()


def test_reads_the_file_body():
    pairs = request_run.load_script(str(FIXTURE), "run-script.yaml", [])
    script, digest = _inputs_from(pairs).values()
    assert script == SCRIPT_BODY
    assert digest == hashlib.sha256(SCRIPT_BODY.encode("utf-8")).hexdigest()


def test_reads_stdin_when_dash(monkeypatch):
    import io
    import sys

    monkeypatch.setattr(sys, "stdin", io.StringIO(SCRIPT_BODY))
    pairs = request_run.load_script("-", "run-script.yaml", [])
    assert _inputs_from(pairs)["script"] == SCRIPT_BODY


def test_refused_for_other_workflows():
    with pytest.raises(typer.Exit):
        request_run.load_script("-x", "build-container.yaml", [])


def test_refused_when_pair_already_given_as_inputs():
    for dup in ("script=x", "script_sha256=" + "a" * 64):
        with pytest.raises(typer.Exit):
            request_run.load_script("-x", "run-script.yaml", [dup])


def test_missing_file_refused():
    with pytest.raises(typer.Exit):
        request_run.load_script("/nonexistent/script-xyz.sh", "run-script.yaml", [])


def test_empty_body_refused(tmp_path):
    empty = tmp_path / "empty.sh"
    empty.write_text("", encoding="utf-8")
    with pytest.raises(typer.Exit):
        request_run.load_script(str(empty), "run-script.yaml", [])


def test_non_utf8_body_refused(tmp_path):
    binary = tmp_path / "bin.sh"
    binary.write_bytes(b"\xff\xfe\x00echo")
    with pytest.raises(typer.Exit):
        request_run.load_script(str(binary), "run-script.yaml", [])
