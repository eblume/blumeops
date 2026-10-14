"""lint-auto-apply: the derivation must fail closed, and markers must be read strictly.

The lint gates auto-apply PRs (docs/explanation/auto-apply.md), so a PR that
breaks its own workflow (unparseable YAML, a string-form `on: push`, a
non-list `paths`, an unexpected glob, a host glob cancelled by paths-ignore,
a missing workflow file) must fail the lint rather than silently drop the
host — and a #NNNN named outside a host's Auto-apply blockquote block is not
a declaration that the merge would ship that change.

The fixture workflows are the minimal shape the production ones
(ringtail-rebuild.yaml, provision-indri.yaml) must hold; `derive_hosts` in
mise-tasks/lint-auto-apply holds the full contract.
"""

import importlib.machinery
import importlib.util
import json
import pathlib
import sys

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent


@pytest.fixture(scope="session")
def laa():
    # Mise tasks are extensionless, so name the loader. Importing is safe:
    # typer.run() is under __main__.
    loader = importlib.machinery.SourceFileLoader(
        "lint_auto_apply", str(ROOT / "mise-tasks" / "lint-auto-apply")
    )
    spec = importlib.util.spec_from_loader("lint_auto_apply", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    # Register before exec: the module's @dataclass looks itself up in
    # sys.modules at decoration time.
    sys.modules["lint_auto_apply"] = module
    loader.exec_module(module)
    return module


POLICY = """
version: 1
actions:
  ringtail-rebuild.yaml:
    class: auto
  provision-indri.yaml:
    class: auto
  build-container.yaml:
    class: auto
  argocd-deploy.yaml:
    class: warrant
"""

RINGTAIL = """
on:
  push:
    branches: [main]
    paths:
      - 'nixos/ringtail/**'
      - 'forge/runners.nix'
      - 'forge/runners.json'
  workflow_dispatch:
    inputs:
      revision:
        required: true
"""

INDRI = """
on:
  push:
    paths:
      - 'darwin/indri/**'
      - 'forge/runners.nix'
      - 'forge/runners.json'
  workflow_dispatch:
    inputs:
      revision:
        required: true
jobs:
  apply:
    steps:
      - run: |
          # fire-and-forget: a green run means launched
          wait=false
"""

BUILD = """
on:
  push:
    paths:
      - 'containers/**'
"""


class FakeResp:
    def __init__(self, status_code: int, data):
        self.status_code = status_code
        self._data = data

    def json(self):
        return self._data

    def raise_for_status(self):
        if self.status_code >= 400:
            raise RuntimeError(f"unexpected status {self.status_code}")


class FakeClient:
    """A contents-API stub: files maps (path, ref) → text, None = 404."""

    def __init__(self, files: dict):
        self.files = files

    def get(self, url: str, params: dict | None = None) -> FakeResp:
        path = url.removeprefix("/repos/eblume/blumeops/contents/")
        ref = (params or {}).get("ref")
        if (path, ref) in self.files:
            content = self.files[(path, ref)]
            if content is None:
                return FakeResp(404, {})
            return FakeResp(200, {"content": content, "encoding": "text"})
        return FakeResp(404, {})


def _client(ringtail: str = RINGTAIL, missing: bool = False) -> FakeClient:
    files = {
        ("warrant-policy.yaml", "main"): POLICY,
        (".forgejo/workflows/provision-indri.yaml", "main"): INDRI,
        (".forgejo/workflows/build-container.yaml", "main"): BUILD,
    }
    if not missing:
        files[(".forgejo/workflows/ringtail-rebuild.yaml", "main")] = ringtail
    return FakeClient(files)


def test_host_glob_shape(laa):
    rgx = laa.HOST_GLOB_RE
    assert rgx.match("nixos/ringtail/**")
    assert rgx.match("darwin/indri-2/**")
    assert rgx.match("nixos/ringtail") is None
    assert rgx.match("nixos/ringtail/*.nix") is None
    assert rgx.match("nixos/ringtail/x/**") is None
    assert rgx.match("containers/**") is None
    assert rgx.match("nixos//**") is None
    assert rgx.match("nixos/ringtail/**/") is None


def test_plain_path_shape(laa):
    rgx = laa.PLAIN_PATH_RE
    assert rgx.match("forge/runners.nix")
    assert rgx.match("a/b/c.json")
    assert rgx.match("containers/**") is None
    assert rgx.match("nixos/ringtail/*") is None
    assert rgx.match("/absolute/nix") is None
    assert rgx.match("a/../b") is None


def test_glob_matches(laa):
    m = laa.glob_matches
    assert m("nixos/ringtail/**", "nixos/ringtail/configuration.nix")
    assert m("nixos/ringtail/**", "nixos/ringtail/roles/x")
    assert not m("nixos/ringtail/**", "nixos/ringtail")
    assert not m("nixos/ringtail/**", "nixos/ringtailx/nix")
    # A plain input path matches exactly, not by prefix.
    assert m("forge/runners.nix", "forge/runners.nix")
    assert not m("forge/runners.nix", "forge/runners.nix.bak")


def test_derive_hosts_ok(laa):
    hosts = laa.derive_hosts(_client())
    # Policy order; the warrant-class entry and the allowlisted
    # build-container are not derived.
    assert list(hosts) == ["ringtail", "indri"]
    r = hosts["ringtail"]
    assert r.workflow == "ringtail-rebuild.yaml"
    assert r.globs == ["nixos/ringtail/**"]
    assert r.trigger_paths == [
        "nixos/ringtail/**",
        "forge/runners.nix",
        "forge/runners.json",
    ]
    assert not r.fire_and_forget
    i = hosts["indri"]
    assert i.globs == ["darwin/indri/**"]
    assert i.trigger_paths == [
        "darwin/indri/**",
        "forge/runners.nix",
        "forge/runners.json",
    ]
    assert i.fire_and_forget


BAD_WORKFLOWS = [
    "broken: [",  # unparseable
    "on: push",  # string form — no paths to derive from
    "on: {}",  # no push trigger
    "on: {push: {paths: 'nixos/ringtail/**'}}",  # paths is not a list
    "on: {push: {paths: []}}",  # no globs at all
    "on: {push: {paths: ['containers/**']}}",  # a glob that is not host-shaped
    "on: {push: {paths: ['nixos/ringtail/**/']}}",  # not the exact shape
    "on: {push: {paths: ['nixos/ringtail/**'], paths-ignore: ['nixos/ringtail/**']}}",
    # the only host glob cancelled by paths-ignore → no host derived
    "on: {push: {paths: ['nixos/ringtail/**'], paths-ignore: 'nixos/ringtail/**'}}",
    # paths-ignore is not a list
    "on: {push: {paths: [42]}}",  # non-string entry
]


@pytest.mark.parametrize("bad", BAD_WORKFLOWS)
def test_derive_hosts_fail_closed(laa, bad):
    with pytest.raises(SystemExit) as ei:
        laa.derive_hosts(_client(ringtail=bad))
    assert "ringtail-rebuild.yaml" in str(ei.value)


def test_derive_hosts_missing_workflow(laa):
    with pytest.raises(SystemExit) as ei:
        laa.derive_hosts(_client(missing=True))
    assert "ringtail-rebuild.yaml" in str(ei.value)


def test_derive_hosts_unparseable_policy(laa):
    client = _client()
    client.files[("warrant-policy.yaml", "main")] = "actions: {{"
    with pytest.raises(SystemExit) as ei:
        laa.derive_hosts(client)
    assert "warrant-policy.yaml" in str(ei.value)


def test_derive_hosts_pr_head_ref(laa):
    # A workflow the PR modified is read at the PR head sha — fail-closed
    # there too: a host glob replaced by a non-host glob at the head is an
    # error, not a silent drop.
    client = _client()
    client.files[(".forgejo/workflows/ringtail-rebuild.yaml", "deadbeef")] = (
        "on: {push: {paths: ['containers/**']}}"
    )
    with pytest.raises(SystemExit) as ei:
        laa.derive_hosts(client, {"ringtail-rebuild.yaml": "deadbeef"})
    assert "ringtail-rebuild.yaml" in str(ei.value)


def test_derive_hosts_policy_at_ref(laa):
    # The policy is read at policy_ref when the PR modifies it.
    client = _client()
    del client.files[("warrant-policy.yaml", "main")]
    client.files[("warrant-policy.yaml", "deadbeef")] = POLICY
    hosts = laa.derive_hosts(client, policy_ref="deadbeef")
    assert set(hosts) == {"ringtail", "indri"}


def test_run_revision(laa):
    push = {"trigger_event": "push", "commit_sha": "a" * 40}
    assert laa.run_revision(push) == "a" * 40
    dispatch = {
        "trigger_event": "workflow_dispatch",
        "event_payload": json.dumps({"inputs": {"revision": "b" * 40}}),
    }
    assert laa.run_revision(dispatch) == "b" * 40
    assert (
        laa.run_revision(
            {"trigger_event": "workflow_dispatch", "event_payload": "not json"}
        )
        is None
    )
    assert (
        laa.run_revision({"trigger_event": "workflow_dispatch", "event_payload": "{}"})
        is None
    )
    assert laa.run_revision({"trigger_event": "push", "commit_sha": "abc"}) is None


def test_pr_subject_number(laa):
    assert (
        laa.pr_subject_number(
            "Merge pull request 'fix' (#12) from agents:agent/x into main"
        )
        == 12
    )
    assert laa.pr_subject_number("direct push") is None


def test_marker_regex_strict(laa):
    m = laa.MARKER_RE
    assert m.match("Auto-apply: ringtail")
    assert m.match("Auto-apply:    ringtail")
    assert m.match("Auto-apply: ringtail ")
    # \s* used to straddle a newline; [ \t]* must not.
    assert m.match("Auto-apply:") is None
    assert m.match("Auto-apply: ringtail extra") is None
    assert m.match("  Auto-apply: ringtail") is None
    # Uppercase declares a *different* host — it does not count for ringtail.
    assert m.match("Auto-apply: Ringtail").group(1) == "Ringtail"
    assert m.match("!!Auto-apply: ringtail") is None


BODY_LINES = [
    "Here is the block I was shown:",
    "",
    "```bash",
    "Auto-apply: ringtail#9999",
    "```",
    "",
    "The actual declaration:",
    "Auto-apply: ringtail",
    "> Pending host changes on main that this merge would also apply:",
    "> - #1550 — fix the runner labels",
    "> - #1540 — bump nixpkgs",
    "Auto-apply: indri",
    "> - #1571 — something else",
]
BODY = "\n".join(BODY_LINES)


def test_markers_skip_fences(laa):
    markers = laa.body_markers(BODY)
    # Only the real declarations count — the fenced one does not.
    assert markers == {"ringtail": 7, "indri": 11}


def test_segment_is_blockquote_only(laa):
    seg = laa.pending_segment(BODY, "ringtail")
    assert seg is not None
    text = "\n".join(seg)
    assert "#1550" in text and "#1540" in text
    # indri's items are outside ringtail's segment, and the fenced mention
    # is not a declaration at all.
    assert "#1571" not in text
    assert "#9999" not in text


def test_segment_missing_host(laa):
    assert laa.pending_segment(BODY, "nope") is None
    # A marker with no blockquote lines yields an empty segment, not None.
    assert laa.pending_segment("Auto-apply: ringtail\n", "ringtail") == []
