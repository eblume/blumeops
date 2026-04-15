"""Transmission Prometheus exporter — native Dagger build.

Minimal collect-on-scrape exporter using uv to resolve deps at runtime.
"""

import dagger
from dagger import dag

from blumeops.containers import oci_labels

VERSION = "1.0.1"

PYTHON_BASE = "python:3.14-alpine3.23"
UV_IMAGE = "ghcr.io/astral-sh/uv:0.11.6"


async def build(src: dagger.Directory) -> dagger.Container:
    ctr = (
        dag.container()
        .from_(PYTHON_BASE)
        .with_file("/usr/local/bin/uv", dag.container().from_(UV_IMAGE).file("/uv"))
        .with_env_variable("PYTHONUNBUFFERED", "1")
        .with_env_variable("UV_CACHE_DIR", "/tmp/uv-cache")
        .with_workdir("/app")
        .with_file(
            "/app/exporter.py", src.file("containers/transmission-exporter/exporter.py")
        )
        .with_exposed_port(19091)
        .with_user("65534:65534")
        .with_default_args(args=["uv", "run", "--script", "/app/exporter.py"])
    )
    return oci_labels(
        ctr,
        title="Transmission Exporter",
        description="Prometheus exporter for Transmission BitTorrent client",
        version=VERSION,
    )
