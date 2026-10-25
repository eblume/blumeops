"""Shared loading of `mise-tasks/request-run` for the repo-tooling suite.

Run via `mise run horkos-test`. (The service's own suite moved to the
eblume/horkos repo with the extraction; only the client tooling is tested
here.) Exposed as a fixture rather than an importable helper — a habit kept
from the two-conftest era, and still the collision-proof shape.
"""

import importlib.machinery
import importlib.util
import os
import pathlib
import shlex
import subprocess

import pytest

ROOT = pathlib.Path(__file__).resolve().parent.parent


@pytest.fixture(scope="session")
def request_run():
    """mise tasks are extensionless, so spec_from_file_location can't infer a
    loader — name one. Importing is safe: typer.run() is under __main__."""
    loader = importlib.machinery.SourceFileLoader(
        "request_run", str(ROOT / "mise-tasks" / "request-run")
    )
    spec = importlib.util.spec_from_loader("request_run", loader)
    if spec is None:
        raise RuntimeError("could not build an import spec")
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


_SHELLS = {"sh", "bash", "dash", "zsh"}
# git's options that consume the following token.
_GIT_VALUE_OPTS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
_NETWORK_SUBCOMMANDS = {"fetch", "pull"}


def _argv(args, shell) -> list[str]:
    if isinstance(args, (str, bytes)):
        text = os.fsdecode(args)
        try:
            return shlex.split(text)
        except ValueError:  # unbalanced quoting in a shell script: scan loosely
            return text.split()
    return [os.fsdecode(os.fspath(a)) for a in args]


def _git_subcommand(argv: list[str], start: int) -> str | None:
    """The subcommand after a `git` token at `start`, skipping global options."""
    i = start + 1
    while i < len(argv):
        tok = argv[i]
        if tok in _GIT_VALUE_OPTS:
            i += 2
        elif tok.startswith("-"):
            i += 1
        else:
            return tok
    return None


def _is_git_fetch(args, shell=False) -> bool:
    """True when a git invocation in argv (by any path, possibly behind a
    wrapper such as `env`, or inside `sh -c`) runs a network subcommand."""
    argv = _argv(args, shell)
    if shell and len(argv) == 1:
        # subprocess with shell=True hands the whole string to /bin/sh.
        argv = _argv(argv[0], False)
    for i, tok in enumerate(argv):
        if (
            os.path.basename(tok) == "git"
            and _git_subcommand(argv, i) in _NETWORK_SUBCOMMANDS
        ):
            return True
        if os.path.basename(tok) in _SHELLS and "-c" in argv[i + 1 :]:
            payload = argv[argv.index("-c", i + 1) + 1 :]
            if payload and _is_git_fetch(payload[0], False):
                return True
    return False


class _NoFetchPopen(subprocess.Popen):
    def __init__(self, args, *a, shell=False, env=None, **kw):
        if _is_git_fetch(args, shell):
            raise AssertionError(f"tests must stub the fetch: {args!r}")
        if env is not None:
            env = {**env, "GIT_ALLOW_PROTOCOL": "file"}
        super().__init__(args, *a, shell=shell, env=env, **kw)


@pytest.fixture(autouse=True)
def _forbid_real_git_fetch(monkeypatch):
    """Fail any test that issues a real `git fetch` instead of stubbing it.

    Patching Popen covers the in-process subprocess API. GIT_ALLOW_PROTOCOL
    covers child processes (repo scripts), which the patch cannot see: a
    network fetch from them fails, while file-protocol git keeps working.
    """
    monkeypatch.setattr(subprocess, "Popen", _NoFetchPopen)
    monkeypatch.setenv("GIT_ALLOW_PROTOCOL", "file")
