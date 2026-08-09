"""The approved SHA must reach the run — request-run's half of invariant 3.

Warrant binds a request to an immutable commit, but the workflow takes its
target as a dispatch *input*, and for a long time nothing joined the two.
Requesting `build-container.yaml @ bcb2b55 -i container=agent-ws` filed an
approval that read "build bcb2b55", dispatched a build of main, and reported
success (warrant #22, run 742). The requested change was never built and every
signal was green.

These tests pin the join: `binds_sha` in warrant-policy.yaml names the input
carrying the approved SHA, and request-run refuses anything that would let CI
build something else. The coverage test is the load-bearing one — it fails the
day someone adds a warrant-class action without a binding, which is how the
hole would otherwise reopen.
"""

import importlib.machinery
import importlib.util
import pathlib

import pytest
import typer
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHA = "b" * 40
OTHER = "c" * 40


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
ACTIONS = yaml.safe_load((ROOT / "warrant-policy.yaml").read_text())["actions"]
WARRANT_ACTIONS = sorted(
    name for name, entry in ACTIONS.items() if entry.get("class") == "warrant"
)


def check(workflow: str, inputs: dict[str, str]) -> None:
    request_run.enforce_sha_binding(workflow, ACTIONS[workflow], inputs, SHA)


@pytest.mark.parametrize("workflow", WARRANT_ACTIONS)
def test_every_warrant_action_binds_its_sha(workflow):
    """A requestable workflow free to ignore the approved SHA is precisely
    what the approval was meant to constrain."""
    binding = ACTIONS[workflow].get("binds_sha")
    assert binding, f"{workflow} is class warrant but declares no binds_sha"
    assert binding in (ACTIONS[workflow].get("inputs") or {}), (
        f"{workflow} binds_sha={binding!r}, which is not a declared input"
    )


def test_omitted_binding_input_is_refused():
    """The original bug: no ref, so the dispatch silently built main."""
    with pytest.raises(typer.Exit):
        check("build-container.yaml", {"container": "agent-ws"})


def test_matching_sha_is_allowed():
    check("build-container.yaml", {"container": "agent-ws", "ref": SHA})


def test_different_sha_is_refused():
    with pytest.raises(typer.Exit):
        check("build-container.yaml", {"container": "agent-ws", "ref": OTHER})


def test_mutable_ref_is_refused():
    """`main` is a legal dispatch value but resolves at dispatch time — the
    moving target an approval exists to pin down."""
    with pytest.raises(typer.Exit):
        check("deploy-fly.yaml", {"revision": "main"})


def test_deploy_fly_and_argocd_bind_revision():
    check("deploy-fly.yaml", {"revision": SHA})
    check("argocd-deploy.yaml", {"app": "grafana-ringtail", "revision": SHA})
    with pytest.raises(typer.Exit):
        check("argocd-deploy.yaml", {"app": "grafana-ringtail"})


def test_non_warrant_action_without_binding_is_not_refused():
    """deny-class entries never reach dispatch, so they need no binding."""
    request_run.enforce_sha_binding("x.yaml", {"class": "deny"}, {}, SHA)


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        (
            "supersedes request #21, deny that one",
            "supersedes request `#21`, deny that one",
        ),
        ("no refs here", "no refs here"),
        ("already `#21` quoted", "already `#21` quoted"),
        ("rgb #ffffff is not a ref", "rgb #ffffff is not a ref"),
    ],
)
def test_bare_refs_are_neutralized(text, expected):
    """A bare #N in --why autolinked to an unrelated PR of this repo (seen on
    PR #525). Code spans are exempt from Forgejo's reference expansion."""
    assert request_run.neutralize_refs(text) == expected
