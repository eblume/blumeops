#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "prometheus-client",
#     "transmission-rpc",
# ]
# ///
"""Minimal Prometheus exporter for Transmission, using collect-on-scrape."""

import os
import sys
import urllib.parse
from wsgiref.simple_server import make_server

from prometheus_client import make_wsgi_app
from prometheus_client.core import REGISTRY, GaugeMetricFamily
from transmission_rpc import Client


def parse_addr(addr: str) -> dict:
    """Parse TRANSMISSION_ADDR into kwargs for transmission_rpc.Client."""
    parsed = urllib.parse.urlparse(addr)
    kwargs: dict = {}
    if parsed.hostname:
        kwargs["host"] = parsed.hostname
    if parsed.port:
        kwargs["port"] = parsed.port
    if parsed.scheme == "https":
        kwargs["protocol"] = "https"
    if parsed.path and parsed.path != "/":
        kwargs["path"] = parsed.path.strip("/")
    if parsed.username:
        kwargs["username"] = parsed.username
    if parsed.password:
        kwargs["password"] = parsed.password
    return kwargs


class TransmissionCollector:
    def __init__(self, client_kwargs: dict):
        self._client_kwargs = client_kwargs

    def collect(self):
        try:
            client = Client(**self._client_kwargs)
            session = client.session_stats()
            torrents = client.get_torrents()
        except Exception as e:
            print(f"Error collecting metrics: {e}", file=sys.stderr)
            return

        yield _gauge(
            "transmission_session_stats_download_speed_bytes",
            "Current download speed in bytes/s",
            session.download_speed,
        )
        yield _gauge(
            "transmission_session_stats_upload_speed_bytes",
            "Current upload speed in bytes/s",
            session.upload_speed,
        )
        yield _gauge(
            "transmission_session_stats_torrents_active",
            "Number of active torrents",
            session.active_torrent_count,
        )
        yield _gauge(
            "transmission_session_stats_torrents_total",
            "Total number of torrents",
            session.torrent_count,
        )

        downloaded = GaugeMetricFamily(
            "transmission_session_stats_downloaded_bytes",
            "Total bytes downloaded",
            labels=["type"],
        )
        downloaded.add_metric(["cumulative"], session.cumulative_stats.downloaded_bytes)
        yield downloaded

        uploaded = GaugeMetricFamily(
            "transmission_session_stats_uploaded_bytes",
            "Total bytes uploaded",
            labels=["type"],
        )
        uploaded.add_metric(["cumulative"], session.cumulative_stats.uploaded_bytes)
        yield uploaded

        t_download = GaugeMetricFamily(
            "transmission_torrent_download_bytes",
            "Torrent total downloaded bytes",
            labels=["name"],
        )
        t_upload = GaugeMetricFamily(
            "transmission_torrent_upload_bytes",
            "Torrent total uploaded bytes",
            labels=["name"],
        )
        t_ratio = GaugeMetricFamily(
            "transmission_torrent_ratio",
            "Torrent upload ratio",
            labels=["name"],
        )
        t_uploaded_ever = GaugeMetricFamily(
            "transmission_torrent_uploaded_ever",
            "Torrent total uploaded ever in bytes",
            labels=["name"],
        )
        t_done = GaugeMetricFamily(
            "transmission_torrent_done",
            "Torrent percent done (0.0-1.0)",
            labels=["name"],
        )

        for t in torrents:
            name = t.name or "unknown"
            t_download.add_metric([name], t.total_size * t.percent_done)
            t_upload.add_metric([name], t.uploaded_ever)
            t_ratio.add_metric([name], t.ratio)
            t_uploaded_ever.add_metric([name], t.uploaded_ever)
            t_done.add_metric([name], t.percent_done)

        yield t_download
        yield t_upload
        yield t_ratio
        yield t_uploaded_ever
        yield t_done


def _gauge(name: str, doc: str, value: float) -> GaugeMetricFamily:
    g = GaugeMetricFamily(name, doc)
    g.add_metric([], value)
    return g


def main():
    addr = os.environ.get("TRANSMISSION_ADDR", "http://localhost:9091")
    port = int(os.environ.get("EXPORTER_PORT", "19091"))

    client_kwargs = parse_addr(addr)
    REGISTRY.register(TransmissionCollector(client_kwargs))

    print(f"Listening on :{port}, scraping {addr}")
    httpd = make_server("", port, make_wsgi_app())
    httpd.serve_forever()


if __name__ == "__main__":
    main()
