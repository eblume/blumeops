"""The prek-present invariant: the repo root has a prek.toml that parses as TOML."""

from __future__ import annotations

import pathlib
import tomllib

KIND = "invariant"


def check(root: pathlib.Path) -> list[str]:
    path = root / "prek.toml"
    if not path.is_file():
        return ["prek.toml missing at repo root"]
    try:
        tomllib.loads(path.read_text())
    except tomllib.TOMLDecodeError as exc:
        return [f"prek.toml does not parse as TOML: {exc}"]
    return []
