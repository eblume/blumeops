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
    if spec is None:
        raise RuntimeError("could not build an import spec")
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


APP_YAML = (
    "apiVersion: argoproj.io/v1alpha1\n"
    "kind: Application\n"
    "spec:\n"
    "  source:\n"
    "    targetRevision: {tag}\n"
)

POLICY = (ROOT / "warrant-policy.yaml").read_text()


def request_declared(tag_main: str, tag_bound: str | None) -> None:
    files = {
        ("main", "warrant-policy.yaml"): POLICY,
        ("main", "argocd/apps/external-secrets-crds-ringtail.yaml"): APP_YAML.format(
            tag=tag_main
        ),
    }
    if tag_bound is not None:
        files[(SHA, "argocd/apps/external-secrets-crds-ringtail.yaml")] = (
            APP_YAML.format(tag=tag_bound)
        )
    request_run.enforce_policy(
        PolicyClient(files),
        "argocd-deploy.yaml",
        {"app": "external-secrets-crds-ringtail", "revision": "declared"},
        SHA,
    )


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
    """The original bug (build-container's `ref`): no ref, so the dispatch
    silently built main. Exercised here on deploy-fly's revision binding —
    same shape: omit the bound input and the run would target main, not the
    bound SHA."""
    with pytest.raises(typer.Exit):
        check("deploy-fly.yaml", {})


def test_different_sha_is_refused():
    with pytest.raises(typer.Exit):
        check("deploy-fly.yaml", {"revision": OTHER})


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


def test_argocd_declared_revision_binds_the_declaring_commit():
    """`declared` is admitted because argocd-deploy's policy pattern admits
    it: the bound SHA is the commit declaring the revision, not the payload."""
    check("argocd-deploy.yaml", {"app": "grafana-ringtail", "revision": "declared"})


def test_declared_is_refused_where_the_pattern_does_not_admit_it():
    with pytest.raises(typer.Exit):
        check("deploy-fly.yaml", {"revision": "declared"})


def test_declared_binds_the_commit_declaring_the_revision():
    request_declared("helm-chart-2.10.0", "helm-chart-2.10.0")


def test_declared_refuses_a_sha_declaring_a_different_revision():
    with pytest.raises(typer.Exit):
        request_declared("helm-chart-2.10.0", "helm-chart-2.9.0")


def test_declared_refuses_a_sha_without_the_app():
    with pytest.raises(typer.Exit):
        request_declared("helm-chart-2.10.0", None)


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
