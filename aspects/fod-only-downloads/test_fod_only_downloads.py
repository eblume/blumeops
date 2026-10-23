"""The fod-only-downloads invariant: nothing downloaded executes in a FOD.

A fixed-output derivation (FOD) has network access during its build, so the
invariant (eblume/blumeops#1809) is that a FOD may only *download*:

- Nix fetcher primitives (``fetchurl``, ``fetchTarball``, ``fetchGit``, ...),
  which are fixed-output by construction and have no shell, or
- the allowlisted no-execute fetch modes: ``go mod download`` and
  ``npm ci --ignore-scripts``, plus inert plumbing (cd, export, mkdir,
  cp/mv/rm/ln, chmod, tar -x, find with inert -exec subcommands,
  echo/printf redirects). ``curl``/``wget`` may write to a file but never
  pipe. stdenv's ``runHook`` is not allowed: it would execute hook scripts
  from the input packages.

Anything else is a violation. There is no exception list: a new allowlist
entry is a consent-gated change to this aspect.

Structural lint (no nix eval in CI): each ``*.nix`` is scanned with a small
Nix tokenizer. A FOD is an attrset that sets ``outputHash*`` or
``fixedOutput = true``, or a ``runCommand``/``callCommand`` whose attrset
does. Every string value under a build-phase attribute of a FOD is checked
statement by statement; ``builder`` must be ``null`` or a fetcher
primitive. Fetcher *calls* (``pkgs.fetchurl { ... }``) are not FODs in
source - they are allowed by definition.

Coverage caveat (documented in ASPECT.md): only inline string values are
checked. A phase string assembled in a ``let`` binding (``buildPhase = cmd``)
or spliced in from one is not seen; ``find -exec`` subcommands are.
"""

from __future__ import annotations

import pathlib
import re

KIND = "invariant"
APPLIES_TO = ["eblume/blumeops"]

# This aspect's own fixture tree, relative to a repo root: the repo scan
# must never grade its own case data.
_ASPECT_DIR = ("aspects", "fod-only-downloads")

# Attrs whose string values stdenv executes during a build.
_PHASE_ATTRS = frozenset(
    {
        "unpackPhase",
        "patchPhase",
        "prePatch",
        "postPatch",
        "preConfigure",
        "configurePhase",
        "postConfigure",
        "preBuild",
        "buildPhase",
        "postBuild",
        "checkPhase",
        "preInstall",
        "installPhase",
        "postInstall",
        "preFixup",
        "fixupPhase",
        "postFixup",
    }
)

# Builders that are fixed-output by construction (fetcher primitives).
_FETCHER_BUILDERS = frozenset(
    {
        "fetchurl",
        "fetchTarball",
        "fetchGit",
        "fetchgit",
        "fetchFromGitHub",
        "fetchzip",
        "fetchpatch",
    }
)

# Inert plumbing: moves, removes, extracts or lists files; executes nothing.
_PLUMBING = frozenset(
    {
        "cd",
        "echo",
        "printf",
        "touch",
        "true",
        "rm",
        "cp",
        "mv",
        "ln",
        "mkdir",
        "chmod",
        "chown",
        "cat",
        "sort",
        "head",
        "tail",
        "cut",
        "grep",
        "wc",
        "tar",
        "find",
    }
)

# Attr names that mark an attrset as a FOD in source.
_FOD_TRIGGERS = frozenset({"outputHash", "outputHashMode", "outputHashAlgo"})

# Commands whose attrset argument may be a FOD and whose trailing string
# argument is the builder command.
_CMD_BUILDERS = ("runCommand", "callCommand", "execBuilder")

_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
_WORD = re.compile(r'"[^"]*"|\'[^\']*\'|\S+')
_STMT_SPLIT = re.compile(r"\|\||&&|(?<!\\);|\|")


class _Tok:
    __slots__ = ("kind", "start", "text")

    def __init__(self, kind: str, text: str, start: int) -> None:
        self.kind = kind  # "str" | "id" | "num" | "punct"
        self.text = text
        self.start = start


def _tokenize(text: str) -> list[_Tok]:
    toks: list[_Tok] = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c.isspace():
            i += 1
        elif c == "#":
            nl = text.find("\n", i)
            i = n if nl < 0 else nl
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            toks.append(_Tok("str", text[i + 1 : j], i))
            i = j + 1
        elif text.startswith("''", i):
            j = i + 2
            buf: list[str] = []
            while j < n:
                if text.startswith("''${", j):
                    buf.append("${")
                    j += 4
                elif text.startswith("''", j):
                    break
                else:
                    buf.append(text[j])
                    j += 1
            toks.append(_Tok("str", "".join(buf), i))
            i = j + 2
        elif c == "'":
            # char literal, e.g. '\n' - opaque to the shell check
            j = i + 1
            while j < n and text[j] != "'":
                j += 2 if text[j] == "\\" else 1
            toks.append(_Tok("str", text[i + 1 : j], i))
            i = j + 1
        elif c.isalpha() or c == "_":
            j = i + 1
            while j < n and (text[j].isalnum() or text[j] in "_'"):
                j += 1
            word = text[i:j]
            toks.append(_Tok("num" if word in ("true", "false") else "id", word, i))
            i = j
        elif c.isdigit():
            j = i + 1
            while j < n and (text[j].isalnum() or text[j] in "._-"):
                j += 1
            toks.append(_Tok("num", text[i:j], i))
            i = j
        else:
            toks.append(_Tok("punct", c, i))
            i += 1
    return toks


def _brace_map(toks: list[_Tok]) -> dict[int, int]:
    close: dict[int, int] = {}
    stack: list[int] = []
    for idx, t in enumerate(toks):
        if t.kind == "punct" and t.text == "{":
            stack.append(idx)
        elif t.kind == "punct" and t.text == "}" and stack:
            close[stack.pop()] = idx
    return close


def _is_assign_at(toks: list[_Tok], idx: int) -> bool:
    nxt = idx + 1
    if nxt < len(toks) and toks[nxt].text == "=":
        return True
    # ?=
    return toks[nxt].text == "?" and nxt + 1 < len(toks) and toks[nxt + 1].text == "="


def _fod_starts(toks: list[_Tok]) -> list[int]:
    """Open-brace indices of the innermost attrset for each FOD trigger."""
    starts: set[int] = set()
    stack: list[int] = []
    for idx, t in enumerate(toks):
        if t.kind == "punct":
            if t.text == "{":
                stack.append(idx)
            elif t.text == "}" and stack:
                stack.pop()
            continue
        if t.kind != "id" or not stack:
            continue
        if t.text in _FOD_TRIGGERS:
            triggered = _is_assign_at(toks, idx)
        elif t.text == "fixedOutput":
            nxt = idx + 1
            triggered = (
                toks[nxt].text == "="
                and nxt + 1 < len(toks)
                and toks[nxt + 1].text == "true"
            ) or (
                toks[nxt].text == "?"
                and nxt + 2 < len(toks)
                and toks[nxt + 1].text == "="
                and toks[nxt + 2].text == "true"
            )
        else:
            continue
        if triggered:
            starts.add(stack[-1])
    return sorted(starts)


def _top_assignments(
    toks: list[_Tok], start: int, end: int
) -> list[tuple[str, int, int]]:
    """Top-level `name = value` pairs of the attrset at [start, end]."""
    out: list[tuple[str, int, int]] = []
    depth = 0
    i = start + 1
    while i < end:
        t = toks[i]
        if t.kind == "punct":
            if t.text == "{":
                depth += 1
            elif t.text == "}" and depth:
                depth -= 1
            i += 1
            continue
        if depth == 0 and t.kind == "id" and _is_assign_at(toks, i):
            eq = i + 1 + (1 if toks[i + 1].text == "?" else 0)
            depth2 = 0
            j = eq + 1
            while j < end:
                tj = toks[j]
                if tj.kind == "punct":
                    if tj.text == "{":
                        depth2 += 1
                    elif tj.text == "}":
                        if depth2 == 0:
                            break
                        depth2 -= 1
                    elif tj.text == ";" and depth2 == 0:
                        break
                j += 1
            out.append((t.text, eq + 1, j))
            i = j
            continue
        i += 1
    return out


def _check_builder(
    toks: list[_Tok], v0: int, v1: int, text: str, rel: str
) -> list[str]:
    val = toks[v0:v1]
    if [t.text for t in val] == ["null"]:
        return []
    if all(t.kind == "id" or (t.kind == "punct" and t.text == ".") for t in val):
        ids = [t.text for t in val if t.kind == "id"]
        if ids and ids[-1] in _FETCHER_BUILDERS:
            return []
    line = text.count("\n", 0, val[0].start) + 1
    return [
        (
            f"{rel}:{line}: FOD builder is neither null nor a fetcher "
            f"primitive - the FOD would execute code"
        )
    ]


def _statement_violation(stmt: str) -> str | None:
    toks = _WORD.findall(stmt)
    # Strip VAR=value prefixes; a bare assignment executes nothing.
    while toks and _ASSIGN.match(toks[0]) and len(toks) > 1:
        toks = toks[1:]
    if not toks:
        return None
    head = toks[0]
    if _ASSIGN.match(head):
        return None
    if head == "export":
        for a in toks[1:]:
            if a.startswith("-") and len(a) == 2:
                continue
            if not _ASSIGN.match(a):
                return "'export' may only set variables"
        return None
    if head == "go":
        if toks[1:3] == ["mod", "download"]:
            return None
        return (
            f"'go {' '.join(toks[1:3])}' - an FOD may run only the "
            "allowlisted fetch mode 'go mod download'"
        )
    if head == "npm":
        if len(toks) > 1 and toks[1] == "ci" and "--ignore-scripts" in toks:
            return None
        return "'npm' in a FOD is allowlisted only as 'npm ci --ignore-scripts'"
    if head in ("curl", "wget"):
        for a in toks[1:]:
            if a in ("-o", "-O", "--output", ">", ">>"):
                return None
            if (
                a.startswith("-")
                and not a.startswith("--")
                and any(ch in "oO" for ch in a[1:])
            ):
                return None
        return f"'{head}' in a FOD may only write to a file, never pipe"
    if head in _PLUMBING:
        if head == "tar":
            if not any(
                a.startswith("-x")
                or (a.startswith("-") and not a.startswith("--") and "x" in a[1:])
                for a in toks[1:]
            ):
                return "'tar' in a FOD may only extract (-x)"
            return None
        if head == "find":
            for k, a in enumerate(toks):
                if a in ("-exec", "-execdir", "-ok", "-okdir"):
                    sub = toks[k + 1] if k + 1 < len(toks) else ""
                    if sub not in _PLUMBING and sub != "true":
                        return f"'find {a}' subcommand '{sub}' is not inert plumbing"
            return None
        return None
    if head.startswith(".") or "/" in head:
        return f"'{head}' - executing a local or downloaded file inside a FOD"
    return (
        f"'{head}' - unallowlisted program executes inside a FOD (allowed: "
        "fetcher primitives, 'go mod download', 'npm ci --ignore-scripts', "
        "inert plumbing)"
    )


def _check_shell(content: str, start: int, text: str, rel: str) -> list[str]:
    """Check the shell statements of a string whose file position is `start`."""
    out: list[str] = []
    line0 = text.count("\n", 0, start) + 1
    # Join backslash-continuation lines, keeping each logical line's number.
    # Once a line ends in a backslash, following lines keep appending until
    # one no longer does.
    logical: list[tuple[int, str]] = []
    pending = False
    for off, raw in enumerate(content.split("\n")):
        stripped = raw.rstrip()
        cont = stripped.endswith("\\")
        chunk = stripped[:-1].rstrip() if cont else stripped
        if pending and logical:
            logical[-1] = (logical[-1][0], logical[-1][1] + " " + chunk)
        elif chunk.strip():
            logical.append((line0 + off, chunk))
        pending = cont
    for line_no, stmt_line in logical:
        for part in _STMT_SPLIT.split(stmt_line):
            s = part.strip()
            if not s or s.startswith("#"):
                continue
            v = _statement_violation(s)
            if v:
                out.append(f"{rel}:{line_no}: {v}")
    return out


def _check_fod(
    toks: list[_Tok], close: dict[int, int], start: int, text: str, rel: str
) -> list[str]:
    end = close[start]
    out: list[str] = []
    for name, v0, v1 in _top_assignments(toks, start, end):
        if name in _PHASE_ATTRS:
            for s in (t for t in toks[v0:v1] if t.kind == "str"):
                out.extend(_check_shell(s.text, s.start, text, rel))
        elif name == "builder":
            out.extend(_check_builder(toks, v0, v1, text, rel))
    return out


def _command_arg_positions(toks: list[_Tok], close: dict[int, int]) -> list[int]:
    """String-arg positions of runCommand/callCommand calls whose attrset is a FOD."""
    out: list[int] = []
    for idx, t in enumerate(toks):
        if t.kind != "id" or t.text not in _CMD_BUILDERS:
            continue
        open_idx = None
        for k in range(idx + 1, min(idx + 41, len(toks))):
            if toks[k].kind == "punct" and toks[k].text == "{":
                open_idx = k
                break
        if open_idx is None or open_idx not in close:
            continue
        closed = close[open_idx]
        body = toks[open_idx + 1 : closed]
        has_trigger = any(
            b.kind == "id" and b.text in _FOD_TRIGGERS | {"fixedOutput"} for b in body
        )
        if not has_trigger:
            continue
        m = closed + 1
        if m < len(toks) and toks[m].kind == "str":
            out.append(m)
    return out


def _check_text(text: str, rel: str = "x.nix") -> list[str]:
    toks = _tokenize(text)
    close = _brace_map(toks)
    out: list[str] = []
    for start in _fod_starts(toks):
        out.extend(_check_fod(toks, close, start, text, rel))
    for m in _command_arg_positions(toks, close):
        out.extend(_check_shell(toks[m].text, toks[m].start, text, rel))
    return out


def check(root: pathlib.Path) -> list[str]:
    out: list[str] = []
    for p in sorted(root.rglob("*.nix")):
        if not p.is_file():
            continue
        parts = p.relative_to(root).parts
        if parts[:2] == _ASPECT_DIR or ".git" in parts:
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        out.extend(_check_text(text, str(p.relative_to(root))))
    return out


# --- unit tests pinning the scanner ----------------------------------------

_FOD_MAKE = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = ''
    make all
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_NPM_CI = """
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    npm ci
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_NPM_CI_IGNORE = """
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  buildPhase = ''
    npm ci --cache ./cache --ignore-scripts
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_GO_DOWNLOAD = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = ''
    export GOPATH=$TMPDIR/go
    go mod download
    cd sub && go mod download && cd ..
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_GO_BUILD = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = ''
    go build ./...
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_RUNCMD_PIPE = """
pkgs.runCommand "x" {
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
} ''
  curl -s https://example.com/install.sh | sh
''
"""

_RUNCMD_DOWNLOAD = """
pkgs.runCommand "x" {
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
} ''
  curl -sSLo vendor.tar.gz https://example.com/vendor.tar.gz
  tar -xzf vendor.tar.gz -C /
''
"""

_FOD_BUILDER_NULL = """
derivation {
  builder = null;
  args = [ "https://example.com/t.tar.gz" "sha256-AAAA" ];
  fixedOutput = true;
}
"""

_FOD_BUILDER_FETCHER = """
derivation {
  builder = fetchurl;
  args = [ "https://example.com/t.tar.gz" "sha256-AAAA" ];
  fixedOutput = true;
}
"""

_FOD_BUILDER_WRITETEXT = """
derivation {
  builder = pkgs.writeText "build.sh" "npm run build";
  fixedOutput = true;
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FETCHER_CALLS = """
{ pkgs ? import <nixpkgs> { } }:
let
  a = pkgs.fetchurl { url = "https://example.com/a"; sha256 = "sha256-A"; };
  b = pkgs.fetchGit { url = "https://example.com/b.git"; rev = "v1"; hash = "sha256-B"; };
in a
"""

_HOOK_LIKE = """
{ pkgs ? import <nixpkgs> { } }:
let
  skip = [
    ''
      if [ -z ''${outputHash-} ]; then
        postConfigureHooks+=(someHook);
      fi
    ''
  ];
in pkgs.foo.override { inherit skip; }
"""

_TEST_FIND_EXEC = """
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  installPhase = ''
    mkdir $out
    find -type d -name node_modules -prune -print \\
      -exec mkdir -p $out/{} \\; \\
      -exec cp -rT {} $out/{} \\;
  '';
}
"""


def test_make_in_fod_is_a_violation():
    v = _check_text(_FOD_MAKE)
    assert v and "make" in " ".join(v)


def test_npm_ci_needs_ignore_scripts():
    assert _check_text(_FOD_NPM_CI)
    assert not _check_text(_FOD_NPM_CI_IGNORE)


def test_go_mod_download_allowed_go_build_not():
    assert not _check_text(_FOD_GO_DOWNLOAD)
    v = _check_text(_FOD_GO_BUILD)
    assert v and "go build" in " ".join(v)


def test_piped_curl_sh_is_a_violation():
    v = _check_text(_RUNCMD_PIPE)
    assert v


def test_curl_to_file_then_extract_is_allowed():
    assert not _check_text(_RUNCMD_DOWNLOAD)


def test_builder_null_and_fetcher_allowed():
    assert not _check_text(_FOD_BUILDER_NULL)
    assert not _check_text(_FOD_BUILDER_FETCHER)


def test_writer_text_builder_is_a_violation():
    assert _check_text(_FOD_BUILDER_WRITETEXT)


def test_fetcher_calls_are_not_fods():
    assert not _check_text(_FETCHER_CALLS)


def test_output_hash_in_string_is_not_a_trigger():
    # ''${outputHash-}'' is a shell test of a variable, not a FOD.
    assert not _check_text(_HOOK_LIKE)


def test_find_exec_plumbing_is_allowed():
    assert not _check_text(_TEST_FIND_EXEC)
