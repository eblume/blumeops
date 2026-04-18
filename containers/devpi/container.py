"""devpi PyPI server and caching proxy — native Dagger build.

Single-stage build: install devpi-server and devpi-web into a Python slim image.
"""

import dagger
from dagger import dag

from blumeops.containers import oci_labels

VERSION = "6.19.3"

DEVPI_WEB_VERSION = "5.0.2"
PYTHON_BASE = "python:3.12-slim"


async def build(src: dagger.Directory) -> dagger.Container:
    ctr = (
        dag.container()
        .from_(PYTHON_BASE)
        .with_exec(
            [
                "pip",
                "install",
                "--no-cache-dir",
                f"devpi-server=={VERSION}",
                f"devpi-web=={DEVPI_WEB_VERSION}",
            ]
        )
        .with_exec(
            [
                "useradd",
                "-r",
                "-u",
                "1000",
                "devpi",
            ]
        )
        .with_exec(["mkdir", "-p", "/devpi"])
        .with_exec(["chown", "devpi:devpi", "/devpi"])
        .with_file(
            "/usr/local/bin/start.sh",
            src.file("containers/devpi/start.sh"),
        )
        .with_exec(["chmod", "+x", "/usr/local/bin/start.sh"])
        .with_user("devpi")
        .with_workdir("/devpi")
        .with_exposed_port(3141)
        .with_entrypoint(["/usr/local/bin/start.sh"])
    )
    return oci_labels(
        ctr,
        title="devpi",
        description="devpi PyPI server and caching proxy",
        version=VERSION,
    )
