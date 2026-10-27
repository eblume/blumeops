"""Offline tests for the OpenRouter exporter.

Feeds the synthetic fixtures under ``fixtures/`` through an injected fetch
function, so no network and no management key is needed.
"""

import importlib.util
import io
import json
import pathlib
import urllib.error

import pytest
from prometheus_client import generate_latest
from prometheus_client.core import CollectorRegistry

HERE = pathlib.Path(__file__).parent
FIXTURES = HERE / "fixtures"
FAKE_KEY = "sk-or-v1-TESTKEY-do-not-log"


def _exporter():
    spec = importlib.util.spec_from_file_location(
        "openrouter_exporter", HERE / "exporter.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


exp = _exporter()


def _load(name):
    return json.loads((FIXTURES / name).read_text())


class FakeUpstream:
    """Routes ``fetch(path)`` to canned payloads; an Exception value is raised."""

    def __init__(self, activity=None, credits=None):
        self.responses = {
            "/activity": activity if activity is not None else _load("activity.json"),
            "/credits": credits if credits is not None else _load("credits.json"),
        }
        self.calls: list[str] = []

    def __call__(self, path):
        self.calls.append(path)
        value = self.responses[path]
        if isinstance(value, Exception):
            raise value
        return value


class Clock:
    def __init__(self, now=1_000_000.0):
        self.now = now

    def __call__(self):
        return self.now


def _render(exporter):
    registry = CollectorRegistry(auto_describe=False)
    registry.register(exporter)
    return generate_latest(registry).decode()


def _series(text, name):
    return [
        line for line in text.splitlines() if line.startswith((name + "{", name + " "))
    ]


def _endpoint_ts(text, endpoint):
    prefix = (
        f'openrouter_exporter_last_success_timestamp_seconds{{endpoint="{endpoint}"}} '
    )
    lines = [line for line in text.splitlines() if line.startswith(prefix)]
    assert len(lines) == 1, f"expected one timestamp sample for {endpoint}, got {lines}"
    return float(lines[0][len(prefix) :])


def _value(text, name):
    lines = [line for line in text.splitlines() if line.startswith(name + " ")]
    assert len(lines) == 1, f"expected one bare sample for {name}, got {lines}"
    return float(lines[0].split()[-1])


def test_activity_sums_rows_with_same_date_and_model():
    parsed = exp.parse_activity(_load("activity.json"))
    usage, byok = parsed[("2026-10-20", "anthropic/claude-sonnet-4")]
    assert usage == pytest.approx(1.2345 + 0.5)
    assert byok == pytest.approx(0.0 + 0.25)


def test_activity_gauges_emit_per_date_model_and_byok_series():
    text = _render(exp.Exporter(FakeUpstream(), clock=Clock()))
    assert (
        'openrouter_activity_usage_usd{date="2026-10-20",model="anthropic/claude-sonnet-4"} 1.7345'
        in text
    )
    assert (
        'openrouter_activity_byok_usage_usd{date="2026-10-20",model="anthropic/claude-sonnet-4"} 0.25'
        in text
    )
    assert (
        'openrouter_activity_byok_usage_usd{date="2026-10-22",model="deepseek/deepseek-r1"} 0.0'
        in text
    )
    assert len(_series(text, "openrouter_activity_usage_usd")) == 4


def test_credits_remaining_is_total_minus_usage():
    text = _render(exp.Exporter(FakeUpstream(), clock=Clock()))
    assert _value(text, "openrouter_credits_total_usd") == 100.5
    assert _value(text, "openrouter_credits_used_usd") == 25.75
    assert _value(text, "openrouter_credits_remaining_usd") == pytest.approx(74.75)


def test_up_is_one_when_both_polls_succeed():
    text = _render(exp.Exporter(FakeUpstream(), clock=Clock()))
    assert _value(text, "openrouter_exporter_up") == 1.0
    assert _endpoint_ts(text, "activity") == 1_000_000.0
    assert _endpoint_ts(text, "credits") == 1_000_000.0


def test_nothing_absent_before_first_success_no_fake_zeros():
    fake = FakeUpstream(
        credits=exp.PollError("never works"),
        activity=exp.PollError("never works"),
    )
    text = _render(exp.Exporter(fake, clock=Clock()))
    assert _value(text, "openrouter_exporter_up") == 0.0
    assert "openrouter_credits_" not in text
    assert "openrouter_activity_" not in text
    assert "openrouter_exporter_last_success_timestamp_seconds{" not in text


def test_malformed_credits_is_poll_error_and_emits_no_credit_gauges():
    fake = FakeUpstream(credits={"data": {"total_credits": "lots"}})
    text = _render(exp.Exporter(fake, clock=Clock()))
    assert "openrouter_credits_" not in text
    assert _value(text, "openrouter_exporter_up") == 0.0
    assert 'endpoint="credits"' not in text
    assert _endpoint_ts(text, "activity") == 1_000_000.0


def test_malformed_credits_keeps_previous_good_values():
    clock = Clock()
    fake = FakeUpstream()
    exporter = exp.Exporter(fake, clock=clock, interval=300)
    _render(exporter)  # first scrape: good poll
    fake.responses["/credits"] = {"unexpected": True}
    clock.now += 301
    text = _render(exporter)
    assert _value(text, "openrouter_credits_remaining_usd") == pytest.approx(74.75)
    assert _value(text, "openrouter_exporter_up") == 0.0
    assert _endpoint_ts(text, "credits") == 1_000_000.0


def test_up_goes_zero_on_failure_after_success():
    clock = Clock()
    fake = FakeUpstream()
    exporter = exp.Exporter(fake, clock=clock, interval=300)
    assert _value(_render(exporter), "openrouter_exporter_up") == 1.0
    fake.responses["/activity"] = exp.PollError("HTTP 503")
    clock.now += 301
    assert _value(_render(exporter), "openrouter_exporter_up") == 0.0


def test_polls_at_most_once_per_interval():
    clock = Clock()
    fake = FakeUpstream()
    exporter = exp.Exporter(fake, clock=clock, interval=300)
    _render(exporter)
    _render(exporter)
    _render(exporter)
    assert fake.calls.count("/activity") == 1
    assert fake.calls.count("/credits") == 1
    clock.now += 300
    _render(exporter)
    assert fake.calls.count("/activity") == 2


def test_non_dict_and_missing_keys_are_poll_errors():
    for bad in ([], "x", {}, {"data": "no"}, {"data": [1]}):
        with pytest.raises(exp.PollError):
            exp.parse_activity(bad)
    for bad in (
        [],
        {},
        {"data": []},
        {"data": {"total_credits": 1}},
        {"data": {"total_credits": None, "total_usage": 1}},
    ):
        with pytest.raises(exp.PollError):
            exp.parse_credits(bad)


def test_ints_are_coerced_and_rows_missing_date_or_model_skipped():
    payload = {
        "data": [
            {"date": "2026-10-01", "model": "m", "usage": 2, "byok_usage_inference": 0},
            {"model": "m", "usage": 99, "byok_usage_inference": 0},
            {"date": "2026-10-01", "usage": 99, "byok_usage_inference": 0},
        ]
    }
    parsed = exp.parse_activity(payload)
    assert parsed == {("2026-10-01", "m"): (2.0, 0.0)}
    assert isinstance(parsed[("2026-10-01", "m")][0], float)


def test_unexpected_exception_from_fetch_does_not_escape_collect():
    fake = FakeUpstream(activity=RuntimeError("boom"))
    text = _render(exp.Exporter(fake, clock=Clock()))
    assert _value(text, "openrouter_exporter_up") == 0.0
    assert _value(text, "openrouter_credits_remaining_usd") == pytest.approx(74.75)


def test_key_never_appears_in_output_or_errors(caplog):
    def opener(request, timeout):
        raise urllib.error.HTTPError(
            request.full_url, 401, "Unauthorized", {}, io.BytesIO(FAKE_KEY.encode())
        )

    fetch = exp.make_fetch("https://example.invalid/api/v1", FAKE_KEY, opener=opener)
    with caplog.at_level("DEBUG"):
        text = _render(exp.Exporter(fetch, clock=Clock()))
    assert FAKE_KEY not in text
    assert FAKE_KEY not in caplog.text
    assert _value(text, "openrouter_exporter_up") == 0.0


def test_fetch_sends_bearer_header_and_timeout():
    seen = {}

    class Resp:
        def __enter__(self):
            return self

        def __exit__(self, *a):
            return False

        def read(self):
            return b'{"data": {"total_credits": 1, "total_usage": 0}}'

    def opener(request, timeout):
        seen["auth"] = request.get_header("Authorization")
        seen["timeout"] = timeout
        seen["url"] = request.full_url
        return Resp()

    fetch = exp.make_fetch("https://openrouter.ai/api/v1", FAKE_KEY, opener=opener)
    assert fetch("/credits") == {"data": {"total_credits": 1, "total_usage": 0}}
    assert seen == {
        "auth": f"Bearer {FAKE_KEY}",
        "timeout": 4,
        "url": "https://openrouter.ai/api/v1/credits",
    }
