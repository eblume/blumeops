"""Import `main` the way the container does — from the app dir, with a DB
path it is allowed to create. `main` calls init_db() at import time, so the
env has to be set before the import, not in a fixture."""

import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault(
    "WARRANT_DB", str(Path(tempfile.mkdtemp(prefix="warrant-test-")) / "warrant.db")
)
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "app"))
