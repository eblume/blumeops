"""Log-only except handlers in Python, via tree-sitter. See ASPECT.md."""

from __future__ import annotations

import os
import pathlib

import tree_sitter as ts
import tree_sitter_python as tspy

KIND = "ratchet"
APPLIES_TO = ["eblume/horkos"]

_PARSER = ts.Parser(ts.Language(tspy.language()))
_LOG_METHODS = frozenset(
    {"debug", "info", "warning", "warn", "error", "exception", "critical"}
)
_LOG_RECEIVERS = frozenset({"logging", "logger", "log", "_log", "_logger"})
_METRIC_METHODS = frozenset({"inc", "observe"})
_SKIP_DIRS = frozenset({"node_modules", "__pycache__", "dist", "build", "venv"})
_SCOPES = ("function_definition", "class_definition")


def _text(node: ts.Node | None) -> str:
    if node is None or node.text is None:
        return ""
    return node.text.decode()


def _last_name(node: ts.Node | None) -> str:
    if node is None:
        return ""
    if node.type == "identifier":
        return _text(node)
    if node.type == "attribute":
        return _text(node.child_by_field_name("attribute"))
    return ""


def _is_logging_call(call: ts.Node) -> bool:
    fn = call.child_by_field_name("function")
    if fn is None:
        return False
    if fn.type == "identifier":
        return _text(fn) == "print"
    if fn.type == "attribute":
        method = _text(fn.child_by_field_name("attribute"))
        receiver = _last_name(fn.child_by_field_name("object")).lower()
        return method in _LOG_METHODS and receiver in _LOG_RECEIVERS
    return False


def _is_handling_call(call: ts.Node) -> bool:
    fn = call.child_by_field_name("function")
    if fn is None:
        return False
    if "ntfy" in _text(fn).lower():
        return True
    return (
        fn.type == "attribute"
        and _text(fn.child_by_field_name("attribute")) in _METRIC_METHODS
    )


def _log_only(block: ts.Node) -> bool:
    saw_log = False
    for stmt in block.named_children:
        if stmt.type == "comment":
            continue
        if stmt.type != "expression_statement":
            return False
        exprs = stmt.named_children
        if len(exprs) != 1 or exprs[0].type != "call" or not _is_logging_call(exprs[0]):
            return False
        saw_log = True
    return saw_log


def _handles(block: ts.Node) -> bool:
    stack = [block]
    while stack:
        node = stack.pop()
        if node.type in ("raise_statement", "return_statement"):
            return True
        if node.type == "call" and _is_handling_call(node):
            return True
        stack.extend(node.children)
    return False


def _scan_file(path: pathlib.Path, root: pathlib.Path, out: list[str]) -> None:
    rel = path.relative_to(root).as_posix()
    tree = _PARSER.parse(path.read_bytes())
    ordinals: dict[str, int] = {}

    def visit(node: ts.Node, scope: tuple[str, ...]) -> None:
        for child in node.children:
            if child.type == "except_clause":
                block = next((c for c in child.children if c.type == "block"), None)
                if block is None or not _log_only(block):
                    visit(child, scope)
                    continue
                name = ".".join(scope) or "<module>"
                ordinal = ordinals.get(name, 0)
                ordinals[name] = ordinal + 1
                if not _handles(block):
                    out.append(f"{rel}::{name}#{ordinal}")
                visit(child, scope)
            elif child.type in _SCOPES:
                name_node = child.child_by_field_name("name")
                scope_name = _text(name_node) if name_node is not None else "<unparsed>"
                visit(child, scope + (scope_name,))
            else:
                visit(child, scope)

    visit(tree.root_node, ())


def _python_files(root: pathlib.Path):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(
            d for d in dirnames if d not in _SKIP_DIRS and not d.startswith(".")
        )
        for name in sorted(filenames):
            if not name.endswith(".py"):
                continue
            if (
                name.startswith("test_")
                or name.endswith("_test.py")
                or name == "conftest.py"
            ):
                continue
            yield pathlib.Path(dirpath) / name


def check(root: pathlib.Path) -> list[str]:
    out: list[str] = []
    for path in _python_files(root):
        _scan_file(path, root, out)
    return out
