"""Grafana dashboard sidecar — native Dagger build.

Two-stage build: Python venv (builder), Python Alpine (runtime).
Source cloned from forge mirror.
"""

import dagger
from dagger import dag

from blumeops.containers import clone_from_forge, oci_labels

VERSION = "2.6.0"

PYTHON_BASE = "python:3.14-alpine3.23"


async def build(src: dagger.Directory) -> dagger.Container:
    source = clone_from_forge("kiwigrid-grafana-sidecar", VERSION)

    # Stage 1: Build Python venv with dependencies
    builder = (
        dag.container()
        .from_(PYTHON_BASE)
        .with_exec(["apk", "add", "--no-cache", "gcc", "musl-dev"])
        .with_workdir("/app")
        .with_exec(
            ["python", "-m", "venv", ".venv"],
        )
        .with_exec(
            [".venv/bin/pip", "install", "--no-cache-dir", "-U", "pip", "setuptools"],
        )
        .with_file("/app/pyproject.toml", source.file("pyproject.toml"))
        .with_directory("/app/src", source.directory("src"))
        .with_exec([".venv/bin/pip", "install", "--no-cache-dir", "."])
        # Strip test dirs and bytecode from venv to shrink the image
        .with_exec(
            [
                "sh",
                "-c",
                "find /app/.venv"
                " \\( -type d -a -name test -o -name tests \\)"
                " -o \\( -type f -a -name '*.pyc' -o -name '*.pyo' \\)"
                " -exec rm -rf {} +",
            ]
        )
    )

    # Stage 2: Runtime
    runtime = dag.container().from_(PYTHON_BASE)
    runtime = oci_labels(
        runtime,
        title="Grafana Sidecar",
        description="K8s sidecar to sync ConfigMap dashboards into Grafana",
        version=VERSION,
    )
    return (
        runtime.with_env_variable("PYTHONUNBUFFERED", "1")
        .with_workdir("/app")
        .with_directory("/app/.venv", builder.directory("/app/.venv"))
        .with_env_variable("PATH", "/app/.venv/bin:$PATH")
        .with_user("65534:65534")
        .with_default_args(args=["python", "-u", "-m", "sidecar"])
    )
