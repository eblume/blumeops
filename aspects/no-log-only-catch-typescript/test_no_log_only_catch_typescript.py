"""Log-only catch clauses in TypeScript, via tree-sitter. See ASPECT.md."""

from __future__ import annotations

import os
import pathlib

import tree_sitter as ts
import tree_sitter_typescript as tstypescript

KIND = "ratchet"
APPLIES_TO = ["eblume/talos"]

_TS_PARSER = ts.Parser(ts.Language(tstypescript.language_typescript()))
_TSX_PARSER = ts.Parser(ts.Language(tstypescript.language_tsx()))
_CONSOLE_METHODS = frozenset({"log", "info", "warn", "error", "debug", "trace"})
_LOGGER_METHODS = frozenset(
    {
        "debug",
        "info",
        "warn",
        "warning",
        "error",
        "exception",
        "critical",
        "log",
        "trace",
    }
)
_LOGGER_RECEIVERS = frozenset({"logger", "log", "_log", "_logger"})
_METRIC_METHODS = frozenset({"inc", "observe"})
_SKIP_DIRS = frozenset({"node_modules", "dist", "build", "coverage"})
_EXEMPT_SUFFIXES = (".test.ts", ".test.tsx", ".spec.ts", ".spec.tsx", ".d.ts")
_SCOPES = ("function_declaration", "class_declaration", "method_definition")
_FUNCTION_VALUES = ("arrow_function", "function", "function_expression")


def _text(node: ts.Node | None) -> str:
    if node is None or node.text is None:
        return ""
    return node.text.decode()


def _last_name(node: ts.Node | None) -> str:
    if node is None:
        return ""
    if node.type == "identifier":
        return _text(node)
    if node.type == "member_expression":
        return _text(node.child_by_field_name("property"))
    return ""


def _is_logging_call(call: ts.Node) -> bool:
    fn = call.child_by_field_name("function")
    if fn is None or fn.type != "member_expression":
        return False
    method = _text(fn.child_by_field_name("property"))
    receiver = fn.child_by_field_name("object")
    if receiver is not None and _text(receiver) == "console":
        return method in _CONSOLE_METHODS
    return (
        method in _LOGGER_METHODS and _last_name(receiver).lower() in _LOGGER_RECEIVERS
    )


def _is_handling_call(call: ts.Node) -> bool:
    fn = call.child_by_field_name("function")
    if fn is None:
        return False
    if "ntfy" in _text(fn).lower():
        return True
    return (
        fn.type == "member_expression"
        and _text(fn.child_by_field_name("property")) in _METRIC_METHODS
    )


def _log_only(block: ts.Node) -> bool:
    saw_log = False
    for stmt in block.named_children:
        if stmt.type == "comment":
            continue
        if stmt.type != "expression_statement":
            return False
        exprs = stmt.named_children
        if (
            len(exprs) != 1
            or exprs[0].type != "call_expression"
            or not _is_logging_call(exprs[0])
        ):
            return False
        saw_log = True
    return saw_log


def _handles(block: ts.Node) -> bool:
    stack = [block]
    while stack:
        node = stack.pop()
        if node.type in ("throw_statement", "return_statement"):
            return True
        if node.type == "call_expression" and _is_handling_call(node):
            return True
        stack.extend(node.children)
    return False


def _is_function_binding(declarator: ts.Node) -> bool:
    value = declarator.child_by_field_name("value")
    name = declarator.child_by_field_name("name")
    return (
        value is not None
        and value.type in _FUNCTION_VALUES
        and name is not None
        and name.type == "identifier"
    )


def _scan_file(path: pathlib.Path, root: pathlib.Path, out: list[str]) -> None:
    rel = path.relative_to(root).as_posix()
    parser = _TSX_PARSER if path.suffix == ".tsx" else _TS_PARSER
    tree = parser.parse(path.read_bytes())
    ordinals: dict[str, int] = {}

    def visit(node: ts.Node, scope: tuple[str, ...]) -> None:
        for child in node.children:
            if child.type == "catch_clause":
                body = child.child_by_field_name("body")
                if body is not None and _log_only(body):
                    name = ".".join(scope) or "<module>"
                    ordinal = ordinals.get(name, 0)
                    ordinals[name] = ordinal + 1
                    if not _handles(body):
                        out.append(f"{rel}::{name}#{ordinal}")
                visit(child, scope)
            elif child.type in _SCOPES:
                name_node = child.child_by_field_name("name")
                scope_name = (
                    _text(name_node) if name_node is not None else "<anonymous>"
                )
                visit(child, scope + (scope_name,))
            elif child.type == "variable_declarator" and _is_function_binding(child):
                visit(child, scope + (_text(child.child_by_field_name("name")),))
            else:
                visit(child, scope)

    visit(tree.root_node, ())


def _ts_files(root: pathlib.Path):
    for dirpath, dirnames, filenames in os.walk(root):
        at_root = os.path.relpath(dirpath, root) == "."
        dirnames[:] = sorted(
            d
            for d in dirnames
            if d not in _SKIP_DIRS
            and not d.startswith(".")
            and not (at_root and d == "aspects")
        )
        for name in sorted(filenames):
            if not name.endswith((".ts", ".tsx")) or name.endswith(_EXEMPT_SUFFIXES):
                continue
            yield pathlib.Path(dirpath) / name


def check(root: pathlib.Path) -> list[str]:
    out: list[str] = []
    for path in _ts_files(root):
        _scan_file(path, root, out)
    return out
