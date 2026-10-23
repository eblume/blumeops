"""Invariant: no instance values in component source of eblume/talos and
eblume/horkos (eblu.me hostnames, the tailnet hostname, the owner name
``eblume``, 1Password ``op://`` refs), including prompt strings; comments
(whole-line and trailing), docstrings and test files exempt."""

from __future__ import annotations

import ast
import io
import pathlib
import re
import tokenize

KIND = "invariant"
APPLIES_TO = ["eblume/talos", "eblume/horkos"]

BANNED = re.compile(r"eblu\.me|eblume|op://|tail8d86e\.ts\.net", re.IGNORECASE)
COMPONENT_DIRS = ("src", "prompts", "app")

_DOCSTRING_OWNERS = (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)


def _is_test(name: str) -> bool:
    return (
        name.endswith(
            (".test.ts", ".test.js", ".test.tsx", ".spec.ts", ".spec.js", ".spec.tsx")
        )
        or name.endswith(".py")
        and (name.startswith("test_") or name.endswith("_test.py"))
    )


def _flag(violations, rel, lineno, line, segs):
    if any(BANNED.search(s) for s in segs):
        violations.append(f"{rel}:{lineno}: {line.strip()[:120]}")


# --- python: stdlib ast + tokenize ---


def _docstring_ranges(tree):
    """(start_line, start_col, end_line, end_col) of docstrings: a plain
    string constant as the first statement of a module, class or function —
    horkos's linter uses the same definition, so a paren-wrapped prompt
    value (an Assign, not an Expr) stays scannable."""
    out = []
    for node in ast.walk(tree):
        if isinstance(node, _DOCSTRING_OWNERS):
            body = node.body
            if (
                body
                and isinstance(body[0], ast.Expr)
                and isinstance(body[0].value, ast.Constant)
                and isinstance(body[0].value.value, str)
            ):
                d = body[0].value
                out.append((d.lineno, d.col_offset, d.end_lineno, d.end_col_offset))
    return out


def _comment_ranges(source: str):
    out = []
    try:
        for tok in tokenize.generate_tokens(io.StringIO(source).readline):
            if tok.type == tokenize.COMMENT:
                out.append((tok.start[0], tok.start[1], tok.end[0], tok.end[1]))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        pass
    return out


def _bcol(line: str, bcol: int) -> int:
    # ast/tokenize cols are UTF-8 byte offsets; back to a char index.
    return len(line.encode("utf-8")[:bcol].decode("utf-8", errors="ignore"))


def _exempt_char_ranges(src_lines: list[str], ranges) -> list[list[tuple[int, int]]]:
    """Per line (0-based), the merged-irrelevant char ranges that are
    docstring text or comments: the line minus those is what gets scanned."""
    per_line: list[list[tuple[int, int]]] = [[] for _ in src_lines]
    for sl, sc, el, ec in ranges:
        for li in range(sl - 1, min(el, len(src_lines))):
            line = src_lines[li]
            start = _bcol(line, sc) if li == sl - 1 else 0
            end = _bcol(line, ec) if li == el - 1 else len(line)
            if start < end:
                per_line[li].append((start, end))
    return per_line


def _line_segments(line: str, exempt: list[tuple[int, int]]) -> list[str]:
    kept: list[tuple[int, int]] = []
    pos = 0
    for s, e in sorted(exempt):
        s = max(s, pos)
        e = min(e, len(line))
        if s < e:
            kept.append((s, e))
            pos = e
    segs = []
    pos = 0
    for s, e in kept:
        if pos < s:
            segs.append(line[pos:s])
        pos = e
    if pos < len(line):
        segs.append(line[pos:])
    return segs


def _scan_py(rel: str, lines: list[str], violations: list[str]) -> None:
    source = "\n".join(lines)
    try:
        tree = ast.parse(source)
    except SyntaxError:
        # Malformed file: no docstring exemption, comment lines still are.
        for lineno, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue
            _flag(violations, rel, lineno, line, [line])
        return
    exempt = _exempt_char_ranges(
        lines, _docstring_ranges(tree) + _comment_ranges(source)
    )
    for lineno, line in enumerate(lines, 1):
        _flag(violations, rel, lineno, line, _line_segments(line, exempt[lineno - 1]))


# --- typescript: line-oriented, backtick state carried across lines ---


def _unescaped_backticks(line: str) -> int:
    n = i = 0
    while i < len(line):
        if line[i] == "\\":
            i += 2
            continue
        if line[i] == "`":
            n += 1
        i += 1
    return n


def _first_unescaped_backtick(line: str) -> int:
    i = 0
    while i < len(line):
        if line[i] == "\\":
            i += 2
            continue
        if line[i] == "`":
            return i
        i += 1
    return -1


def _ts_code_portion(line: str) -> tuple[str, bool, bool]:
    """(scannable portion, next block-comment state, end-of-line template
    state) for a TS line that does not start with a comment. Stops at the
    first // or opens a carried block comment at the first /* outside a
    string or template literal; comment text is dropped from the scannable
    portion. The third element is the walker's in_tpl value at the return
    point: backticks inside quoted strings or dropped comments never
    toggle it."""
    out: list[str] = []
    last = i = 0
    n = len(line)
    quote = None
    in_tpl = False
    while i < n:
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if in_tpl:
            if c == "\\":
                i += 2
                continue
            if c == "`":
                in_tpl = False
            i += 1
            continue
        if c in "'\"":
            quote = c
        elif c == "`":
            in_tpl = True
        elif c == "/" and i + 1 < n and line[i + 1] == "/":
            out.append(line[last:i])
            return "".join(out), False, in_tpl
        elif c == "/" and i + 1 < n and line[i + 1] == "*":
            j = line.find("*/", i + 2)
            if j == -1:
                out.append(line[last:i])
                return "".join(out), True, in_tpl
            out.append(line[last:i])
            last = i = j + 2
            continue
        i += 1
    out.append(line[last:])
    return "".join(out), False, in_tpl


def _ts_segments(
    line: str, in_block: bool, in_template: bool
) -> tuple[list[str], bool, bool]:
    """(code segments, next block-comment state, next template state) for
    one TS/JS/TSX line. Inside a template literal the line is prompt
    content: comment rules do not apply. An even count of unescaped
    backticks keeps the line in the template; an odd count closes it on
    this line, so the code after the first unescaped backtick gets the
    usual comment handling and the next state comes from the code
    scanner. Outside a template the state comes from the code scanner,
    which ignores backticks inside quoted strings and dropped
    comments."""
    if in_template:
        if _unescaped_backticks(line) % 2 == 0:
            return [line], in_block, True
        pos = _first_unescaped_backtick(line)
        portion, next_block, in_tpl = _ts_code_portion(line[pos + 1 :])
        segs = [line[: pos + 1]]
        if portion:
            segs.append(portion)
        return segs, next_block, in_tpl
    if in_block:
        j = line.find("*/")
        if j == -1:
            return [], True, in_template
        code = line[j + 2 :]
        portion, next_block, in_tpl_at_end = _ts_code_portion(code)
        return [portion], next_block, in_tpl_at_end
    t = line.lstrip()
    if t.startswith("//"):  # whole-line comment
        return [], False, in_template
    if t.startswith("/*"):
        j = t.find("*/")
        if j == -1:
            return [], True, in_template
        code = line[len(line) - len(t) + j + 2 :]
        portion, next_block, in_tpl_at_end = _ts_code_portion(code)
        return [portion], next_block, in_tpl_at_end
    code, next_block, in_tpl_at_end = _ts_code_portion(line)
    return [code], next_block, in_tpl_at_end


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
                _scan_py(rel, lines, violations)
            elif p.suffix in (".ts", ".js", ".tsx"):
                block_state = False
                template_state = False
                for lineno, line in enumerate(lines, 1):
                    segs, block_state, template_state = _ts_segments(
                        line, block_state, template_state
                    )
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


def test_template_literal_bullet_is_scanned(tmp_path: pathlib.Path) -> None:
    # A `*` bullet line inside a template literal is prompt content, not a
    # JSDoc continuation: the banned hostname in it is flagged.
    p = tmp_path / "src"
    p.mkdir()
    (p / "w.ts").write_text(
        "export function workStyle(): string {\n"
        "  return `## Forge\n"
        "\n"
        "* push to https://forge.ops.eblu.me\n"
        "  `;\n"
        "}\n"
    )
    assert len(check(tmp_path)) == 1


def test_template_literal_slash_comment_is_scanned(tmp_path: pathlib.Path) -> None:
    # A `//` line inside a template literal is prompt content, not a
    # comment: the banned owner name in it is flagged.
    p = tmp_path / "src"
    p.mkdir()
    (p / "p.ts").write_text(
        "const PROMPT = `You are the release agent.\n"
        "// ask eblume first\n"
        "`;\n"
        "export { PROMPT };\n"
    )
    assert len(check(tmp_path)) == 1


def test_comment_after_template_closer_stays_exempt(tmp_path: pathlib.Path) -> None:
    # Backtick parity restores code state after the closer, so the
    # whole-line comment that follows is still exempt.
    p = tmp_path / "src"
    p.mkdir()
    (p / "m.ts").write_text(
        "const PROMPT = `line one.\n"
        "`;\n"
        "// eblume/talos#252 owns this\n"
        "const n = 1;\n"
        "export { PROMPT, n };\n"
    )
    assert check(tmp_path) == []


def test_trailing_comment_after_template_closer_is_exempt(
    tmp_path: pathlib.Path,
) -> None:
    # Code on the template-closer line gets the usual comment handling.
    p = tmp_path / "src"
    p.mkdir()
    (p / "c.ts").write_text("const p = `x\n`; // eblume/talos#252\nexport { p };\n")
    assert check(tmp_path) == []


def test_block_comment_after_template_closer_is_tracked(tmp_path: pathlib.Path) -> None:
    # A block comment opened on the template-closer line carries: its
    # continuation line is comment, not code.
    p = tmp_path / "src"
    p.mkdir()
    (p / "d.ts").write_text(
        "const p = `x\n`; /*\n* forge.ops.eblu.me is the instance host\n*/\nexport { p };\n"
    )
    assert check(tmp_path) == []


def test_backtick_inside_quoted_string_does_not_flip_template_state(
    tmp_path: pathlib.Path,
) -> None:
    # A backtick inside a quoted string on a code line is string content,
    # not a template delimiter: the whole-line comment that follows is
    # still exempt.
    p = tmp_path / "src"
    p.mkdir()
    (p / "q.ts").write_text(
        'const cmd = "a`b";\n// eblume/talos#252 owns this\nexport { cmd };\n'
    )
    assert check(tmp_path) == []


def test_trailing_comment_is_exempt(tmp_path: pathlib.Path) -> None:
    # A trailing comment is prose, not shipped: the issue ref in it is fine.
    p = tmp_path / "src"
    p.mkdir()
    (p / "t.ts").write_text(
        'const API_BASE = "https://forge.example.com/api"; // see eblume/talos#252\n'
        "const port = 8080;\n"
        "export { API_BASE, port };\n"
    )
    assert check(tmp_path) == []


def test_trailing_comment_after_block_closer_is_exempt(tmp_path: pathlib.Path) -> None:
    # The code after a block-comment closer that runs mid-line still gets
    # the trailing-comment exemption, like any other code line.
    p = tmp_path / "src"
    p.mkdir()
    (p / "b.ts").write_text(
        "/* multi\nline */ const x = 1; // eblume/talos#252\nexport { x };\n"
    )
    assert check(tmp_path) == []


def test_trailing_comment_with_url_still_scans_code(tmp_path: pathlib.Path) -> None:
    # Only the banned string value on line 2 flags; line 1's comment is exempt.
    p = tmp_path / "src"
    p.mkdir()
    (p / "u.ts").write_text(
        'const API_BASE = "https://forge.example.com"; // eblu.me is the instance domain\n'
        'const x = "https://forge.ops.eblu.me"; // eblume\n'
    )
    assert len(check(tmp_path)) == 1


def test_paren_wrapped_prompt_is_scanned(tmp_path: pathlib.Path) -> None:
    # A paren-wrapped prompt value is an Assign, not the module docstring,
    # so the banned owner name in it is flagged.
    p = tmp_path / "app"
    p.mkdir()
    (p / "a.py").write_text(
        "PROMPT = (\n"
        '    """\n'
        "    Ask eblume about the instance first.\n"
        '    """\n'
        ")\n"
        'DEFAULT = "forge.example.com"\n'
    )
    assert len(check(tmp_path)) == 1


def test_trailing_py_comment_is_exempt(tmp_path: pathlib.Path) -> None:
    # The trailing comment on line 1 is prose: no hit.
    p = tmp_path / "app"
    p.mkdir()
    (p / "s.py").write_text(
        'DEFAULT_HOST = "forge.example.com"  # erich@example.org is the operator\n'
        "\n"
        "def serve():\n"
        "    return DEFAULT_HOST\n"
    )
    assert check(tmp_path) == []
