"""service-review: build_checklist behavior across the release axis.

The checklist is a pure function over a service dict, so the axis decisions
are unit-testable without a console: `release: self` swaps the version check
for a release-pipeline check, while the per-type branches are orthogonal and
always run.
"""

import importlib.machinery
import importlib.util
import pathlib
from datetime import date

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "service_review", str(ROOT / "mise-tasks" / "service-review")
    )
    spec = importlib.util.spec_from_loader("service_review", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


review = _load()


def _svc(**overrides) -> dict:
    """A minimal service dict; tests override the axis-relevant fields."""
    svc = {
        "name": "svc",
        "type": "argocd",
        "last-reviewed": None,
        "current-version": "v1.0.0",
        "upstream-source": "https://example.com/releases",
    }
    svc.update(overrides)
    return svc


def _text(parts: list[str]) -> str:
    return "".join(parts)


def test_upstream_argocd_uses_version_check():
    parts = _text(review.build_checklist(_svc(), date(2026, 9, 17)))
    assert "Version Check:" in parts
    assert "ArgoCD Deployment:" in parts
    assert "Release Pipeline Check:" not in parts


def test_self_released_argocd_swaps_check():
    parts = _text(review.build_checklist(_svc(release="self"), date(2026, 9, 17)))
    assert "Release Pipeline Check:" in parts
    assert "ArgoCD Deployment:" in parts  # type branch still runs
    assert "Check upstream releases" not in parts
    assert "After Review:" in parts  # stamping unchanged


def test_self_released_ansible_keeps_type_branch():
    parts = _text(
        review.build_checklist(_svc(release="self", type="ansible"), date(2026, 9, 17))
    )
    assert "Release Pipeline Check:" in parts
    assert "Ansible Deployment:" in parts


def test_each_type_hits_its_own_branch():
    for svc_type, heading in [
        ("container", "Container Build:"),
        ("nixos", "NixOS Deployment:"),
        ("fly", "Fly Proxy App:"),
        ("mise", "Mise Tool Update:"),
    ]:
        parts = _text(review.build_checklist(_svc(type=svc_type), date(2026, 9, 17)))
        assert heading in parts


def test_missing_upstream_defaults_to_na():
    # never-reviewed / null upstream-source must not crash the checklist
    svc = _svc()
    svc["upstream-source"] = None
    parts = _text(review.build_checklist(svc, date(2026, 9, 17)))
    assert "Check upstream releases: N/A" in parts


def test_after_review_stamps_today():
    parts = _text(review.build_checklist(_svc(release="self"), date(2026, 9, 17)))
    assert "last-reviewed: 2026-09-17" in parts
