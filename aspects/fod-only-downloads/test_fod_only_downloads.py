"""The fod-only-downloads invariant: nothing downloaded executes in a FOD.

A fixed-output derivation (FOD) has network access during its build, so the
invariant (eblume/blumeops#1809) is that a FOD may only *download*:

- Nix fetcher primitives (``fetchurl``, ``fetchTarball``, ``fetchGit``, ...),
  which are fixed-output by construction and have no shell, or
- the allowlisted no-execute fetch modes: ``go mod download`` (only with
  ``GOTOOLCHAIN=local``) and ``npm ci --ignore-scripts``, plus inert plumbing
  (cd, export, mkdir, cp/mv/rm/ln, chmod, tar -x, find with inert -exec
  subcommands, echo/printf redirects).

Everything else is a violation, fail-closed: shell control flow (if/case/
for/while), other builtins (set, umask), command substitution (``$(...)``,
backticks - it would execute the substituted command), and any program
outside the allowlist. Pipes are checked segment by segment against the
same allowlist, so ``curl ... | sh`` is red. There is no exception list:
a new allowlist entry is a consent-gated change to this aspect.

Two shapes of FOD are graded:

1. **FODs in source** - an attrset that assigns ``outputHash*`` or
   ``fixedOutput = true`` (directly or via ``inherit``), or a
   ``runCommand``/``callCommand``/``execBuilder`` whose attrset does. For
   these the check is fail-closed over names: every attribute whose value
   is a direct string literal is checked statement by statement, except a
   short allowlist of attrs that hold inert strings (``pname``, ``version``,
   ``outputHash*``, ``sourceRoot``, ...). ``builder`` must be ``null`` or a
   fetcher primitive. String elements of a ``phases``/``*Phases`` list are
   checked too, since a non-name string there is an inline phase.

2. **FODs nixpkgs builders create** - the call itself is not a FOD in
   source (no ``outputHash``), but the builder derives one internally, at
   the pinned nixpkgs rev (see ASPECT.md):

   - ``buildGoModule { ... }`` with ``vendorHash != null``: the vendor
     FOD inherits ``prePatch``/``postPatch``/``preBuild`` (and
     ``modPostBuild``), and its phases are ``mod*Phase``; ``overrideModAttrs``
     is applied on top, so an override value wins and any other override
     becomes a FOD attr.
   - ``buildNpmPackage { ... }``: the deps FOD inherits ``prePatch``/
     ``postPatch`` (and ``prePnpmInstall`` where pnpm deps are used).
   - ``fetchPnpmDeps { ... }`` / ``fetchNpmDeps { ... }``: the call's
     attrs are spliced into the FOD wholesale - checked like a plain FOD.
   - any fetcher call: only ``preFetch``/``postFetch`` run shell in the
     FOD, and they are checked.
   - ``fetchMixDeps``: any call is red - it has no no-execute mode.

Coverage caveat (documented in ASPECT.md): only inline string values are
checked. A phase string assembled in a ``let`` binding (``buildPhase =
cmd``) or spliced in from one is not seen; list-valued attrs (``patches``,
``ldflags``, ...) and ``nativeBuildInputs`` setup-hook bodies are not seen.
"""

from __future__ import annotations

import pathlib
import re

KIND = "invariant"
APPLIES_TO = ["eblume/blumeops"]

# This aspect's own fixture tree, relative to a repo root: the repo scan
# must never grade its own case data.
_ASPECT_DIR = ("aspects", "fod-only-downloads")

# Attrs whose direct string values stdenv never executes: names, hashes,
# paths and fetcher bookkeeping. A FOD attrset attr with any other direct
# string value is checked as shell (fail-closed).
_INERT_ATTRS = frozenset(
    {
        "pname",
        "name",
        "version",
        "src",
        "sourceRoot",
        "setSourceRoot",
        "modRoot",
        "goSum",
        "position",
        "hash",
        "sha256",
        "sha512",
        "outputHash",
        "outputHashAlgo",
        "outputHashMode",
        "vendorHash",
        "npmDepsHash",
        "pnpmDepsHash",
        "npmRegistryOverridesString",
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
_CMD_BUILDERS = frozenset(
    {
        "runCommand",
        "runCommandLocal",
        "runCommandCC",
        "runCommandNoCC",
        "callCommand",
        "execBuilder",
    }
)

# tar extract forms: single-dash clusters with an x, GNU letter forms,
# and the long flag.
_TAR_EXTRACT = frozenset({"x", "xf", "xz", "xzf", "xj", "xjf", "jx", "jxf"})

# tar flags that can execute commands inside a FOD.
_TAR_EXEC_FLAGS = (
    "--to-command",
    "--use-compress-program",
    "--info-script",
    "--new-volume-script",
    "--rsh-command",
    "--checkpoint",
)

# nixpkgs builders that create a FOD internally (call is not a FOD in
# source): call head -> how to grade the call's attrset.
_BUILDER_CALLS = {
    "buildGoModule": "go-module",
    "buildNpmPackage": "npm-package",
    "fetchPnpmDeps": "all-strings",
    "fetchNpmDeps": "all-strings",
    "fetchMixDeps": "mix-deps",
}

# buildGoModule vendor FOD: the attrs the FOD executes. module.nix
# (pkgs/build-support/go/module.nix at the pin) assigns prePatch/postPatch/
# preBuild/modPostBuild onto the FOD, its default mod*Phase run
# runHook preConfigure/postConfigure/preInstall/postInstall, and it never
# overrides unpackPhase/patchPhase.
_GO_MOD_FOD_ATTRS = frozenset(
    {
        "preUnpack",
        "postUnpack",
        "unpackCmd",
        "prePatch",
        "postPatch",
        "preConfigure",
        "postConfigure",
        "preBuild",
        "modPostBuild",
        "preInstall",
        "postInstall",
    }
)
_MOD_PHASE = re.compile(r"^mod[A-Z][A-Za-z0-9]*Phase$")

# buildNpmPackage: the attrs its deps FOD (fetchNpmDeps/fetchPnpmDeps)
# inherits and executes.
_NPM_FOD_ATTRS = frozenset({"prePatch", "postPatch", "prePnpmInstall"})

# Fetcher calls: the only attrs that run shell inside the FOD.
_FETCHER_SHELL_ATTRS = frozenset({"preFetch", "postFetch"})

_ASSIGN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
_BARE_IDENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
_WORD = re.compile(r'"[^"]*"|\'[^\']*\'|\S+')
_GOTOOLCHAIN_LOCAL = re.compile(r'^GOTOOLCHAIN=["\']?local["\']?$')
_BARE_PHASE_NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


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
    # An optional attrset entry (`? name = ...`) is tokenized with `?`
    # before the id, so the id itself is always followed by `=`.
    return idx + 1 < len(toks) and toks[idx + 1].text == "="


def _inherit_names(toks: list[_Tok], idx: int) -> list[str]:
    """Ids collected by the `inherit` at idx (skipping an optional (group))."""
    j = idx + 1
    if j < len(toks) and toks[j].text == "(":
        depth = 0
        while j < len(toks):
            if toks[j].text == "(":
                depth += 1
            elif toks[j].text == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        j += 1
    names: list[str] = []
    while j < len(toks) and toks[j].kind == "id":
        names.append(toks[j].text)
        j += 1
    return names


def _fod_starts(toks: list[_Tok]) -> list[int]:
    """Open-brace indices of the attrset a FOD trigger sits in.

    Only attrsets that are a derivation's argument qualify: a call-argument
    (`mkDerivation {`, `runCommand "x" {`, `(...) {`) or a top-level let
    binding (`name = { ... };` at brace depth 0). An attrset nested as an
    attr value (`args = { outputHash = ...; }`) is data, not a FOD.
    """
    starts: set[int] = set()
    stack: list[tuple[int, int]] = []
    for idx, t in enumerate(toks):
        if t.kind == "punct":
            if t.text == "{":
                stack.append((idx, len(stack)))
            elif t.text == "}" and stack:
                stack.pop()
            continue
        # A quoted attr name ("outputHash") is a str token.
        if t.kind not in ("id", "str") or not stack:
            continue
        if t.text in _FOD_TRIGGERS:
            triggered = _is_assign_at(toks, idx)
        elif t.text == "fixedOutput":
            nxt = idx + 1
            triggered = (
                nxt < len(toks)
                and toks[nxt].text == "="
                and nxt + 1 < len(toks)
                and toks[nxt + 1].text == "true"
            )
        elif t.text == "inherit":
            # inherit (x) outputHash; / inherit fixedOutput outputHash;
            triggered = any(
                n in _FOD_TRIGGERS | {"fixedOutput"} for n in _inherit_names(toks, idx)
            )
        else:
            continue
        if triggered:
            open_idx, depth = stack[-1]
            prev = toks[open_idx - 1] if open_idx > 0 else None
            call_arg = prev is not None and (
                prev.kind in ("id", "str") or prev.text in (")", "(", "//", "&&")
            )
            let_binding = prev is not None and prev.text == "=" and depth == 0
            if call_arg or let_binding:
                starts.add(open_idx)
    return sorted(starts)


def _top_assignments(
    toks: list[_Tok], start: int, end: int
) -> list[tuple[str, int, int]]:
    """Top-level `name = value` pairs of the attrset at [start, end].

    `name` is the full dotted path of an attrpath assignment (env.CGO,
    overrideModAttrs.preBuild); callers decide what to do with dotted names.
    """
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
        # An attr entry starts at an id or a quoted attr name
        # ("buildPhase"), never at a dotted continuation (after `.`).
        if (
            depth == 0
            and t.kind in ("id", "str")
            and not (i > 0 and toks[i - 1].kind == "punct" and toks[i - 1].text == ".")
        ):
            j = i
            while (
                j + 2 < end
                and toks[j + 1].kind == "punct"
                and toks[j + 1].text == "."
                and toks[j + 2].kind in ("id", "str")
            ):
                j += 2
            if j + 1 < end and toks[j + 1].text == "=":
                eq = j + 1
                depth2 = 0
                k = eq + 1
                while k < end:
                    tk = toks[k]
                    if tk.kind == "punct":
                        if tk.text == "{":
                            depth2 += 1
                        elif tk.text == "}":
                            if depth2 == 0:
                                break
                            depth2 -= 1
                        elif tk.text == ";" and depth2 == 0:
                            break
                    k += 1
                name = ".".join(
                    toks[x].text
                    for x in range(i, j + 1)
                    if toks[x].kind in ("id", "str")
                )
                out.append((name, eq + 1, k))
                i = k
                continue
        i += 1
    return out


def _is_direct_str(toks: list[_Tok], v0: int, v1: int) -> bool:
    """True when the value at [v0, v1) is one string literal (a script)."""
    return v1 - v0 == 1 and toks[v0].kind == "str"


def _check_builder(
    toks: list[_Tok], v0: int, v1: int, text: str, rel: str
) -> list[str]:
    val = toks[v0:v1]
    if not val:
        # `builder = ;` does not parse in Nix; nothing to grade here.
        return []
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


def _split_statements(line: str) -> list[str]:
    """Split a shell line on ;, &&, ||, | outside quotes; a backslash
    escapes the next character."""
    out: list[str] = []
    cur: list[str] = []
    quote: str | None = None
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if quote:
            cur.append(c)
            if c == "\\" and quote == '"' and i + 1 < n:
                cur.append(line[i + 1])
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c in "\"'":
            quote = c
            cur.append(c)
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            cur.append(c)
            cur.append(line[i + 1])
            i += 2
            continue
        if c == ";":
            out.append("".join(cur))
            cur = []
            i += 1
            continue
        if c == "&" and line[i : i + 2] == "&&":
            out.append("".join(cur))
            cur = []
            i += 2
            continue
        if c == "|" and line[i : i + 2] == "||":
            out.append("".join(cur))
            cur = []
            i += 2
            continue
        if c == "|":
            out.append("".join(cur))
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    out.append("".join(cur))
    return [s.strip() for s in out]


def _statement_violation(stmt: str, gotoolchain_local: bool = False) -> str | None:
    toks = _WORD.findall(stmt)
    # Strip VAR=value prefixes; a bare assignment executes nothing.
    prefixes: list[str] = []
    while toks and _ASSIGN.match(toks[0]) and len(toks) > 1:
        prefixes.append(toks[0])
        toks = toks[1:]
    # GOTOOLCHAIN=local prefixed on this command, e.g.
    # `GOTOOLCHAIN=local go mod download` - only leading env prefixes count,
    # never comment or argument text.
    prefixed_local = any(_GOTOOLCHAIN_LOCAL.match(t) for t in prefixes)
    if not toks:
        return None
    head = toks[0]
    if _ASSIGN.match(head):
        return None
    if head == "export":
        for a in toks[1:]:
            if a.startswith("-") and len(a) == 2:
                continue
            if not _ASSIGN.match(a) and not _BARE_IDENT.match(a):
                return "'export' may only set or re-export variables"
        return None
    if head == "go":
        if toks[1:3] == ["mod", "download"]:
            if gotoolchain_local or prefixed_local:
                return None
            return (
                "'go mod download' needs GOTOOLCHAIN=local (export it earlier "
                "in the same phase or prefix it on the command) - with the "
                "default auto, a 'toolchain' line in a downloaded go.mod "
                "fetches and executes a different Go toolchain in the FOD"
            )
        return (
            f"'go {' '.join(toks[1:3])}' - an FOD may run only the "
            "allowlisted fetch mode 'go mod download' with GOTOOLCHAIN=local"
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
        return (
            f"'{head}' in a FOD may only download to a file - each pipe "
            "segment is checked against the allowlist"
        )
    if head in _PLUMBING:
        if head == "tar":
            for a in toks[1:]:
                if any(a.startswith(f) for f in _TAR_EXEC_FLAGS):
                    return f"'tar {a}' can execute commands inside a FOD"
                if (
                    a.startswith("-")
                    and not a.startswith("--")
                    and ("I" in a[1:] or "F" in a[1:])
                ):
                    return (
                        f"'tar {a}' (-I/--use-compress-program or "
                        "-F/--info-script) can execute commands inside a FOD"
                    )
            if not any(
                a.startswith("-x")
                or (a.startswith("-") and not a.startswith("--") and "x" in a[1:])
                or a == "--extract"
                or a in _TAR_EXTRACT
                for a in toks[1:]
            ):
                return "'tar' in a FOD may only extract (-x)"
            return None
        if head == "sort":
            if any(a.startswith("--compress-program") for a in toks[1:]):
                return "'sort --compress-program' can execute commands inside a FOD"
            return None
        if head == "find":
            for k, a in enumerate(toks):
                if a in ("-exec", "-execdir", "-ok", "-okdir"):
                    # The whole subcommand argv is a command: grade it.
                    sub: list[str] = []
                    for b in toks[k + 1 :]:
                        if b in ("\\;", "\\+"):
                            break
                        sub.append(b)
                    if not sub:
                        continue
                    v = _statement_violation(" ".join(sub), gotoolchain_local)
                    if v:
                        return f"'find {a}' subcommand {' '.join(sub)}: {v}"
            return None
        return None
    if head.startswith(".") or "/" in head:
        return f"'{head}' - executing a local or downloaded file inside a FOD"
    return (
        f"'{head}' - unallowlisted program executes inside a FOD (allowed: "
        "fetcher primitives, 'go mod download' with GOTOOLCHAIN=local, "
        "'npm ci --ignore-scripts', inert plumbing; no shell control flow)"
    )


def _check_shell(
    content: str, start: int, text: str, rel: str, ctx: str = ""
) -> list[str]:
    """Check the shell statements of a string whose file position is `start`."""
    out: list[str] = []
    line0 = text.count("\n", 0, start) + 1
    if "$(" in content or "`" in content:
        out.append(
            f"{rel}:{line0}: {ctx}command substitution ($(...) or backticks) "
            "would execute code inside a FOD"
        )
        return out
    # Join backslash-continuation lines, keeping each logical line's number.
    # Only an odd number of trailing backslashes continues the line.
    logical: list[tuple[int, str]] = []
    pending = False
    for off, raw in enumerate(content.split("\n")):
        stripped = raw.rstrip()
        trail = len(stripped) - len(stripped.rstrip("\\"))
        if trail % 2 == 1:
            chunk = stripped[:-1].rstrip()
        else:
            chunk = stripped
        if pending and logical:
            logical[-1] = (logical[-1][0], logical[-1][1] + " " + chunk)
        elif chunk.strip():
            logical.append((line0 + off, chunk))
        pending = trail % 2 == 1
    local_seen = False
    for line_no, stmt_line in logical:
        for s in _split_statements(stmt_line):
            if not s or s.startswith("#"):
                continue
            ev = _gotoolchain_event(s)
            if ev is not None:
                local_seen = ev
            v = _statement_violation(s, local_seen)
            if v:
                out.append(f"{rel}:{line_no}: {ctx}{v}")
    return out


def _gotoolchain_event(stmt: str) -> bool | None:
    """Whether a statement sets GOTOOLCHAIN to local (True), to another
    value (False), or leaves it alone (None). Only pure assignment
    statements and `export` count - `echo GOTOOLCHAIN=local` is just a word.
    """
    toks = _WORD.findall(stmt)
    i = 0
    while i < len(toks) and _ASSIGN.match(toks[i]):
        i += 1
    if i < len(toks) and toks[i] == "export":
        targets = toks[i + 1 :]
    elif i == len(toks) and i > 0:
        targets = toks
    else:
        return None
    ev = None
    for t in targets:
        if t.startswith("GOTOOLCHAIN="):
            # covers local, "local" and 'local' via the local-only matcher
            ev = _GOTOOLCHAIN_LOCAL.match(t) is not None
    return ev


def _check_phases_list(
    toks: list[_Tok], v0: int, v1: int, text: str, rel: str
) -> list[str]:
    """String elements of a phases list: a bare name references a phase;
    anything else is an inline phase body and executes."""
    out: list[str] = []
    depth = 0
    for t in toks[v0:v1]:
        if t.kind == "punct":
            if t.text == "[":
                depth += 1
            elif t.text == "]" and depth:
                depth -= 1
        elif t.kind == "str" and depth >= 1:
            if _BARE_PHASE_NAME.match(t.text):
                continue
            out.extend(_check_shell(t.text, t.start, text, rel))
    return out


def _check_fod(
    toks: list[_Tok], close: dict[int, int], start: int, text: str, rel: str
) -> list[str]:
    """Fail-closed over names: every attr of the FOD attrset whose value is a
    direct string literal is checked, except the inert allowlist."""
    end = close[start]
    out: list[str] = []
    for name, v0, v1 in _top_assignments(toks, start, end):
        if "." in name:
            # Nested attrpath (env.CGO, meta.description, ...): env values
            # are not commands and the top-level attr governs.
            continue
        if name == "builder":
            out.extend(_check_builder(toks, v0, v1, text, rel))
        elif name in _INERT_ATTRS:
            continue
        elif name == "phases" or name.endswith("Phases"):
            out.extend(_check_phases_list(toks, v0, v1, text, rel))
        elif _is_direct_str(toks, v0, v1):
            out.extend(_check_shell(toks[v0].text, toks[v0].start, text, rel))
    return out


def _fod_trigger_names(toks: list[_Tok], start: int, end: int) -> set[str]:
    """Top-level FOD trigger names of the attrset, incl. inherit."""
    names: set[str] = set()
    for idx in range(start + 1, end):
        t = toks[idx]
        if t.kind not in ("id", "str"):
            continue
        depth = 0
        for k in range(start + 1, idx):
            if toks[k].kind == "punct":
                if toks[k].text == "{":
                    depth += 1
                elif toks[k].text == "}":
                    depth -= 1
        if depth != 0:
            continue
        if t.text in _FOD_TRIGGERS:
            if _is_assign_at(toks, idx):
                names.add(t.text)
        elif t.text == "fixedOutput":
            nxt = idx + 1
            if (
                nxt < len(toks)
                and toks[nxt].text == "="
                and nxt + 1 < len(toks)
                and toks[nxt + 1].text == "true"
            ):
                names.add("fixedOutput")
        elif t.text == "inherit":
            for n in _inherit_names(toks, idx):
                if n in _FOD_TRIGGERS | {"fixedOutput"}:
                    names.add(n)
    return names


def _command_arg_positions(toks: list[_Tok], close: dict[int, int]) -> list[int]:
    """String-arg positions of runCommand-family calls whose attrset is a FOD."""
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
        if not _fod_trigger_names(toks, open_idx, closed):
            continue
        m = closed + 1
        if m < len(toks) and toks[m].kind == "str":
            out.append(m)
    return out


def _FETCHER_CALL_HEAD(name: str) -> bool:
    """A fetcher call head: any fetch-prefixed name that is not a known
    builder (fetchMixDeps, fetchPnpmDeps, fetchNpmDeps)."""
    return len(name) > 5 and name.startswith("fetch") and name not in _BUILDER_CALLS


def _call_attrset(toks: list[_Tok], close: dict[int, int], idx: int) -> int | None:
    """Open-brace index of the call attrset for a call head id at idx.

    Tolerates an `.override { ... }` argument and a wrapping `(...)` between
    the head and the call attrset; None when the id is not a call (alias
    binding, list element, bare reference).
    """
    j = idx + 1
    while j < len(toks):
        t = toks[j]
        if t.kind == "punct":
            if t.text == "{":
                k = j - 1
                if toks[k].kind == "punct" and toks[k].text == ".":
                    k -= 1
                if toks[k].kind == "id" and toks[k].text == "override":
                    m = close.get(j)
                    if m is None:
                        return None
                    j = m + 1
                    continue
                return j
            if t.text == ")":
                j += 1
                continue
            if t.text in (";", ",", "]", "("):
                return None
        elif t.kind == "id":
            if t.text != "override":
                return None
        elif t.kind == "num":
            return None
        j += 1
    return None


def _is_builder_ref(val: list[_Tok], builder_id: str) -> bool:
    """value is exactly `<dotted path ending in builder> [.override { ... }]`."""
    p, n = 0, len(val)
    ids: list[str] = []
    while p < n and val[p].kind == "id":
        ids.append(val[p].text)
        p += 1
        # `.override { ... }` is not part of the dotted path.
        if (
            p + 1 < n
            and val[p].text == "."
            and val[p + 1].kind == "id"
            and val[p + 1].text != "override"
        ):
            p += 1
            continue
        break
    if not ids or ids[-1] != builder_id:
        return False
    if p >= n:
        return True
    if (
        val[p].text == "."
        and p + 1 < n
        and val[p + 1].kind == "id"
        and val[p + 1].text == "override"
        and p + 2 < n
        and val[p + 2].text == "{"
    ):
        p += 3
        depth = 0
        while p < n:
            if val[p].text == "{":
                depth += 1
            elif val[p].text == "}":
                depth -= 1
                if depth == 0:
                    break
            p += 1
        return p + 1 >= n
    return False


def _builder_aliases(toks: list[_Tok]) -> dict[str, str]:
    """Top-level `name = <direct reference to a builder>;` bindings.

    Covers `buildGo126Module = pkgs.buildGoModule.override { go = ...; };`
    so `buildGo126Module { ... }` is still recognized. A wrapper function
    (`myBuilder = args: pkgs.buildGoModule (args // ...);`) is not a direct
    reference and is not aliased.
    """
    aliases: dict[str, str] = {}
    depth = 0
    i = 0
    n = len(toks)
    while i < n:
        t = toks[i]
        if t.kind == "punct":
            if t.text in "{[(":
                depth += 1
            elif t.text in "}])":
                depth -= 1
            i += 1
            continue
        if depth == 0 and t.kind == "id":
            j = i
            while (
                j + 2 < n
                and toks[j + 1].kind == "punct"
                and toks[j + 1].text == "."
                and toks[j + 2].kind == "id"
            ):
                j += 2
            if j + 1 < n and toks[j + 1].text == "=":
                k = j + 2
                d = 0
                while k < n:
                    tk = toks[k]
                    if tk.kind == "punct":
                        if tk.text in "{[(":
                            d += 1
                        elif tk.text in "}])":
                            d -= 1
                        elif tk.text == ";" and d == 0:
                            break
                    k += 1
                val = toks[j + 2 : k]
                for builder_id, kind in _BUILDER_CALLS.items():
                    if _is_builder_ref(val, builder_id):
                        aliases[t.text] = kind
                        break
                i = k
                continue
        i += 1
    return aliases


def _mod_overrides(
    toks: list[_Tok], close: dict[int, int], start: int, end: int
) -> dict[str, tuple[int, int]]:
    """overrideModAttrs as a name -> value-range dict.

    Covers the attrpath form (`overrideModAttrs.preBuild = "";`) and the
    value form (`overrideModAttrs = _: { ... }`, with up to two param
    colons, or a bare attrset).
    """
    overrides: dict[str, tuple[int, int]] = {}
    for name, v0, v1 in _top_assignments(toks, start, end):
        if name == "overrideModAttrs":
            j = v0
            params = 0
            while j < v1 and params < 2:
                if (
                    toks[j].kind == "id"
                    and j + 1 < v1
                    and toks[j + 1].kind == "punct"
                    and toks[j + 1].text == ":"
                ):
                    j += 2
                    params += 1
                    continue
                break
            if j < v1 and toks[j].kind == "punct" and toks[j].text == "{":
                m = close.get(j)
                if m is not None and m <= end:
                    for n2, w0, w1 in _top_assignments(toks, j, m):
                        overrides[n2] = (w0, w1)
        elif name.startswith("overrideModAttrs."):
            overrides[name.split(".", 1)[1]] = (v0, v1)
    return overrides


def _check_named_attrs(
    toks: list[_Tok],
    close: dict[int, int],
    open_idx: int,
    attr_names: frozenset[str],
    text: str,
    rel: str,
    ctx: str,
) -> list[str]:
    """Check the direct-string values of named attrs of the call attrset."""
    closed = close[open_idx]
    out: list[str] = []
    for name, v0, v1 in _top_assignments(toks, open_idx, closed):
        if name in attr_names and _is_direct_str(toks, v0, v1):
            out.extend(_check_shell(toks[v0].text, toks[v0].start, text, rel, ctx))
    return out


def _check_go_module(
    toks: list[_Tok], close: dict[int, int], open_idx: int, text: str, rel: str
) -> list[str]:
    """Grade the vendor FOD of a buildGoModule call with vendorHash != null.

    The FOD's executed shell is the inherited attrs plus the mod*Phase,
    with overrideModAttrs applied on top: an override wins for a shared
    attr, and any other override becomes a FOD attr.
    """
    closed = close[open_idx]
    out: list[str] = []
    names: dict[str, tuple[int, int]] = {}
    for name, v0, v1 in _top_assignments(toks, open_idx, closed):
        if "." not in name:
            names.setdefault(name, (v0, v1))
    vendor = names.get("vendorHash")
    if vendor is not None and [t.text for t in toks[vendor[0] : vendor[1]]] == ["null"]:
        return out
    overrides = _mod_overrides(toks, close, open_idx, closed)
    ctx = "buildGoModule vendor FOD: "
    for name in list(names) + list(overrides):
        if name in _INERT_ATTRS:
            continue
        in_fod_set = name in _GO_MOD_FOD_ATTRS or _MOD_PHASE.match(name)
        if in_fod_set:
            rng = overrides.get(name) or names.get(name)
        elif name in overrides:
            rng = overrides[name]
        else:
            continue
        if rng is None:
            continue
        v0, v1 = rng
        if _is_direct_str(toks, v0, v1):
            out.extend(_check_shell(toks[v0].text, toks[v0].start, text, rel, ctx))
    return out


def _check_builder_calls(
    toks: list[_Tok], close: dict[int, int], text: str, rel: str
) -> list[str]:
    out: list[str] = []
    aliases = _builder_aliases(toks)
    for idx, t in enumerate(toks):
        if t.kind != "id":
            continue
        kind = _BUILDER_CALLS.get(t.text) or aliases.get(t.text)
        if kind is None and not _FETCHER_CALL_HEAD(t.text):
            continue
        open_idx = _call_attrset(toks, close, idx)
        if open_idx is None or open_idx not in close:
            continue
        line = text.count("\n", 0, t.start) + 1
        if kind is None:
            out.extend(
                _check_named_attrs(
                    toks,
                    close,
                    open_idx,
                    _FETCHER_SHELL_ATTRS,
                    text,
                    rel,
                    "fetcher FOD: ",
                )
            )
        elif kind == "mix-deps":
            out.append(
                f"{rel}:{line}: fetchMixDeps is a builder FOD - its build "
                "runs the mix dependency fetcher over the downloaded source; "
                "fetch each dependency with a no-execute fetcher instead"
            )
        elif kind == "go-module":
            out.extend(_check_go_module(toks, close, open_idx, text, rel))
        elif kind == "npm-package":
            out.extend(
                _check_named_attrs(
                    toks,
                    close,
                    open_idx,
                    _NPM_FOD_ATTRS,
                    text,
                    rel,
                    "buildNpmPackage deps FOD: ",
                )
            )
        elif kind == "all-strings":
            out.extend(_check_fod(toks, close, open_idx, text, rel))
    return out


def _check_text(text: str, rel: str = "x.nix") -> list[str]:
    toks = _tokenize(text)
    close = _brace_map(toks)
    out: list[str] = []
    for start in _fod_starts(toks):
        out.extend(_check_fod(toks, close, start, text, rel))
    for m in _command_arg_positions(toks, close):
        out.extend(_check_shell(toks[m].text, toks[m].start, text, rel))
    out.extend(_check_builder_calls(toks, close, text, rel))
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

_FOD_BUILD_COMMAND = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildCommand = ''
    make install
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_CUSTOM_PHASE = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  prePhases = [ "generateAssets" ];
  generateAssets = ''
    ./configure
  '';
}
"""

_FOD_PHASES_NAMES = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  phases = [ "unpackPhase" "patchPhase" "buildPhase" ];
  buildPhase = ''
    echo done
  '';
}
"""

_FOD_PRE_UNPACK = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  preUnpack = ''
    make
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_INSTALL_CHECK = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  installCheckPhase = ''
    ./run
  '';
}
"""

_FOD_TAR_TO_COMMAND = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  buildPhase = ''
    tar -xf s.tar --to-command=sh
  '';
}
"""

_FOD_TAR_I = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  buildPhase = ''
    tar -I ./unpack -xf s.tar
  '';
}
"""

_FOD_SORT_COMPRESS = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  buildPhase = ''
    sort --compress-program=./x a
  '';
}
"""

_FOD_FIND_EXEC_TAR = """
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  installPhase = ''
    find . -name node_modules -exec tar --to-command=sh -xf a.tar \\;
  '';
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
    export GOFLAGS=-modcacherw
    export GOTOOLCHAIN=local
    go mod download
    cd sub && go mod download && cd ..
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_GO_DOWNLOAD_NO_TOOLCHAIN = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = ''
    export GOPATH=$TMPDIR/go
    go mod download
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_GO_DOWNLOAD_PREFIXED = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = ''
    GOTOOLCHAIN=local go mod download
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

_FOD_CMD_SUB = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = ''
    echo "build: $(go version)"
  '';
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
}
"""

_FOD_INHERIT_HASH = """
pkgs.stdenv.mkDerivation rec {
  pname = "x";
  buildPhase = ''
    make all
  '';
  inherit (attrs) outputHash;
}
"""

_FOD_EVEN_BACKSLASH = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  buildPhase = ''
    echo foo \\\\
    make all
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

_RUNCMD_CC_MAKE = """
pkgs.runCommandCC "x" {
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
} ''
  gcc -o x x.c
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

_RUNCMD_NON_FOD = """
pkgs.runCommand "x" {
  args = { outputHash = "a"; };
} ''
  make all
''
"""

_QUOTED_SEMICOLON = """
pkgs.stdenvNoCC.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  installPhase = ''
    echo "done: a;b"
    mkdir $out
  '';
}
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

_FETCHER_POSTFETCH = """
{ pkgs ? import <nixpkgs> { } }:
pkgs.fetchurl {
  url = "https://example.com/a";
  hash = "sha256-A";
  postFetch = ''
    sh $out
  '';
}
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

_GOMOD_INHERITED_PREBUILD = """
pkgs.buildGoModule {
  pname = "x";
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  preBuild = ''
    go generate ./...
  '';
}
"""

_GOMOD_OVERRIDEMODATTRS = """
pkgs.buildGoModule {
  pname = "x";
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  overrideModAttrs = _: {
    preBuild = ''
      make gen
    '';
  };
}
"""

_GOMOD_CLEARED = """
let
  ui = pkgs.buildNpmPackage {
    pname = "ui";
    version = "1.0";
    src = pkgs.fetchgit {
      url = "https://example.com/thing.git";
      rev = "v1.0";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
    npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    prePatch = ''
      cd web/
    '';
    installPhase = ''
      mv build/ $out/site
    '';
  };
in
pkgs.buildGoModule {
  pname = "x";
  version = "1.0";
  src = pkgs.fetchgit {
    url = "https://example.com/thing.git";
    rev = "v1.0";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  doCheck = false;
  postPatch = ''
    sed -i 's/old/new/' Makefile
  '';
  preBuild = ''
    cp -r ${ui}/site/ server/
  '';
  overrideModAttrs.preBuild = "";
  overrideModAttrs.postPatch = "";
}
"""

_GOMOD_NULL_VENDOR = """
let
  buildGoModule26 = pkgs.buildGoModule.override { go = pkgs.go_1_26; };
in
buildGoModule26 {
  pname = "x";
  vendorHash = null;
  preBuild = ''
    go generate ./...
  '';
}
"""

_GOMOD_GOTOOLCHAIN = """
pkgs.buildGoModule {
  pname = "x";
  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  modBuildPhase = ''
    go mod download
  '';
}
"""

_FETCHPNPM_PRE = """
pkgs.fetchPnpmDeps {
  pname = "x";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  fetcherVersion = 3;
  prePnpmInstall = ''
    pnpm config set evil 1
  '';
}
"""

_FETCHNPM_PREBUILD = """
pkgs.fetchNpmDeps {
  name = "x";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  preBuild = ''
    curl -s https://example.com/x | sh
  '';
}
"""

_BUILDNPM_PREPATCH = """
pkgs.buildNpmPackage {
  pname = "x";
  version = "1.0";
  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  prePatch = ''
    make assets
  '';
}
"""

_FETCHMIXDEPS = """
pkgs.fetchMixDeps {
  name = "x";
  src = ./proj;
}
"""

_RUNCMD_INHERIT_HASH = """
pkgs.runCommand "x" {
  inherit (attrs) outputHash;
} ''
  make all
''
"""

_FOD_GO_TOOLCHAIN_ECHO = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  buildPhase = ''
    echo GOTOOLCHAIN=local
    go mod download
  '';
}
"""

_FOD_GO_TOOLCHAIN_COMMENT = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  buildPhase = ''
    go mod download # GOTOOLCHAIN=local is noted here but not set
  '';
}
"""

_FOD_GO_TOOLCHAIN_AUTO = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  buildPhase = ''
    export GOTOOLCHAIN=local
    export GOTOOLCHAIN=auto
    go mod download
  '';
}
"""

_FOD_QUOTED_ATTR = """
pkgs.stdenv.mkDerivation {
  pname = "x";
  outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  "buildPhase" = ''
    make all
  '';
}
"""

_RUNCMD_ARGS_DATA = """
pkgs.runCommand "x" {
  args = { outputHash = "a"; buildPhase = "make all"; };
} ''
  true
''
"""

_FOD_LET_BOUND = """
let
  x = {
    pname = "x";
    buildPhase = ''
      make all
    '';
    outputHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
in
x
"""

_BUILDER_ALIAS_WRAPPER = """
{ pkgs ? import <nixpkgs> { } }:
let
  myBuilder = args: pkgs.buildGoModule (args // { vendorHash = null; });
in
myBuilder {
  preBuild = ''
    make gen
  '';
}
"""


def test_make_in_fod_is_a_violation():
    v = _check_text(_FOD_MAKE)
    assert v and "make" in " ".join(v)


def test_build_command_is_checked():
    v = _check_text(_FOD_BUILD_COMMAND)
    assert v and "make" in " ".join(v)


def test_custom_phase_body_is_checked():
    v = _check_text(_FOD_CUSTOM_PHASE)
    assert v and "configure" in " ".join(v)


def test_phase_name_lists_are_not_shell():
    assert not _check_text(_FOD_PHASES_NAMES)


def test_pre_unpack_is_checked():
    v = _check_text(_FOD_PRE_UNPACK)
    assert v and "make" in " ".join(v)


def test_install_check_phase_is_checked():
    v = _check_text(_FOD_INSTALL_CHECK)
    assert v and "run" in " ".join(v)


def test_tar_to_command_is_a_violation():
    v = _check_text(_FOD_TAR_TO_COMMAND)
    assert v and "to-command" in " ".join(v)


def test_tar_I_is_a_violation():
    v = _check_text(_FOD_TAR_I)
    assert v and "compress-program" in " ".join(v)


def test_sort_compress_program_is_a_violation():
    v = _check_text(_FOD_SORT_COMPRESS)
    assert v and "compress-program" in " ".join(v)


def test_find_exec_checks_full_subcommand():
    v = _check_text(_FOD_FIND_EXEC_TAR)
    assert v and "to-command" in " ".join(v)


def test_npm_ci_needs_ignore_scripts():
    assert _check_text(_FOD_NPM_CI)
    assert not _check_text(_FOD_NPM_CI_IGNORE)


def test_go_mod_download_needs_gotoolchain_local():
    assert not _check_text(_FOD_GO_DOWNLOAD)
    assert not _check_text(_FOD_GO_DOWNLOAD_PREFIXED)
    v = _check_text(_FOD_GO_DOWNLOAD_NO_TOOLCHAIN)
    assert v and "GOTOOLCHAIN" in " ".join(v)


def test_go_mod_download_allowed_go_build_not():
    v = _check_text(_FOD_GO_BUILD)
    assert v and "go build" in " ".join(v)


def test_command_substitution_is_a_violation():
    v = _check_text(_FOD_CMD_SUB)
    assert v and "command substitution" in " ".join(v)


def test_inherited_output_hash_marks_a_fod():
    assert _check_text(_FOD_INHERIT_HASH)


def test_even_backslash_is_not_a_continuation():
    # `echo foo \\` is a complete line; the next line's make is a new
    # statement and must still be flagged.
    v = _check_text(_FOD_EVEN_BACKSLASH)
    assert v and "make" in " ".join(v)


def test_piped_curl_sh_is_a_violation():
    assert _check_text(_RUNCMD_PIPE)


def test_runcommand_cc_is_checked():
    v = _check_text(_RUNCMD_CC_MAKE)
    assert v and "gcc" in " ".join(v)


def test_curl_to_file_then_extract_is_allowed():
    assert not _check_text(_RUNCMD_DOWNLOAD)


def test_runcommand_nested_outputhash_is_not_a_fod():
    assert not _check_text(_RUNCMD_NON_FOD)


def test_separators_inside_quotes_are_not_statements():
    assert not _check_text(_QUOTED_SEMICOLON)


def test_builder_null_and_fetcher_allowed():
    assert not _check_text(_FOD_BUILDER_NULL)
    assert not _check_text(_FOD_BUILDER_FETCHER)


def test_write_text_builder_is_a_violation():
    assert _check_text(_FOD_BUILDER_WRITETEXT)


def test_fetcher_calls_are_not_fods():
    assert not _check_text(_FETCHER_CALLS)


def test_fetcher_postfetch_is_checked():
    v = _check_text(_FETCHER_POSTFETCH)
    assert v and "sh" in " ".join(v)


def test_output_hash_in_string_is_not_a_trigger():
    # ''${outputHash-}'' is a shell test of a variable, not a FOD.
    assert not _check_text(_HOOK_LIKE)


def test_find_exec_plumbing_is_allowed():
    assert not _check_text(_TEST_FIND_EXEC)


def test_gomod_inherited_prebuild_is_checked():
    v = _check_text(_GOMOD_INHERITED_PREBUILD)
    assert v and "go generate" in " ".join(v)


def test_gomod_overridemodattrs_is_checked():
    v = _check_text(_GOMOD_OVERRIDEMODATTRS)
    assert v and "make" in " ".join(v)


def test_gomod_cleared_hooks_are_green():
    assert not _check_text(_GOMOD_CLEARED)


def test_gomod_null_vendorhash_is_not_a_fod():
    assert not _check_text(_GOMOD_NULL_VENDOR)


def test_gomod_gotoolchain_rule_applies_to_mod_phases():
    v = _check_text(_GOMOD_GOTOOLCHAIN)
    assert v and "GOTOOLCHAIN" in " ".join(v)


def test_fetchpnpm_pre_pnpm_install_is_checked():
    v = _check_text(_FETCHPNPM_PRE)
    assert v and "pnpm" in " ".join(v)


def test_fetchnpm_prebuild_is_checked():
    v = _check_text(_FETCHNPM_PREBUILD)
    assert v and "sh" in " ".join(v)


def test_buildnpm_prepatch_is_checked():
    v = _check_text(_BUILDNPM_PREPATCH)
    assert v and "make" in " ".join(v)


def test_fetch_mix_deps_is_a_violation():
    v = _check_text(_FETCHMIXDEPS)
    assert v and "fetchMixDeps" in " ".join(v)


def test_runcommand_inherited_output_hash_is_checked():
    v = _check_text(_RUNCMD_INHERIT_HASH)
    assert v and "make" in " ".join(v)


def test_gotoolchain_echo_is_not_a_setting():
    v = _check_text(_FOD_GO_TOOLCHAIN_ECHO)
    assert v and "GOTOOLCHAIN" in " ".join(v)


def test_gotoolchain_comment_is_not_a_setting():
    v = _check_text(_FOD_GO_TOOLCHAIN_COMMENT)
    assert v and "GOTOOLCHAIN" in " ".join(v)


def test_gotoolchain_auto_resets():
    v = _check_text(_FOD_GO_TOOLCHAIN_AUTO)
    assert v and "GOTOOLCHAIN" in " ".join(v)


def test_quoted_attr_name_is_checked():
    v = _check_text(_FOD_QUOTED_ATTR)
    assert v and "make" in " ".join(v)


def run_command_args_data_is_not_a_fod():
    assert not _check_text(_RUNCMD_ARGS_DATA)


def test_run_command_args_data_is_not_a_fod():
    assert not _check_text(_RUNCMD_ARGS_DATA)


def test_let_bound_fod_is_checked():
    v = _check_text(_FOD_LET_BOUND)
    assert v and "make" in " ".join(v)


def test_builder_alias_wrapper_is_not_a_fod():
    assert not _check_text(_BUILDER_ALIAS_WRAPPER)
