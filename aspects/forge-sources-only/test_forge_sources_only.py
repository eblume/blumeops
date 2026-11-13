"""The forge-sources-only invariant (aspects/forge-sources-only/ASPECT.md).

Every source fetch in Nix expressions, flake inputs and Dockerfiles resolves
to a forge-hosted source owned by an allowed owner, to a rule class (PyPI,
nixpkgs), or to an entry in the reviewed exception list at
``aspects/forge-sources-only/exceptions.json`` under the checked root. An
exception that matches no fetch is stale and fails, so the list only holds live entries.
"""

from __future__ import annotations

import bisect
import json
import os
import pathlib
import re
import shlex

import pytest

KIND = "invariant"
APPLIES_TO = ["eblume/blumeops"]

EXCEPTIONS_REL = "aspects/forge-sources-only/exceptions.json"
EXCEPTION_KINDS = ("exceptional", "pending-removal")
EXCEPTION_KEYS = {"match", "kind", "reason", "tracking"}

# Allowed by rule: forge-hosted sources, PyPI packages, nixpkgs (source
# tarballs and flake input). Other registries become classes here only when one
# appears.
ALLOWED_PREFIXES = (
    "https://files.pythonhosted.org/packages/",
    "https://github.com/NixOS/nixpkgs/",
)
# BorgBase Borg repo locators (ssh, key-authenticated) are backup destinations,
# not fetched sources. Exactly `ssh://<label>@<label>.repo.borgbase.com/./repo`:
# the userinfo must equal the host's first label. Reviewed in eblume/blumeops#2353.
BORGBASE_REPO = re.compile(r"ssh://([a-z0-9]+)@\1\.repo\.borgbase\.com/\./repo")
FORGE_HOSTS = r"forge(?:\.ops)?\.eblu\.me"
# Owners the talos bot cannot write. Keep in step with
# mise-tasks/validate-argocd-apps (see the agreement test).
ALLOWED_OWNERS = ("eblume", "mirrors")
# Userinfo excludes ?#\ too, so `https://evil.example?@forge...` is not a forge
# host. The host is case-insensitive.
FORGE_SOURCE = re.compile(
    rf"^(?:https|ssh)://(?:[^@/?#\\]+@)?{FORGE_HOSTS}(?::\d+)?/([^/?#]+)",
    re.IGNORECASE,
)
# Dot segments and percent-encoded dots/slashes resolve to a different owner's path.
FORGE_PATH_EVASION = re.compile(r"\.\.|/\.(?=[/?#]|$)|%2[ef]", re.IGNORECASE)

FLAKE_SCHEME = re.compile(r"^(?:github:|gitlab:|git\+|git://|ssh://)", re.IGNORECASE)
# scp-style `[user@]host:path`; `(?!//)` keeps real `scheme://` URLs out.
SCP_LIKE = re.compile(r"^(?:([^@\s/:]+)@)?([^@\s/:]+):(?!//)(\S+)$")
GO_MODULE = re.compile(r"github\.com/[\w.-]+/[\w.-]+@v[\w.+-]+")
FETCH_FROM_FORGE = re.compile(r"\bfetchFrom(GitHub|GitLab|Gitea|Forgejo)\b")
DOCKER_DOWNLOAD = re.compile(
    r"\b(?:curl|wget)\b[^\n]*?(https?://[^\s'\"\\)<>]+)", re.IGNORECASE
)
DOCKER_TOOL_TAIL = re.compile(r"\b(?:curl|wget)\b([^\n;&|<>]*)", re.IGNORECASE)
# A bare `host.tld/...` token: curl and wget fetch it as http, with no scheme to grade.
SCHEMELESS_HOST = re.compile(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+(?::\d+)?(?:[/?#]|$)")
DOWNLOAD_VALUE_FLAGS = frozenset(
    {"-o", "--output", "-O", "-H", "--header", "-A", "-u", "-d", "-X", "-P", "-U"}
)
# `git` global options (`-C dir`, `-c k=v`, `--git-dir=...`) may precede `clone`.
GIT_GLOBAL_OPTS = r"(?:\s+(?:-[Cc]\s*\S+|--[\w-]+(?:=\S*)?))*"
GIT_CLONE = re.compile(
    rf"\bgit{GIT_GLOBAL_OPTS}\s+clone\b[^\n]*?((?:https?|git|ssh)://[^\s'\"\\)<>]+)",
    re.IGNORECASE,
)
# `git clone` argument tail (one shell command), and the scp-style candidates in it.
CLONE_TAIL = re.compile(rf"\bgit{GIT_GLOBAL_OPTS}\s+clone\b([^\n;&|]*)", re.IGNORECASE)
# A url.<base>.insteadOf= rewrite can send a clone to an unlisted host, so a
# clone that carries one is a violation.
GIT_INSTEADOF = re.compile(r"\burl\.\S+\.insteadof", re.IGNORECASE)
ADD_SOURCE = re.compile(r"\s*ADD\s+(?:--[\w-]+(?:=\S*)?\s+)*(\S+)", re.IGNORECASE)
ADD_REMOTE = re.compile(
    r"(?:https?|git|ssh)://|(?:[^@\s/:]+@)?[^@\s/:]+:(?!//)", re.IGNORECASE
)
CLONE_ARG = re.compile(r"^(?:[^@\s/:]+@)?[^@\s/:]+:(?!//)")
CLONE_VALUE_FLAGS = frozenset(
    {
        "-b",
        "--branch",
        "--depth",
        "--filter",
        "-o",
        "--origin",
        "-c",
        "--config",
        "--reference",
        "--template",
        "-j",
        "--jobs",
        "--separate-git-dir",
        "--shallow-since",
        "--shallow-exclude",
        "-u",
        "--upload-pack",
        "--server-option",
    }
)
# Attrset fetchers: the attrset names the forge source instead of a url.
FETCH_CALL = re.compile(r"\bfetch(?:Tree|Git)\b")
FETCH_ARG_OPEN = re.compile(r"\s*\{")
FETCH_KEYS = re.compile(r"\b(?:type|owner|repo|host)\b")
NIX_STRING_ATTR = re.compile(r'\s*"((?:[^"\\$]|\\.|\$(?!\{))*)"\s*;')
FORGE_HOST_DEFAULT = {
    "github": "github.com",
    "gitlab": "gitlab.com",
    "sourcehut": "git.sr.ht",
}
URL_TYPES = ("git", "tarball", "file")
HOST_PART = re.compile(r"[A-Za-z0-9.-]+(?::\d+)?")
OWNER_PART = re.compile(r"[\w.~-]+")
URL_ATTR_BEFORE = re.compile(r'"?\burl"?\s*=\s*$')
URLS_ATTR_BEFORE = re.compile(r'"?\burls"?\s*=\s*\[$')
URLS_KEY = re.compile(r'"?\burls"?\s*=(?!=)')
URLS_LIST = re.compile(r'\s*\[(?:\s*"(?:[^"\\]|\\.)*")*\s*\]\s*;')
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


def _mask_strings(code: str) -> str:
    """``code`` with the contents of string literals blanked (delimiters and
    newlines kept), so braces and keywords inside strings are invisible. Code
    inside ``${...}`` interpolations is still code.
    """
    out = list(code)
    n = len(code)
    # Stack entries: "dq" / "sq" for open strings, or ["interp", depth].
    stack: list = []
    i = 0

    def blank(k: int) -> None:
        if out[k] != "\n":
            out[k] = " "

    while i < n:
        top = stack[-1] if stack else None
        in_string = top in ("dq", "sq")
        if top == "dq":
            if code[i] == "\\":
                for k in range(i, min(i + 2, n)):
                    blank(k)
                i += 2
                continue
            if code[i] == '"':
                stack.pop()
                i += 1
                continue
        elif top == "sq":
            if code.startswith("''", i):
                if code[i + 2 : i + 3] in ("$", "'", "\\"):
                    for k in range(i, min(i + 3, n)):
                        blank(k)
                    i += 3
                    continue
                stack.pop()
                i += 2
                continue
        elif top is not None and code[i] == "}":  # close an interpolation
            if top[1] == 0:
                stack.pop()
                i += 1
                continue
            top[1] -= 1
        elif top is not None and code[i] == "{":
            top[1] += 1
        if in_string:
            if code.startswith("${", i):
                stack.append(["interp", 0])
                i += 2
                continue
            blank(i)
            i += 1
            continue
        # Code context (top level or inside an interpolation).
        if code[i] == '"':
            stack.append("dq")
        elif code.startswith("''", i):
            stack.append("sq")
            i += 2
            continue
        i += 1
    return "".join(out)


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
    # Before the scp form: `github:owner/repo` also matches SCP_LIKE.
    if raw.lower().startswith("github:"):
        return "https://github.com/" + raw[len("github:") :]
    if raw.lower().startswith("gitlab:"):
        return "https://gitlab.com/" + raw[len("gitlab:") :]
    scp = SCP_LIKE.match(raw)
    if scp:
        user, host, path = scp.groups()
        path = path.removeprefix("/")
        raw = f"ssh://{user + '@' if user else ''}{host}/{path}"
    raw = re.sub(r"^git\+", "", raw, flags=re.IGNORECASE)
    return re.sub(r"^[A-Za-z][\w+.-]*://", lambda m: m.group(0).lower(), raw)


def _matches(match: str, norm: str) -> bool:
    if not norm.startswith(match):
        return False
    return len(norm) == len(match) or norm[len(match)] in "/.?@#"


def _nix_sources(rel: str, text: str) -> list[Source]:
    code, strings = _lex(text)
    masked = _mask_strings(code)
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
        elif value.lower().startswith(("https://", "http://")) or SCP_LIKE.match(value):
            attr_pos = _url_attr_pos(code, masked, start)
            if attr_pos is not None:
                if _is_fetch_url(rel, code, attr_pos):
                    found.append((rel, line, value))
            elif FETCH_BEFORE.search(code[max(0, start - 80) : start]):
                found.append((rel, line, value))
        for raw in _shell_sources(value, docker=False):
            found.append((rel, line, raw))
    for m in URLS_KEY.finditer(code):
        if not URLS_LIST.match(code, m.end()):
            line = bisect.bisect_right(starts, m.start()) + 1
            found.append((rel, line, "urls is not a plain list of string literals"))
    _fetch_attrsets(rel, code, masked, starts, found)
    return found


def _url_attr_pos(code: str, masked: str, start: int) -> int | None:
    """Offset of the ``url`` or ``urls`` key that gives the string at ``start``,
    or None. A list element is reached by walking back over earlier string
    elements and whitespace to the ``[``.
    """
    base = max(0, start - 80)
    attr = URL_ATTR_BEFORE.search(code[base:start])
    if attr:
        return base + attr.start()
    j = start
    while True:
        while j > 0 and masked[j - 1].isspace():
            j -= 1
        if j >= 1 and masked[j - 1] == '"':
            j = masked.rfind('"', 0, j - 1)
        elif j >= 2 and masked[j - 2 : j] == "''":
            j = masked.rfind("''", 0, j - 2)
        else:
            break
        if j < 0:
            return None
    if j == 0 or masked[j - 1] != "[":
        return None
    base = max(0, j - 80)
    attr = URLS_ATTR_BEFORE.search(code[base:j])
    return base + attr.start() if attr else None


def _matching_brace(code: str, open_: int) -> int | None:
    depth = 0
    for k in range(open_, len(code)):
        if code[k] == "{":
            depth += 1
        elif code[k] == "}":
            depth -= 1
            if depth == 0:
                return k
    return None


def _attr_str(block: str, key: str):
    """The literal string value of ``key`` in ``block``; None if absent,
    ``_UNRESOLVED`` if repeated or not a plain string literal."""
    hits = list(re.finditer(rf'"?\b{key}"?\s*=', block))
    if not hits:
        return None
    if len(hits) > 1:
        return _UNRESOLVED
    m = NIX_STRING_ATTR.match(block, hits[0].end())
    return m.group(1) if m else _UNRESOLVED


_UNRESOLVED = object()


def _forge_url(ty, host, owner, repo) -> str | None:
    """Reduce a github/gitlab/sourcehut source to ``https://host/owner/repo/``.
    The trailing slash makes ALLOWED_PREFIXES (``.../NixOS/nixpkgs/``) and
    exception prefixes match on a whole path segment only."""
    if host is None:
        host = FORGE_HOST_DEFAULT[ty]
    if not (
        isinstance(host, str)
        and isinstance(owner, str)
        and isinstance(repo, str)
        and HOST_PART.fullmatch(host)
        and OWNER_PART.fullmatch(owner)
        and OWNER_PART.fullmatch(repo)
    ):
        return None
    return f"https://{host}/{owner}/{repo}/"


def _fetch_attrsets(
    rel: str, code: str, masked: str, starts: list[int], found: list[Source]
) -> None:
    for m in FETCH_CALL.finditer(masked):
        line = bisect.bisect_right(starts, m.start()) + 1
        call = m.group(0)
        opened = FETCH_ARG_OPEN.match(masked, m.end())
        if not opened:
            found.append((rel, line, f"builtins.{call} with a non-literal argument"))
            continue
        close = _matching_brace(masked, opened.end() - 1)
        if close is None:
            found.append((rel, line, f"builtins.{call} attrset with unbalanced braces"))
            continue
        block = code[opened.end() - 1 : close + 1]
        if not _has_forge_keys(block):
            continue
        for raw in _attrset_sources(call, block):
            if (rel, line, raw) not in found:
                found.append((rel, line, raw))


def _has_forge_keys(block: str) -> bool:
    if re.search(r'"?\b(?:type|owner|repo|host)"?\s*=', block):
        return True
    return bool(re.search(r"\binherit\b", block)) and bool(FETCH_KEYS.search(block))


def _attrset_sources(call: str, block: str) -> list[str]:
    """Graded sources for one fetchTree/fetchGit attrset: a reduced forge url,
    the literal ``url`` of a git/tarball/file fetch, or a violation marker
    that no rule or exception can match."""
    bad = f"builtins.{call} attrset with an unresolved host/owner/repo"
    ty = _attr_str(block, "type")
    if ty is None or ty is _UNRESOLVED:
        return [f"builtins.{call} attrset with an unresolved type"]
    if ty in URL_TYPES:
        url = _attr_str(block, "url")
        if url is None or url is _UNRESOLVED:
            return [f"builtins.{call} attrset of type {ty} with no literal url"]
        return [url]
    if ty not in FORGE_HOST_DEFAULT:
        return [f"builtins.{call} attrset with unknown type {ty!r}"]
    host = _attr_str(block, "host")
    owner = _attr_str(block, "owner")
    repo = _attr_str(block, "repo")
    if owner is None or repo is None or _UNRESOLVED in (host, owner, repo):
        return [bad]
    url = _forge_url(ty, None if host is None else host, owner, repo)
    return [url if url is not None else bad]


def _line_of_key(text: str, key: str) -> int:
    m = re.search(rf'"{re.escape(key)}"\s*:', text)
    return text.count("\n", 0, m.start()) + 1 if m else 1


def _lock_sources(rel: str, text: str) -> list[Source]:
    """flake.lock: every locked node. Github/gitlab/sourcehut reduce like an
    attrset; git/tarball/file grade their url; path/indirect do not fetch."""
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        return [(rel, 1, f"flake.lock is not valid JSON ({exc})")]
    nodes = data.get("nodes") if isinstance(data, dict) else None
    if not isinstance(nodes, dict):
        return [(rel, 1, "flake.lock has no nodes object")]
    found: list[Source] = []
    for name, node in nodes.items():
        if not isinstance(node, dict) or "locked" not in node:
            continue
        line = _line_of_key(text, name)
        locked = node["locked"]
        if not isinstance(locked, dict):
            found.append(
                (rel, line, f"flake.lock node {name}: locked is not an object")
            )
            continue
        ty = locked.get("type")
        if not isinstance(ty, str):
            found.append(
                (rel, line, f"flake.lock node {name}: locked type is not a string")
            )
            continue
        if ty in ("path", "indirect"):
            continue
        if ty in URL_TYPES:
            url = locked.get("url")
            if not isinstance(url, str) or not url:
                found.append((rel, line, f"flake.lock node {name}: {ty} with no url"))
            else:
                found.append((rel, line, url))
        elif ty in FORGE_HOST_DEFAULT:
            url = _forge_url(
                ty, locked.get("host"), locked.get("owner"), locked.get("repo")
            )
            if url is None:
                url = f"flake.lock node {name}: {ty} with an unresolved host/owner/repo"
            found.append((rel, line, url))
        else:
            found.append(
                (rel, line, f"flake.lock node {name}: unknown locked type {ty!r}")
            )
    return found


def _positionals(tail: str, value_flags: frozenset[str]) -> list[str]:
    try:
        tokens = shlex.split(tail)
    except ValueError:
        tokens = tail.split()
    out: list[str] = []
    skip = False
    for tok in tokens:
        if skip:
            skip = False
        elif tok in value_flags:
            skip = True
        elif not tok.startswith("-"):
            out.append(tok)
    return out


def _interpolated(raw: str) -> str:
    return f"fetch with an interpolated target: {raw}"


def _shell_sources(text: str, docker: bool) -> list[str]:
    """Fetch targets on one shell command line: git clone URLs and scp-style
    remotes, and in a Dockerfile the curl/wget URLs. A target with ``$`` or a
    clone under a url insteadOf rewrite becomes a violation marker, since its
    host or owner is not knowable from the text.
    """
    found: list[str] = []
    for m in GIT_CLONE.finditer(text):
        raw = m.group(1)
        found.append(_interpolated(raw) if "$" in raw else raw)
    for m in CLONE_TAIL.finditer(text):
        for tok in _positionals(m.group(1), CLONE_VALUE_FLAGS):
            if "://" in tok:
                continue
            if "$" in tok:
                found.append(_interpolated(tok))
            elif CLONE_ARG.match(tok):
                found.append(tok)
    if CLONE_TAIL.search(text) and GIT_INSTEADOF.search(text):
        found.append("git clone under a url insteadOf rewrite")
    if docker:
        if GIT_INSTEADOF.search(text):
            found.append("git config url insteadOf rewrite")
        for m in DOCKER_DOWNLOAD.finditer(text):
            raw = m.group(1)
            found.append(_interpolated(raw) if "$" in raw else raw)
        for m in DOCKER_TOOL_TAIL.finditer(text):
            for tok in _positionals(m.group(1), DOWNLOAD_VALUE_FLAGS):
                if "://" in tok:
                    continue
                if "$" in tok:
                    found.append(_interpolated(tok))
                elif SCHEMELESS_HOST.match(tok):
                    found.append(f"fetch with a scheme-less target: {tok}")
    return found


def _logical_lines(text: str) -> list[tuple[int, str]]:
    """Dockerfile instructions as (first line number, text), with backslash
    line continuations joined onto the first line.
    """
    out: list[tuple[int, str]] = []
    buf: list[str] = []
    start = 1
    for n, line in enumerate(text.splitlines(), start=1):
        stripped = line.rstrip()
        if buf and (not stripped or stripped.lstrip().startswith("#")):
            continue  # Docker drops comment and blank lines inside a continuation
        if not buf:
            start = n
        if stripped.endswith("\\"):
            buf.append(stripped[:-1] + " ")
            continue
        buf.append(line)
        out.append((start, "".join(buf)))
        buf = []
    if buf:
        out.append((start, "".join(buf)))
    return out


def _dockerfile_sources(rel: str, text: str) -> list[Source]:
    found: list[Source] = []
    for n, line in _logical_lines(text):
        for raw in _shell_sources(line, docker=True):
            found.append((rel, n, raw))
        add = ADD_SOURCE.match(line)
        if add:
            src = add.group(1).strip("[\"',]")
            if "$" in src:
                found.append((rel, n, _interpolated(src)))
            elif ADD_REMOTE.match(src):
                found.append((rel, n, src))
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
            if (
                name.endswith(".nix")
                or name == "flake.lock"
                or name.startswith(("Dockerfile", "Containerfile"))
            ):
                yield here / name


def _sources(root: pathlib.Path) -> list[Source]:
    found: list[Source] = []
    for path in _files(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text(encoding="utf-8")
        if path.name.endswith(".nix"):
            found.extend(_nix_sources(rel, text))
        elif path.name == "flake.lock":
            found.extend(_lock_sources(rel, text))
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
        forge = FORGE_SOURCE.match(norm)
        evasion = False
        if forge is not None:
            if forge.group(1).lower() in ALLOWED_OWNERS:
                if not FORGE_PATH_EVASION.search(norm):
                    continue
                evasion = True
        elif norm.startswith(ALLOWED_PREFIXES):
            if not FORGE_PATH_EVASION.search(norm):
                continue
            evasion = True
        elif BORGBASE_REPO.fullmatch(norm):
            # The sanctioned `/./repo` is itself a dot segment; check the rest.
            if not FORGE_PATH_EVASION.search(norm.replace("/./repo", "", 1)):
                continue
            evasion = True
        hit = next(
            (i for i, e in enumerate(exceptions) if _matches(e["match"], norm)), None
        )
        if hit is None and evasion:
            violations.append(
                f"{path}:{line}: {raw} — the path has a dot segment or a "
                "percent-encoded dot/slash, so it can resolve outside its owner"
            )
        elif hit is None and forge is not None:
            owner = forge.group(1).lower()
            violations.append(
                f"{path}:{line}: {raw} — forge owner {owner!r} is not an allowed "
                "forge owner (eblume, mirrors): the talos bot can write to other "
                "owners, so the source is unreviewed code"
            )
        elif hit is None:
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


# --- unit tests -------------------------------------------------------------


def _violations_for_url(tmp_path: pathlib.Path, url: str) -> list[str]:
    # A `url =` inside a pinned fetcher attrset: the scanner only grades fetches.
    (tmp_path / "default.nix").write_text(
        "{ pkgs }: pkgs.fetchurl {\n"
        f'  url = "{url}";\n'
        '  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";\n'
        "}\n",
        encoding="utf-8",
    )
    return check(tmp_path)


@pytest.mark.parametrize(
    "url",
    [
        "ssh://xcrtl5tg@xcrtl5tg.repo.borgbase.com/./repo",
        "ssh://u3ugi1x1@u3ugi1x1.repo.borgbase.com/./repo",
    ],
)
def test_borgbase_repo_locator_passes(tmp_path, url):
    assert _violations_for_url(tmp_path, url) == []


@pytest.mark.parametrize(
    "url",
    [
        "ssh://abc@abc.repo.borgbase.com.evil.example/./repo",  # host suffix
        "ssh://abc@evil.repo.borgbase.com/./repo/../x",  # host label mismatch
        "ssh://abc@abc.repo.borgbase.com/other",  # different path
        "ssh://abc@abc.repo.borgbase.com/./repo/../x",  # dot-segment escape
        "ssh://abc@abc.repo.borgbase.com/./repo/extra",  # trailing path
        "ssh://abc@abc.repo.borgbase.com/./repo?x=1",  # query
        "ssh://abc@abc.repo.borgbase.com/./repo#frag",  # fragment
        "ssh://abc@abc.repo.borgbase.com/%2e/repo",  # percent-encoded dot
        "ssh://abc@ABC.repo.borgbase.com/./repo",  # uppercase label
        "ssh://abc@xyz.repo.borgbase.com/./repo",  # userinfo mismatch
        "ssh://abc@abc.repo.borgbase.com:2222/./repo",  # port
        "ssh://abc@abc-x.repo.borgbase.com/./repo",  # non-[a-z0-9] label
        "https://abc@abc.repo.borgbase.com/./repo",  # https is not the rule
        "https://abc.repo.borgbase.com/./repo",
        "ssh://abc@abc.borgbase.com/./repo",  # other borgbase host shape
    ],
)
def test_borgbase_look_alikes_violate(tmp_path, url):
    assert _violations_for_url(tmp_path, url), url
