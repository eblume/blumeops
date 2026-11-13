"""The forge owner allowlist agrees with the argocd validator.

aspects/forge-sources-only grades forge sources by owner (ALLOWED_OWNERS);
mise-tasks/validate-argocd-apps refuses any Application source outside its
ALLOWED_SOURCES patterns. Both name the same owners: the ones the talos bot
cannot write. This keeps them from drifting apart.
"""

import importlib.machinery
import importlib.util
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
VALIDATOR = ROOT / "mise-tasks" / "validate-argocd-apps"
ASPECT = ROOT / "aspects" / "forge-sources-only" / "test_forge_sources_only.py"
OWNER_IN_PATTERN = re.compile(r":\\d\+/([^/\\]+)/")


def _load(name: str, path: pathlib.Path):
    # Extensionless mise task and a hyphenated dir: name the loader explicitly.
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


validator = _load("validate_argocd_apps", VALIDATOR)
aspect = _load("forge_sources_only_aspect", ASPECT)


def _validator_owners() -> set[str]:
    owners: set[str] = set()
    for url_re, _ in validator.ALLOWED_SOURCES:
        found = OWNER_IN_PATTERN.search(url_re.pattern)
        assert found, (
            f"could not extract an owner from validator pattern "
            f"{url_re.pattern!r} — the pattern format changed; "
            "update OWNER_IN_PATTERN"
        )
        owners.add(found.group(1).lower())
    return owners


def test_validator_owners_match_forge_allowlist():
    assert _validator_owners() == set(aspect.ALLOWED_OWNERS)


def test_every_allowed_owner_is_accepted_by_validator():
    for owner in aspect.ALLOWED_OWNERS:
        accepted = [
            validator.is_safe(
                f"ssh://forgejo@forge.ops.eblu.me:2222/{owner}/{repo}", "main"
            )[0]
            for repo in ("blumeops.git", "prometheus.git")
        ]
        assert any(accepted), f"validator refuses every probe URL under owner {owner!r}"


def test_talos_is_refused_by_validator():
    url = "ssh://forgejo@forge.ops.eblu.me:2222/talos/blumeops.git"
    assert not validator.is_safe(url, "main")[0]
    assert not validator.is_safe(url, None)[0]
