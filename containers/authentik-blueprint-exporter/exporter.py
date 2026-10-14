#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "prometheus-client",
# ]
# ///
"""Prometheus exporter for authentik blueprint instance state (eblume/blumeops#1444).

Polls ``GET /api/v3/managed/blueprints/`` as the read-only
``ci-authentik-blueprints`` service account and serves the latest snapshot
on :9101/metrics. Runs as a standalone Deployment in the ``authentik``
namespace, scraped by alloy-ringtail.

Error semantics live here, not in the alert rules: authentik's hourly
``clear_failed_blueprints`` task *deletes* failing instances and hourly
discovery re-creates them, so a ``status == "error" for 30m`` alert can
reset every hour and never fire. Each instance is therefore keyed by
``path`` (stable across re-creation; pk and name are not) and
``authentik_blueprint_status{status="error"}`` stays 1 while the path is
in error state — including polls where the instance is temporarily absent
between delete and re-create. The carried state drops two hours after the
last in-error sighting (the alert's recency window): long enough that an
hourly delete/re-create cycle always keeps an error sample inside the
window, short enough that a permanently removed blueprint stops alerting.

A 200 response with *zero* instances is a failed poll, not a healthy empty
state: list endpoints filter by object permission, so a token whose RBAC
role never bound returns an empty list rather than a 403. Such a poll
reports ``collector_up = 0`` while leaving the previous snapshot (and its
error states) in place, so a dead permission does not silence the alerts.
"""

import argparse
import json
import logging
import os
import ssl
import sys
import threading
import time
import urllib.request
from datetime import datetime
from wsgiref.simple_server import make_server

from prometheus_client import make_wsgi_app
from prometheus_client.core import REGISTRY, CollectorRegistry, GaugeMetricFamily
from prometheus_client.exposition import generate_latest

LOG = logging.getLogger("authentik-blueprint-exporter")

STATUS_PATH = "/api/v3/managed/blueprints/"

# How long a path keeps being reported in error state after its last
# in-error sighting, while it is absent from the API. Matches the alert's
# 2h recency window (see module docstring).
ERROR_CARRY_SECONDS = 2 * 3600

# A sane pagination bound: far beyond any real deployment. Guards against
# a next-pointer loop.
MAX_PAGES = 100

# authentik's list endpoints paginate; ask for a large first page so a
# poll normally fits in one round trip.
PAGE_SIZE = 500


def parse_iso(value):
    try:
        return datetime.fromisoformat(value).timestamp()
    except ValueError:
        LOG.warning("unparseable last_applied %r", value)
        return 0.0


def load_snapshot(pages):
    """Reduce one poll's pages to ``(instances, count)``.

    ``instances`` maps path -> ``{"name", "status", "last_applied"}``;
    ``count`` is the API's own total from the first page's
    ``pagination.count``.
    """
    instances = {}
    for page in pages:
        for inst in page["results"]:
            instances[inst["path"]] = {
                "name": inst.get("name", ""),
                "status": inst["status"],
                "last_applied": parse_iso(inst["last_applied"])
                if inst.get("last_applied")
                else 0.0,
            }
    count = pages[0]["pagination"]["count"] if pages else 0
    if pages and len(instances) != count:
        # The API's own total must match what we aggregated; a mismatch
        # means the list changed mid-poll or a page was malformed.
        raise RuntimeError(f"aggregated {len(instances)} instances, API count {count}")
    return instances, count


def fetch_all(base_url, token, timeout=10.0, urlopen=urllib.request.urlopen):
    """Fetch every page of the blueprint list.

    authentik's list responses carry a ``pagination`` object whose
    ``next`` is the *next page number* (``0`` on the last page), not a
    URL. Every request carries ``page_size``: dropping it on a follow-up
    would make the server default kick in, so the follow-up page covers
    the next 20 items instead of the rest of the list. Follow-ups are
    ``?page=N&page_size=PAGE_SIZE`` until ``pagination.next`` is ``0``.
    """
    root = f"{base_url.rstrip('/')}{STATUS_PATH}"
    url = f"{root}?page_size={PAGE_SIZE}"
    pages = []
    while True:
        if len(pages) >= MAX_PAGES:
            raise RuntimeError(f"pagination exceeded {MAX_PAGES} pages")
        req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
        with urlopen(
            req, timeout=timeout, context=ssl.create_default_context()
        ) as resp:
            page = json.loads(resp.read().decode("utf-8"))
        pages.append(page)
        cur, nxt = page["pagination"]["current"], page["pagination"]["next"]
        if not nxt:
            return pages
        if nxt <= cur:
            # A next pointer that does not advance would loop forever
            # (and never return a 0); fail the poll instead.
            raise RuntimeError(
                f"pagination.next {nxt} did not advance past current {cur}"
            )
        url = f"{root}?page={nxt}&page_size={PAGE_SIZE}"


class BlueprintState:
    """Holds the latest poll result and the carried error states."""

    def __init__(self):
        self._lock = threading.Lock()
        self.instances = {}
        self.up = 0
        self.error_at = {}  # path -> last poll time seen in error state
        self.last_poll = 0.0

    def record_poll(self, instances, count, now=None):
        """Apply one completed poll (or its failure) to the snapshot.

        An API failure and an empty list both arrive as no instances; both
        map to ``collector_up = 0`` while keeping the previous snapshot
        and error states, so a dead poll cannot silence the alerts.
        Returns the number of paths currently reported in error state.
        """
        now = time.time() if now is None else now
        with self._lock:
            self.last_poll = now
            if count == 0 or not instances:
                self.up = 0
                return len(self.error_at)
            self.up = 1
            self.instances = instances
            # A path seen healthy exits error state immediately. A path
            # that is absent (deleted by clear_failed_blueprints, not yet
            # re-created, or removed for good) keeps its error mark for
            # ERROR_CARRY_SECONDS after the last in-error sighting, so a
            # delete/re-create cycle cannot reset the alert, then falls
            # out and the alert's recency window can resolve it.
            new_errors = {
                path: now
                for path, inst in instances.items()
                if inst["status"] == "error"
            }
            carried = {
                path: seen
                for path, seen in self.error_at.items()
                if path not in instances and now - seen < ERROR_CARRY_SECONDS
            }
            self.error_at = new_errors | carried
            return len(self.error_at)

    def render(self):
        """Render the current snapshot as Prometheus text (self-test mode)."""
        with self._lock:
            families = _families(
                self.up,
                {p: dict(i) for p, i in self.instances.items()},
                dict(self.error_at),
                self.last_poll,
            )
        registry = CollectorRegistry()
        registry.register(_InlineCollector(families))
        return generate_latest(registry).decode("utf-8")


class _InlineCollector:
    def __init__(self, families):
        self._families = families

    def collect(self):
        return self._families


def _families(up, instances, error_at, last_poll):
    status = GaugeMetricFamily(
        "authentik_blueprint_status",
        "Current state of each blueprint instance, keyed by path. "
        "status=error stays 1 across delete/re-create cycles.",
        labels=["name", "path", "status"],
    )
    last_applied = GaugeMetricFamily(
        "authentik_blueprint_last_applied_timestamp_seconds",
        "Last apply, as unix time (runbook-only metric).",
        labels=["name", "path"],
    )
    for path, inst in sorted(instances.items()):
        shown = "error" if path in error_at else inst["status"]
        status.add_metric([inst["name"], path, shown], 1)
        last_applied.add_metric([inst["name"], path], inst["last_applied"])
    for path in sorted(set(error_at) - set(instances)):
        status.add_metric(["", path, "error"], 1)
    up_fam = GaugeMetricFamily(
        "authentik_blueprint_collector_up",
        "1 if the last poll succeeded and reported at least one instance.",
    )
    up_fam.add_metric([], up)
    count_fam = GaugeMetricFamily(
        "authentik_blueprint_instances",
        "Blueprint instances reported by the last successful poll.",
    )
    count_fam.add_metric([], len(instances))
    poll_fam = GaugeMetricFamily(
        "authentik_blueprint_last_poll_timestamp_seconds",
        "Unix time of the last completed poll (runbook freshness).",
    )
    poll_fam.add_metric([], last_poll)
    return [status, last_applied, up_fam, count_fam, poll_fam]


class BlueprintCollector:
    """Wiring for the /metrics scrape: serves the live snapshot."""

    def __init__(self, state):
        self._state = state

    def collect(self):
        with self._state._lock:
            return _families(
                self._state.up,
                {p: dict(i) for p, i in self._state.instances.items()},
                dict(self._state.error_at),
                self._state.last_poll,
            )


def poll_loop(state, base_url, token, interval):
    while True:
        try:
            instances, count = load_snapshot(fetch_all(base_url, token))
            error_count = state.record_poll(instances, count)
            LOG.info(
                "poll ok: %d instances, %d in error state",
                count,
                error_count,
            )
        except Exception:
            LOG.exception("poll failed")
            state.record_poll({}, 0)
        time.sleep(interval)


def self_test(path, timestamp):
    """Replay a fixture poll to stdout and exit.

    The fixture file is ``{"pages": [...]}`` (one poll, in page order);
    this doubles as the fixture-replay unit test for the metric shape.
    """
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    pages = data["pages"] if isinstance(data, dict) else [data]
    state = BlueprintState()
    state.record_poll(*load_snapshot(pages), now=timestamp)
    sys.stdout.write(state.render())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--self-test",
        metavar="FIXTURE_JSON",
        help="replay a fixture poll response to stdout and exit",
    )
    parser.add_argument(
        "--port", type=int, default=int(os.environ.get("EXPORTER_PORT", "9101"))
    )
    args = parser.parse_args()
    logging.basicConfig(
        level=logging.INFO,
        stream=sys.stdout,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    if args.self_test:
        self_test(args.self_test, time.time())
        return

    base_url = os.environ.get("AUTHENTIK_BASE_URL", "http://authentik:9000")
    token = os.environ.get("AUTHENTIK_CI_AUTHENTIK_BLUEPRINTS_TOKEN", "")
    interval = int(os.environ.get("POLL_INTERVAL_SECONDS", "60"))
    if not token:
        LOG.warning("AUTHENTIK_CI_AUTHENTIK_BLUEPRINTS_TOKEN is empty")

    state = BlueprintState()
    REGISTRY.register(BlueprintCollector(state))
    threading.Thread(
        target=poll_loop, args=(state, base_url, token, interval), daemon=True
    ).start()
    make_server("", args.port, make_wsgi_app()).serve_forever()


if __name__ == "__main__":
    main()
