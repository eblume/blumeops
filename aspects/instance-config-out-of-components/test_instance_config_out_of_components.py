"""Invariant: no instance values in component source of eblume/talos and
eblume/horkos (eblu.me hostnames, the owner name ``eblume``, 1Password
``op://`` refs), including prompt strings; comments, docstrings and
test files exempt."""

from __future__ import annotations

import pathlib
import re

KIND = "invariant"
APPLIES_TO = ["eblume/talos", "eblume/horkos"]

BANNED = re.compile(r"eblu\.me|eblume|op://", re.IGNORECASE)
COMPONENT_DIRS = ("src", "prompts", "app")


def _is_test(name: str) -> bool:
    return (
        name.endswith(
            (".test.ts", ".test.js", ".test.tsx", ".spec.ts", ".spec.js", ".spec.tsx")
        )
        or name.endswith(".py")
        and (name.startswith("test_") or name.endswith("_test.py"))
    )


def _py_segments(
    line: str, in_str: tuple[str, str] | None
) -> tuple[list[str], tuple[str, str] | None]:
    """(code segments, next string state) for one .py line.

    Line-oriented, not a parser: a triple quote opens a docstring only when
    it is the first token of its line, otherwise it is a string value whose
    content stays scannable. State is ("doc"|"val", delimiter).
    """
    if in_str is None and line.lstrip().startswith("#"):  # whole-line comment
        return [], None
    segs: list[str] = []
    buf = 0
    if in_str is not None:
        kind, delim = in_str
        j = line.find(delim)
        if j == -1:
            return ([line] if kind == "val" else []), in_str
        segs = [] if kind == "doc" else [line[:j]]  # value body is scanned
        buf = j + 3  # code resumes after the closer
    i = buf
    while i < len(line):
        if line.startswith('"""', i) or line.startswith("'''", i):
            segs.append(line[buf:i])
            delim = line[i : i + 3]
            j = line.find(delim, i + 3)
            if j != -1:  # closed on this line: prose only if it opened it
                if line[:i].strip():
                    segs.append(line[i + 3 : j])
                buf = i = j + 3
                continue
            if line[:i].strip():  # mid-line value opener: content is scannable
                segs.append(line[i + 3 :])
                return segs, ("val", delim)
            return segs, ("doc", delim)  # docstring opener: exempt until closer
        i += 1
    segs.append(line[buf:])
    return segs, None


def _ts_segments(line: str, in_block: bool) -> tuple[list[str], bool]:
    """(code segments, next block-comment state) for one TS/JS/TSX line."""
    if in_block:
        j = line.find("*/")
        if j == -1:
            return [], True
        return [line[j + 2 :]], False
    t = line.lstrip()
    if t.startswith("/*"):
        j = t.find("*/")
        if j == -1:
            return [], True
        return [line[len(line) - len(t) + j + 2 :]], False  # code after the closer
    if t.startswith(("//", "*/", "*")):  # whole-line comment / JSDoc line
        return [], False
    return [line], False


def _flag(
    violations: list[str], rel: str, lineno: int, line: str, segs: list[str]
) -> None:
    if any(BANNED.search(s) for s in segs):
        violations.append(f"{rel}:{lineno}: {line.strip()[:120]}")


def check(root: pathlib.Path) -> list[str]:
    violations: list[str] = []
    for comp in COMPONENT_DIRS:
        base = root / comp
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*")):
            if not p.is_file() or _is_test(p.name):
                continue
            rel = str(p.relative_to(root))
            lines = p.read_text(errors="replace").splitlines()
            if p.suffix == ".py":
                py_state: tuple[str, str] | None = None
                for lineno, line in enumerate(lines, 1):
                    segs, py_state = _py_segments(line, py_state)
                    _flag(violations, rel, lineno, line, segs)
            elif p.suffix in (".ts", ".js", ".tsx"):
                block_state = False
                for lineno, line in enumerate(lines, 1):
                    segs, block_state = _ts_segments(line, block_state)
                    _flag(violations, rel, lineno, line, segs)
            else:  # prompts and other files: every line is scanned
                for lineno, line in enumerate(lines, 1):
                    _flag(violations, rel, lineno, line, [line])
    return violations


def test_value_closer_does_not_exempt_later_code(tmp_path: pathlib.Path) -> None:
    # A multiline string value whose closer starts its line must not poison
    # the scanner: the banned literal after the closer is still flagged.
    p = tmp_path / "app"
    p.mkdir()
    (p / "u.py").write_text('s = """\nmulti\n"""\nX = "eblume/talos#1"\n')
    assert len(check(tmp_path)) == 1


def test_docstring_closer_line_body_stays_exempt(tmp_path: pathlib.Path) -> None:
    # A multiline docstring whose closer is mid-line: the body on that line
    # is still prose, not code.
    p = tmp_path / "app"
    p.mkdir()
    (p / "d.py").write_text('"""\nDocs: forge.ops.eblu.me and eblume#1.\n"""\n')
    assert check(tmp_path) == []
