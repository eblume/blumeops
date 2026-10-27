"""The forge-sources-only invariant (aspects/forge-sources-only/ASPECT.md).

Every source fetch in Nix expressions, flake inputs and Dockerfiles resolves
to a forge-hosted source, to a rule class (PyPI, nixpkgs), or to an
entry in the reviewed exception list at ``aspects/forge-sources-only/
exceptions.json`` under the checked root. An exception that matches no fetch
is stale and fails, so the list only holds live entries.
"""

from __future__ import annotations

import bisect
import json
import os
import pathlib
import re

KIND = "invariant"
APPLIES_TO = ["eblume/blumeops"]

EXCEPTIONS_REL = "aspects/forge-sources-only/exceptions.json"
EXCEPTION_KINDS = ("exceptional", "pending-removal")
EXCEPTION_KEYS = {"match", "kind", "reason", "tracking"}

# Allowed by rule: forge-hosted sources, PyPI packages, nixpkgs (source
# tarballs and flake input). Other registries become classes here only when one
# appears.
ALLOWED_PREFIXES = (
    "https://forge.ops.eblu.me/",
    "https://files.pythonhosted.org/packages/",
    "https://github.com/NixOS/nixpkgs/",
)

FLAKE_SCHEME = re.compile(r"^(?:github:|gitlab:|git\+|git://|ssh://)")
GO_MODULE = re.compile(r"github\.com/[\w.-]+/[\w.-]+@v[\w.+-]+")
FETCH_FROM_FORGE = re.compile(r"\bfetchFrom(GitHub|GitLab)\b")
DOCKER_DOWNLOAD = re.compile(r"\b(?:curl|wget)\b[^\n]*?(https?://[^\s'\"\\)<>]+)")
GIT_CLONE = re.compile(r"\bgit\s+clone\b[^\n]*?((?:https?|git)://[^\s'\"\\)<>]+)")
URL_ATTR_BEFORE = re.compile(r"\burl\s*=\s*$")
FETCH_BEFORE = re.compile(r"\bfetch\w*\s*$")
PIN_KEY = re.compile(r"\b(?:hash|sha256|sha512|outputHash|narHash|rev|ref|tag)\s*=")
BLOCK_WINDOW = 5000


Source = tuple[str, int, str]  # (repo-relative path, line, raw URL)


def _lex(text: str) -> tuple[str, list[tuple[int, str]]]:
    """Return (code, strings): ``code`` is ``text`` with comments blanked (same
    length, newlines kept); ``strings`` lists the (offset, value) of each string
    literal, with ``\\0`` standing for an interpolation.
    """
    out = list(text)
    strings: list[tuple[int, str]] = []
    stack: list[dict] = []
    n = len(text)
    i = 0

    def blank(a: int, b: int) -> None:
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        top = stack[-1] if stack else None
        if top is not None and top["kind"] != "interp":
            buf = top["buf"]
            if top["kind"] == "dq":
                if text[i] == "\\":
                    buf.append(text[i : i + 2])
                    i += 2
                    continue
                if text[i] == '"':
                    strings.append((top["start"], "".join(buf)))
                    stack.pop()
                    i += 1
                    continue
            else:  # indented string ''...''
                if text.startswith("''", i):
                    nxt = text[i + 2 : i + 3]
                    if nxt in ("$", "'", "\\"):
                        buf.append(nxt)
                        i += 3
                        continue
                    strings.append((top["start"], "".join(buf)))
                    stack.pop()
                    i += 2
                    continue
            if text.startswith("${", i):
                buf.append("\0")
                stack.append({"kind": "interp", "start": i, "buf": [], "depth": 0})
                i += 2
                continue
            buf.append(text[i])
            i += 1
            continue

        # Code context (top level, or inside a ${} interpolation).
        if text[i] == "#":
            j = text.find("\n", i)
            j = n if j < 0 else j
            blank(i, j)
            i = j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            blank(i, j)
            i = j
            continue
        if top is not None:  # interpolation: track braces to find its close
            if text[i] == "{":
                top["depth"] += 1
            elif text[i] == "}":
                if top["depth"] == 0:
                    stack.pop()
                    i += 1
                    continue
                top["depth"] -= 1
        if text[i] == '"':
            stack.append({"kind": "dq", "start": i, "buf": [], "depth": 0})
            i += 1
        elif text.startswith("''", i):
            stack.append({"kind": "sq", "start": i, "buf": [], "depth": 0})
            i += 2
        else:
            i += 1
    return "".join(out), strings


def _enclosing_block(code: str, pos: int) -> tuple[int, int]:
    """Span of the innermost ``{...}`` that contains ``pos`` (bounded)."""
    lo = max(0, pos - BLOCK_WINDOW)
    depth = 0
    for k in range(pos - 1, lo - 1, -1):
        if code[k] == "}":
            depth += 1
        elif code[k] == "{":
            if depth == 0:
                hi = min(len(code), pos + BLOCK_WINDOW)
                d = 0
                for m in range(k, hi):
                    if code[m] == "{":
                        d += 1
                    elif code[m] == "}":
                        d -= 1
                        if d == 0:
                            return k, m + 1
                return k, hi
            depth -= 1
    return max(0, pos - BLOCK_WINDOW), min(len(code), pos + BLOCK_WINDOW)


def _is_fetch_url(rel: str, code: str, attr_pos: int) -> bool:
    """A ``url =`` attribute is a source fetch when its attrset is a fetcher
    call (``pkgs.fetchurl {``) or pins content (carries a hash or rev)."""
    if rel.endswith("flake.nix"):
        return True
    open_, close = _enclosing_block(code, attr_pos)
    if PIN_KEY.search(code[open_:close]):
        return True
    return bool(FETCH_BEFORE.search(code[max(0, open_ - 60) : open_]))


def _normalize(raw: str) -> str:
    if raw.startswith("github:"):
        return "https://github.com/" + raw[len("github:") :]
    if raw.startswith("gitlab:"):
        return "https://gitlab.com/" + raw[len("gitlab:") :]
    return re.sub(r"^git\+", "", raw)


def _matches(match: str, norm: str) -> bool:
    if not norm.startswith(match):
        return False
    return len(norm) == len(match) or norm[len(match)] in "/.?@#"


def _nix_sources(rel: str, text: str) -> list[Source]:
    code, strings = _lex(text)
    starts = [m.end() for m in re.finditer(r"\n", text)]
    found: list[Source] = []
    # fetchFromGitHub/GitLab name owner/repo, not a URL, so no exception can
    # match them: they are violations, and the fix is a fetchgit forge mirror.
    for m in FETCH_FROM_FORGE.finditer(code):
        found.append((rel, bisect.bisect_right(starts, m.start()) + 1, m.group(0)))
    for start, value in strings:
        line = bisect.bisect_right(starts, start) + 1
        if FLAKE_SCHEME.match(value) and " " not in value:
            found.append((rel, line, value))
        elif GO_MODULE.fullmatch(value):
            found.append((rel, line, "https://" + value.split("@", 1)[0]))
        elif value.startswith(("https://", "http://")):
            before = code[max(0, start - 80) : start]
            attr = URL_ATTR_BEFORE.search(before)
            if attr:
                attr_pos = max(0, start - 80) + attr.start()
                if _is_fetch_url(rel, code, attr_pos):
                    found.append((rel, line, value))
            elif FETCH_BEFORE.search(before):
                found.append((rel, line, value))
        for m in GIT_CLONE.finditer(value):
            found.append((rel, line, m.group(1)))
    return found


def _dockerfile_sources(rel: str, text: str) -> list[Source]:
    found: list[Source] = []
    for n, line in enumerate(text.splitlines(), start=1):
        for m in GIT_CLONE.finditer(line):
            found.append((rel, n, m.group(1)))
        for m in DOCKER_DOWNLOAD.finditer(line):
            found.append((rel, n, m.group(1)))
        add = re.match(r"\s*ADD\s+(https?://\S+)", line)
        if add:
            found.append((rel, n, add.group(1)))
    return found


def _files(root: pathlib.Path):
    for dirpath, dirnames, filenames in os.walk(root):
        here = pathlib.Path(dirpath)
        dirnames[:] = sorted(
            d
            for d in dirnames
            if d not in (".git", "fixtures") and not (here == root and d == "aspects")
        )
        for name in sorted(filenames):
            if name.endswith(".nix") or name.startswith(
                ("Dockerfile", "Containerfile")
            ):
                yield here / name


def _sources(root: pathlib.Path) -> list[Source]:
    found: list[Source] = []
    for path in _files(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        if path.name.endswith(".nix"):
            found.extend(_nix_sources(rel, text))
        else:
            found.extend(_dockerfile_sources(rel, text))
    return found


def _load_exceptions(root: pathlib.Path) -> tuple[list[dict], list[str]]:
    path = root / EXCEPTIONS_REL
    if not path.is_file():
        return [], []
    try:
        entries = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [], [f"{EXCEPTIONS_REL}: not valid JSON: {exc}"]
    if not isinstance(entries, list):
        return [], [f"{EXCEPTIONS_REL}: must be a JSON list of entries"]
    valid: list[dict] = []
    problems: list[str] = []
    for i, entry in enumerate(entries):
        where = f"{EXCEPTIONS_REL}: entry {i}"
        if not isinstance(entry, dict):
            problems.append(f"{where}: must be an object")
            continue
        match = entry.get("match")
        if not isinstance(match, str) or not match.startswith("https://"):
            problems.append(f"{where}: 'match' must be an https:// URL prefix")
            continue
        where = f"{where} ({match})"
        if set(entry) - EXCEPTION_KEYS:
            problems.append(
                f"{where}: unknown keys {sorted(set(entry) - EXCEPTION_KEYS)}"
            )
        kind = entry.get("kind")
        if kind not in EXCEPTION_KINDS:
            problems.append(
                f"{where}: 'kind' must be one of {list(EXCEPTION_KINDS)}, got {kind!r}"
            )
        reason = entry.get("reason")
        if not isinstance(reason, str) or not reason.strip():
            problems.append(f"{where}: missing 'reason' (one line)")
        if kind == "pending-removal" and not str(entry.get("tracking", "")).strip():
            problems.append(f"{where}: pending-removal needs a 'tracking' reference")
        valid.append({"match": match})
    return valid, problems


def check(root: pathlib.Path) -> list[str]:
    exceptions, violations = _load_exceptions(root)
    used: set[int] = set()
    for src in _sources(root):
        path, line, raw = src
        norm = _normalize(raw)
        if norm.startswith(ALLOWED_PREFIXES):
            continue
        hit = next(
            (i for i, e in enumerate(exceptions) if _matches(e["match"], norm)), None
        )
        if hit is None:
            violations.append(
                f"{path}:{line}: {raw} — not a forge mirror or a rule class, "
                "and has no entry in the exception list"
            )
        else:
            used.add(hit)
    for i, e in enumerate(exceptions):
        if i not in used:
            violations.append(
                f"{EXCEPTIONS_REL}: {e['match']} matches no fetch — remove the entry"
            )
    return violations
