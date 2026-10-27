#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "prometheus-client",
# ]
# ///
"""Prometheus exporter for the OpenRouter provider bill (eblume/blumeops#1981).

Polls ``/activity`` and ``/credits`` with a management key and serves the
result on /metrics. Each upstream is polled at most once per
``POLL_INTERVAL`` seconds, driven by scrapes; a failed poll keeps the last
good values, so a transient upstream error never produces fake zeros.
"""

import json
import logging
import os
import socketserver
import sys
import threading
import time
import urllib.error
import urllib.request
from wsgiref.simple_server import WSGIRequestHandler, WSGIServer, make_server

from prometheus_client import make_wsgi_app
from prometheus_client.core import CollectorRegistry, GaugeMetricFamily

LOG = logging.getLogger("openrouter-exporter")

DEFAULT_PORT = 9102
DEFAULT_BASE_URL = "https://openrouter.ai/api/v1"
POLL_INTERVAL = 300
TIMEOUT = 4
ENDPOINTS = ("activity", "credits")


class PollError(Exception):
    """An upstream poll failed; the message is safe to log (no key, no body)."""


def _number(row: dict, key: str) -> float:
    value = row.get(key)
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise PollError(f"field {key!r} is missing or not numeric")
    return float(value)


def parse_activity(payload) -> dict:
    """Map (date, model) -> (usage, byok_usage_inference), summed across endpoints."""
    rows = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(rows, list):
        raise PollError("activity response has no 'data' list")
    out: dict = {}
    for row in rows:
        if not isinstance(row, dict):
            raise PollError("activity row is not an object")
        date, model = row.get("date"), row.get("model")
        if (
            not isinstance(date, str)
            or not isinstance(model, str)
            or not date
            or not model
        ):
            continue
        usage = _number(row, "usage")
        byok = _number(row, "byok_usage_inference")
        prev_usage, prev_byok = out.get((date, model), (0.0, 0.0))
        out[(date, model)] = (prev_usage + usage, prev_byok + byok)
    return out


def parse_credits(payload) -> tuple[float, float]:
    """Return (total_credits, total_usage)."""
    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, dict):
        raise PollError("credits response has no 'data' object")
    return _number(data, "total_credits"), _number(data, "total_usage")


def make_fetch(base_url: str, key: str, opener=urllib.request.urlopen):
    """Return ``fetch(path) -> parsed JSON``. Errors carry only the status code."""

    def fetch(path: str):
        request = urllib.request.Request(
            base_url.rstrip("/") + path,
            headers={"Authorization": f"Bearer {key}", "Accept": "application/json"},
        )
        try:
            with opener(request, timeout=TIMEOUT) as response:
                body = response.read()
        except urllib.error.HTTPError as e:
            raise PollError(f"HTTP {e.code}") from None
        except urllib.error.URLError as e:
            raise PollError(f"request failed: {e.reason}") from None
        except TimeoutError:
            raise PollError("request timed out") from None
        try:
            return json.loads(body)
        except ValueError:
            raise PollError("response is not valid JSON") from None

    return fetch


class Exporter:
    """Registry collector that refreshes upstream state on each scrape."""

    def __init__(self, fetch, clock=time.time, interval: float = POLL_INTERVAL):
        self._fetch = fetch
        self._clock = clock
        self._interval = interval
        self._lock = threading.Lock()
        self._last_attempt: dict[str, float] = {}
        self._last_success: dict[str, float] = {}
        self._last_ok: dict[str, bool] = {name: False for name in ENDPOINTS}
        self._activity: dict | None = None
        self._credits: tuple[float, float] | None = None

    def refresh(self) -> None:
        with self._lock:
            now = self._clock()
            for name, parse in (
                ("activity", parse_activity),
                ("credits", parse_credits),
            ):
                last = self._last_attempt.get(name)
                if last is not None and now - last < self._interval:
                    continue
                self._last_attempt[name] = now
                try:
                    value = parse(self._fetch("/" + name))
                except PollError as e:
                    LOG.warning("%s poll failed: %s", name, e)
                    self._last_ok[name] = False
                    continue
                except Exception as e:  # noqa: BLE001 - keep the server alive whatever upstream sends
                    LOG.warning("%s poll failed: unexpected %s", name, type(e).__name__)
                    self._last_ok[name] = False
                    continue
                if name == "activity":
                    self._activity = value
                else:
                    self._credits = value
                self._last_ok[name] = True
                self._last_success[name] = now

    def collect(self):
        self.refresh()
        with self._lock:
            up = GaugeMetricFamily(
                "openrouter_exporter_up",
                "1 if the most recent poll of both OpenRouter endpoints succeeded.",
            )
            up.add_metric([], 1.0 if all(self._last_ok.values()) else 0.0)
            yield up

            success = GaugeMetricFamily(
                "openrouter_exporter_last_success_timestamp_seconds",
                "Unix time of the last successful poll of each endpoint.",
                labels=["endpoint"],
            )
            for name in ENDPOINTS:
                if name in self._last_success:
                    success.add_metric([name], self._last_success[name])
            yield success

            if self._activity is not None:
                usage = GaugeMetricFamily(
                    "openrouter_activity_usage_usd",
                    "OpenRouter usage cost in USD per date and model.",
                    labels=["date", "model"],
                )
                byok = GaugeMetricFamily(
                    "openrouter_activity_byok_usage_usd",
                    "OpenRouter BYOK inference usage in USD per date and model.",
                    labels=["date", "model"],
                )
                for (date, model), (u, b) in sorted(self._activity.items()):
                    usage.add_metric([date, model], u)
                    byok.add_metric([date, model], b)
                yield usage
                yield byok

            if self._credits is not None:
                total, used = self._credits
                yield _gauge(
                    "openrouter_credits_total_usd",
                    "Total OpenRouter credits purchased in USD.",
                    total,
                )
                yield _gauge(
                    "openrouter_credits_used_usd",
                    "OpenRouter credits used in USD.",
                    used,
                )
                yield _gauge(
                    "openrouter_credits_remaining_usd",
                    "OpenRouter credits remaining in USD (total minus used).",
                    total - used,
                )


def _gauge(name: str, doc: str, value: float) -> GaugeMetricFamily:
    family = GaugeMetricFamily(name, doc)
    family.add_metric([], value)
    return family


class ThreadingWSGIServer(socketserver.ThreadingMixIn, WSGIServer):
    daemon_threads = True


class QuietHandler(WSGIRequestHandler):
    def log_message(self, format, *args):
        pass


def main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
    )
    key = os.environ.get("OPENROUTER_MANAGEMENT_KEY", "")
    if not key:
        print(
            "OPENROUTER_MANAGEMENT_KEY is not set; refusing to start", file=sys.stderr
        )
        return 2
    port = int(os.environ.get("OPENROUTER_EXPORTER_PORT", DEFAULT_PORT))

    registry = CollectorRegistry(auto_describe=False)
    registry.register(Exporter(make_fetch(DEFAULT_BASE_URL, key)))
    app = make_wsgi_app(registry)

    server = make_server(
        "0.0.0.0",
        port,
        app,
        server_class=ThreadingWSGIServer,
        handler_class=QuietHandler,
    )
    LOG.info("serving /metrics on :%d", port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
