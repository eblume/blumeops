"""The `auto` class of warrant-policy.yaml is refused by request-run.

Class `auto` actions are event-triggered on push to main: the merge commit
is the approval, no warrant is minted, and nothing is requestable. request-run
must refuse them exactly as it refuses `deny`, before any input schema or
SHA-binding logic runs (docs/explanation/auto-apply.md).
"""

import importlib.machinery
import importlib.util
import pathlib

import pytest
import typer
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHA = "b" * 40


def _load_request_run():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "request_run", str(ROOT / "mise-tasks" / "request-run")
    )
    spec = importlib.util.spec_from_loader("request_run", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


request_run = _load_request_run()
POLICY = (ROOT / "warrant-policy.yaml").read_text()
ACTIONS = yaml.safe_load(POLICY)["actions"]
AUTO_ACTIONS = sorted(
    name for name, entry in ACTIONS.items() if entry.get("class") == "auto"
)


class _RawResponse:
    def __init__(self, status_code: int, text: str) -> None:
        self.status_code = status_code
        self.text = text


class PolicyClient:
    """Canned responses for enforce_policy's raw fetches, keyed
    (ref, path)."""

    def __init__(self, files: dict):
        self.files = files

    def get(self, url: str):
        suffix = url.split("/raw/", 1)[1]
        ref, _, path = suffix.partition("/")
        text = self.files.get((ref, path))
        return _RawResponse(200 if text is not None else 404, text or "")


class _ErrRecorder:
    """Stands in for request_run.err — collect what would be printed to
    stderr (the shape the rest of the suite uses for `err`)."""

    def __init__(self):
        self.lines = []

    def print(self, *args, **kwargs):
        self.lines.append(" ".join(str(a) for a in args))


def _policy_with(entry: str) -> str:
    return f"actions:\n{entry}"


def _enforce(client: PolicyClient, workflow: str, monkeypatch) -> str:
    """Run enforce_policy, swallowing the typer.Exit; return the stderr."""
    rec = _ErrRecorder()
    monkeypatch.setattr(request_run, "err", rec)
    with pytest.raises(typer.Exit):
        request_run.enforce_policy(client, workflow, {}, SHA)
    return "\n".join(rec.lines)


def test_auto_class_is_refused_by_enforce_policy(monkeypatch):
    """Auto actions are not requestable: the merge commit is the approval,
    so a request would mint a warrant for something no human decided."""
    client = PolicyClient(
        {("main", "warrant-policy.yaml"): _policy_with("  x.yaml:\n    class: auto\n")}
    )
    out = _enforce(client, "x.yaml", monkeypatch)
    assert "class AUTO" in out
    assert "not requestable" in out


def test_deny_class_is_still_refused(monkeypatch):
    client = PolicyClient(
        {
            ("main", "warrant-policy.yaml"): _policy_with(
                "  x.yaml:\n    class: deny\n    note: nope\n"
            )
        }
    )
    out = _enforce(client, "x.yaml", monkeypatch)
    assert "class DENY" in out


def test_real_policy_marks_host_workflows_auto():
    """The three push-triggered workflows are class auto in the real policy,
    with no binds_sha/inputs — they are not requestable."""
    assert AUTO_ACTIONS == [
        "build-container.yaml",
        "provision-indri.yaml",
        "ringtail-rebuild.yaml",
    ]
    for name in AUTO_ACTIONS:
        entry = ACTIONS[name]
        assert "binds_sha" not in entry
        assert "inputs" not in entry


def test_real_policy_refuses_auto_workflows(monkeypatch):
    """enforce_policy against the real policy refuses each auto action before
    any input or binding logic runs."""
    client = PolicyClient({("main", "warrant-policy.yaml"): POLICY})
    for workflow in AUTO_ACTIONS:
        out = _enforce(client, workflow, monkeypatch)
        assert "class AUTO" in out


def test_warrant_action_without_binding_is_refused():
    """A warrant-class entry that declares no binds_sha is refused — the
    enforcement-side mirror of test_every_warrant_action_binds_its_sha."""
    with pytest.raises(typer.Exit):
        request_run.enforce_sha_binding("x.yaml", {"class": "warrant"}, {}, SHA)
