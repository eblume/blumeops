"""openrouter-reconcile: dashboard-set guardrail state becomes a declared file.

`openrouter-reconcile` reconciles the OpenRouter workspace guardrail against
`openrouter/guardrails.json`. Before the file existed the settings were set
by hand in the dashboard and drifted until an incident (eblume/blumeops#1864).
The guardrail is matched by **id** (never by name — the name embeds the
workspace UUID), only the declared fields are diffed, `content_filter_builtins`
compares per declared entry on (slug, action, label) with replace-semantics
on apply, and every apply reads the guardrail back and re-diffs before
declaring convergence — the forge-reconcile hook lesson, because a 200 is not
proof. The management key and its `expires` DATE come from a blumeops-vault
1Password item read by the declared item **id** (`op read` cannot parse the
item's parenthesized name), the credential is never printed, and the expiry
warning (past or within 10 days, warning only) must carry the rotation
instruction.

Everything is importable and testable without op or network: the declared
file is pointed at a scratch path, `subprocess.run` is swapped for a canned
op, and httpx.Client is swapped for a MockTransport-backed fake API.
"""

import importlib.machinery
import importlib.util
import io
import json
import pathlib
import subprocess
from datetime import UTC, datetime, timedelta

import httpx
import pytest
import typer
from rich.console import Console

ROOT = pathlib.Path(__file__).resolve().parent.parent


def _load():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "openrouter_reconcile", str(ROOT / "mise-tasks" / "openrouter-reconcile")
    )
    spec = importlib.util.spec_from_loader("openrouter_reconcile", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


ora = _load()

ITEM_ID = "xzxr47lveovnnobyd4kfqfdvry"
GUARDRAIL_ID = "6cb94804-7ca6-55e5-9848-18549f1a8853"
KEY = "sk-or-v1-test-key"


def _guardrail(**overrides):
    """A guardrail as the declared file declares it (and, absent drift, as the
    live API serves it)."""
    g = {
        "id": GUARDRAIL_ID,
        "name": "Workspace 20bddaf2-0aa1-58c3-b274-c9f858e60f4a Default",
        "limit_usd": 400,
        "reset_interval": "monthly",
        "enforce_zdr_anthropic": False,
        "enforce_zdr_openai": False,
        "enforce_zdr_google": False,
        "enforce_zdr_xai": False,
        "enforce_zdr_other": False,
        "enable_paid_model_training": False,
        "enable_free_model_training": False,
        "enable_free_model_publication": False,
        "include_byok_in_budgets": False,
        "content_filter_builtins": [
            {
                "slug": "regex-prompt-injection",
                "action": "flag",
                "label": "[PROMPT_INJECTION]",
            }
        ],
    }
    g.update(overrides)
    return g


def _declared(**guardrail_overrides):
    return {
        "vault": "blumeops",
        "item": ITEM_ID,
        "guardrail": _guardrail(**guardrail_overrides),
    }


def _op_values(days=30, item=ITEM_ID):
    """Canned `op read` stdout for the credential + a fresh `expires` (a DATE
    field, served as epoch seconds)."""
    epoch = int((datetime.now(UTC) + timedelta(days=days)).timestamp())
    return {
        f"op://blumeops/{item}/credential": f"{KEY}\n",
        f"op://blumeops/{item}/expires": f"{epoch}\n",
    }


class _FakeOp:
    """Stands in for subprocess.run: serves canned `op read` stdout by ref and
    raises CalledProcessError for unknown refs, exactly like the real CLI
    under check=True."""

    def __init__(self, values):
        self.values = dict(values)
        self.calls = []

    def __call__(self, args, **kwargs):
        assert args[:2] == ["op", "read"], args
        self.calls.append(args)
        ref = args[2]
        if ref not in self.values:
            raise subprocess.CalledProcessError(1, args)
        return subprocess.CompletedProcess(args, 0, stdout=self.values[ref], stderr="")


class FakeAPI:
    """MockTransport-backed OpenRouter: records requests and PATCH bodies,
    serves a guardrails list, and applies PATCHes to mutable live state the
    way the real API would (unless apply=False, the 200-changes-nothing
    case). List responses serve the bare list or the `{"data": [...]}`
    envelope."""

    def __init__(self, guardrails, envelope=True, apply=True):
        self.requests = []  # (method, url)
        self.patch_bodies: list[dict] = []
        self.guardrails = [dict(g) for g in guardrails]
        self.envelope = envelope
        self.apply = apply

    def handler(self, request):
        self.requests.append((request.method, str(request.url)))
        path = request.url.path
        if request.method == "GET":
            data = self.guardrails if not self.envelope else {"data": self.guardrails}
            return httpx.Response(200, json=data)
        if request.method == "PATCH":
            body = json.loads(request.content)
            self.patch_bodies.append(body)
            the_id = path.rsplit("/", 1)[-1]
            for g in self.guardrails:
                if g["id"] == the_id:
                    if self.apply:
                        g.update(body)
                    return httpx.Response(200, json=dict(g))
            return httpx.Response(404, json={"error": "no such guardrail"})
        return httpx.Response(405, json={"error": "method not allowed"})

    def install(self, monkeypatch):
        real_client = httpx.Client

        def factory(*args, **kwargs):
            # Bind real_client before patching: httpx.Client is the same
            # module object the script's httpx sees, so a self-reference would
            # recurse. The script builds the client with the Authorization
            # header already set, so headers ride along like in prod.
            return real_client(
                *args, transport=httpx.MockTransport(self.handler), **kwargs
            )

        monkeypatch.setattr(ora.httpx, "Client", factory)
        return factory()


@pytest.fixture
def declared_file(tmp_path, monkeypatch):
    """Point GUARDRAILS_PATH at a scratch guardrails.json; return a setter."""

    def set_declared(declared):
        path = tmp_path / "guardrails.json"
        path.write_text(json.dumps(declared), encoding="utf-8")
        monkeypatch.setattr(ora, "GUARDRAILS_PATH", path)
        return path

    return set_declared


@pytest.fixture
def run_main(monkeypatch):
    """Invoke main() directly with rich output captured; returns (code, out)."""
    buf = io.StringIO()
    monkeypatch.setattr(
        ora, "console", Console(file=buf, force_terminal=False, width=200)
    )

    def invoke(*args, **kwargs):
        code = 0
        try:
            ora.main(*args, **kwargs)
        except typer.Exit as exc:
            code = exc.exit_code
        return code, buf.getvalue()

    return invoke


def test_no_drift_is_clean(declared_file, run_main, monkeypatch):
    # Live serves the bare-list shape and matches the declared guardrail:
    # --check exits 0, the key never appears, and op was read by item id.
    declared_file(_declared())
    api = FakeAPI([_guardrail()], envelope=False)
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 0
    assert "In sync." in out
    assert KEY not in out
    assert [c[2] for c in op.calls] == [
        f"op://blumeops/{ITEM_ID}/credential",
        f"op://blumeops/{ITEM_ID}/expires",
    ]


def test_scalar_drift_fails_check(declared_file, run_main, monkeypatch):
    # Live serves the {"data": [...]} envelope; limit_usd 500 vs declared 400.
    declared_file(_declared())
    api = FakeAPI([_guardrail(limit_usd=500)])
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 1
    assert "Out of sync (--check)." in out
    assert "limit_usd" in out
    assert "500 -> 400" in out
    assert api.patch_bodies == []  # --check never mutates
    assert KEY not in out


def test_builtin_missing_from_live_is_drift(declared_file, run_main, monkeypatch):
    # Live carries no builtins at all; the declared one must be present.
    declared_file(_declared())
    live = _guardrail(content_filter_builtins=[])
    api = FakeAPI([live])
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 1
    assert "content_filter_builtins" in out


def test_builtin_action_changed_is_drift(declared_file, run_main, monkeypatch):
    # The declared entry's action is flag; live says redact.
    declared_file(_declared())
    live = _guardrail(
        content_filter_builtins=[
            {
                "slug": "regex-prompt-injection",
                "action": "redact",
                "label": "[PROMPT_INJECTION]",
            }
        ]
    )
    api = FakeAPI([live])
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 1
    assert "content_filter_builtins" in out


def test_apply_patches_only_drifted_fields(declared_file, run_main, monkeypatch):
    # Two scalars drifted: the PATCH body carries exactly those two fields —
    # no id, no name, no untouched fields — and the read-back converges.
    declared_file(_declared())
    api = FakeAPI([_guardrail(limit_usd=500, reset_interval="weekly")])
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main()
    assert code == 0, out
    assert api.patch_bodies == [{"limit_usd": 400, "reset_interval": "monthly"}]
    assert "converged" in out
    assert KEY not in out


def test_apply_patch_carries_full_builtins_when_builtins_drift(
    declared_file, run_main, monkeypatch
):
    # Builtins are replace-semantics: a drifted collection sends the whole
    # declared array, and no scalar field rides along.
    declared_file(_declared())
    live = _guardrail(content_filter_builtins=[])
    api = FakeAPI([live])
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main()
    assert code == 0, out
    assert api.patch_bodies == [
        {"content_filter_builtins": _guardrail()["content_filter_builtins"]}
    ]
    assert "converged" in out


def test_apply_readback_mismatch_fails(declared_file, run_main, monkeypatch):
    # A PATCH that answers 200 but changes nothing (the forge-reconcile hook
    # lesson) must fail the read-back re-diff, not report success.
    declared_file(_declared())
    api = FakeAPI([_guardrail(limit_usd=500)], apply=False)
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main()
    assert code == 1
    assert "did not converge" in out
    assert "limit_usd" in out


def test_dry_run_prints_patch_body_without_sending(
    declared_file, run_main, monkeypatch
):
    declared_file(_declared())
    api = FakeAPI([_guardrail(limit_usd=500)])
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(dry_run=True)
    assert code == 0
    assert '"limit_usd": 400' in out
    assert api.patch_bodies == []  # nothing was sent
    assert KEY not in out


def test_no_live_match_fails(declared_file, run_main, monkeypatch):
    declared_file(_declared())
    api = FakeAPI([_guardrail(id="some-other-id")])
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 1
    assert "No live guardrail" in out
    assert GUARDRAIL_ID in out


def test_multiple_live_matches_fail(declared_file, run_main, monkeypatch):
    declared_file(_declared())
    api = FakeAPI([_guardrail(), _guardrail()])
    api.install(monkeypatch)
    op = _FakeOp(_op_values())
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 1
    assert "refusing to reconcile an ambiguous target" in out


def test_item_override_substitutes_into_op_path(declared_file, run_main, monkeypatch):
    # --item swaps the op path template's item for a copy, so the expiry test
    # never touches the real item.
    declared_file(_declared())
    api = FakeAPI([_guardrail()])
    api.install(monkeypatch)
    op = _FakeOp(_op_values(item="copy-item"))
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, _out = run_main(check=True, item="copy-item")
    assert code == 0
    assert all(c[2].startswith("op://blumeops/copy-item/") for c in op.calls)
    assert not any(ITEM_ID in c[2] for c in op.calls)


def test_declared_enforce_zdr_is_refused(declared_file, run_main):
    # The deprecated blanket field must not creep back in; load refuses.
    declared = _declared(enforce_zdr=False)
    declared_file(declared)

    code, out = run_main(check=True)
    assert code == 1
    assert "enforce_zdr" in out


def test_expiry_fresh_no_warning(declared_file, run_main, monkeypatch):
    declared_file(_declared())
    api = FakeAPI([_guardrail()])
    api.install(monkeypatch)
    op = _FakeOp(_op_values(days=30))
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 0
    assert ora.ROTATION_INSTRUCTION not in out


def test_expiry_exactly_10_days_warns(declared_file, run_main, monkeypatch):
    declared_file(_declared())
    api = FakeAPI([_guardrail()])
    api.install(monkeypatch)
    op = _FakeOp(_op_values(days=10))
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 0  # a warning, never a changed exit code
    assert ora.ROTATION_INSTRUCTION in out


def test_expiry_past_warns(declared_file, run_main, monkeypatch):
    declared_file(_declared())
    api = FakeAPI([_guardrail()])
    api.install(monkeypatch)
    op = _FakeOp(_op_values(days=-2))
    monkeypatch.setattr(ora.subprocess, "run", op)

    code, out = run_main(check=True)
    assert code == 0
    assert ora.ROTATION_INSTRUCTION in out


def test_expiry_warning_thresholds():
    # Pure expiry-warning logic: fresh (>10 days) silent, exactly 10 days out
    # warns, past warns, one second past 10 days is still fresh.
    now = datetime(2026, 10, 24, 12, 0, 0, tzinfo=UTC)
    fresh = int(now.timestamp()) + 30 * 86400
    assert ora.expiry_warning(fresh, now=now) is None
    exact = int(now.timestamp()) + 10 * 86400
    warning = ora.expiry_warning(exact, now=now)
    assert warning is not None
    assert ora.ROTATION_INSTRUCTION in warning
    past = int(now.timestamp()) - 86400
    assert ora.ROTATION_INSTRUCTION in ora.expiry_warning(past, now=now)
    over = int(now.timestamp()) + 10 * 86400 + 1
    assert ora.expiry_warning(over, now=now) is None
