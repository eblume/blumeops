"""Eval-based FOD check — CLI (docs/explanation/talos-v0.5/fod-eval-check.md).

Instantiate every entry point of the blumeops nix trees (the ringtail flake's
toplevel, the darwin/indri flake's toplevel, every containers/*/default.nix),
walk `nix derivation show -r` over each result with
`--option allow-import-from-derivation false` on every eval (an IFD becomes
an eval error -> red), classify every fixed-output/impure derivation against
template shapes evaluated from the *same* nixpkgs source as the entry point
plus the hand-written catalogue, and inspect the setup hooks of the evaluated
inputs. Fail closed: anything unrecognised — and evaluation errors themselves
— is a violation. Exit 0 iff zero violations AND zero eval errors.

Trust anchor: every nixpkgs source used as a template is
authenticated by its locked identity — github:NixOS/nixpkgs (or the
equivalent https://github.com/NixOS/nixpkgs / git+https … spelling) for flake
inputs and containers/flake.lock, the strict https://github.com/NixOS/nixpkgs/
archive/<40 hex>.tar.gz pattern for the self-pinning containers. A source
that is used but cannot be authenticated is a red entry point; the catalogue
file list is closed in code. No rev is pinned — any genuine NixOS/nixpkgs
pin is acceptable (rev changes are human-reviewed in the diff).

Usage:
    check.py [--repo DIR] [--flake-src REF] [--store PATH] [--self-test]

In CI the default host refs are the plain relative path refs (`./nixos/
ringtail`, `./darwin/indri`, `./containers`) exactly as the runner spike used
them. In-pod the worktree is not libgit2-readable (repo files owned by another
uid), so pass `--flake-src git+file:///abs/path` pointing at a git copy of
the repo; host flake refs are then derived as `git+file://…?dir=…` refs.

The store: `--store PATH` (or `FOD_EVAL_CHECK_STORE`) wins; otherwise the
default store is used when usable, and a local store under
`$XDG_CACHE_HOME/fod-eval-check-store` is created automatically when the
default store is not writable (a landlock'd talos pod: `/nix` is read-only).
The CI path — no overrides, the default store — is unchanged. See the README.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

from classify import classify_walk, is_fod, walk_drvs

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent

# System pin: the deployment target. Containers instantiate for this system on
# any runner (`nix-instantiate --system` overrides builtins.currentSystem); the
# ringtail flake is x86_64-linux by declaration, the darwin flake aarch64-darwin
# (cross-eval on the fallback runner; eval builds nothing).
PINNED_SYSTEM = "x86_64-linux"
# The system variant a host flake's closure mixes in (ringtail's steam /
# graphics-drivers multilib): the i686 packages of the same sources.
MULTILIB_SYSTEM = "i686-linux"

FEATURES_EVAL = "nix-command flakes"
# impure-derivations + ca-derivations so `nix derivation show` serialises an
# unhashed impure output as `outputs.*.impure: true`; harmless everywhere else.
FEATURES_WALK = "nix-command impure-derivations ca-derivations"

# The closed catalogue list: the only hand-written FODs the
# enumerations carry. Adding an entry = editing this declared set in the same
# reviewed diff. `catalogues()` fails red if the directory holds any other
# file, or if a declared pname has no file.
DECLARED_CATALOGUE = frozenset({"alloy-go-modules", "authentik-webui-deps"})


# Canonical identities of a template nixpkgs source. Flake
# lock `original` dictionaries accepted: github:NixOS/nixpkgs in any of its
# spellings. No rev/ref requirement — rev changes are reviewed in the diff.
def _canonical_identity(original: dict | None) -> bool:
    if not isinstance(original, dict):
        return False
    t = original.get("type")
    if t == "github":
        return original.get("owner") == "NixOS" and original.get("repo") == "nixpkgs"
    if t == "git" and original.get("url"):
        url = original["url"].removeprefix("git+file://").removeprefix("git+")
        url = url.removesuffix(".git")
        return url in ("https://github.com/NixOS/nixpkgs", "github.com/NixOS/nixpkgs")
    return False


def _lock_node_identity(lock: dict, name: str) -> dict | None:
    nodes = lock.get("nodes", {})
    root_inputs = nodes.get("root", {}).get("inputs", {})
    nid = root_inputs.get(name)
    if isinstance(nid, str):
        return nodes.get(nid, {}).get("original")
    if isinstance(nid, dict):
        return nid.get("original")
    return None


# The template bundle expression: canonical instances of every known shape,
# evaluated from the entry point's own pkgs (`{pkgsSource}` is the nix
# expression yielding those pkgs). NAT entries are optional per context; the
# fetchpatch/fetchgithub/fetchzip variants are the fetcher shapes the real
# closures contain (verified against ringtail/darwin/meanie/paperless/prowler).
_TEMPLATE_EXPR = r"""
let
  pkgs = {pkgsSource};
  fakeSrc = pkgs.runCommand "fodcheck-src" {} ''
    mkdir -p $out
    printf 'module fodcheck\n\ngo 1.21\n' > $out/go.mod
    printf '[package]\nname = "fodcheck"\nversion = "0.0.0"\nedition = "2021"\n' > $out/Cargo.toml
    printf 'version = 3\n\n[[package]]\nname = "fodcheck"\nversion = "0.0.0"\nsource = "registry+https://github.com/rust-lang/crates.io-index"\nchecksum = "d2b4f6896570dfcfb29919befd28d547ea7349a"\n' > $out/Cargo.lock
  '';
  jsonSrc = pkgs.runCommand "fodcheck-jsonsrc" {} ''
    mkdir -p $out
    printf '{}\n' > $out/package.json
    printf 'lockfileVersion: 9.0\n' > $out/pnpm-lock.yaml
  '';
  yarnSrc = pkgs.runCommand "fodcheck-yarn" {} "printf '# yarn lockfile v1\n' > $out";
  # NAT entries are optional per context: a nixpkgs-native attribute may be
  # absent, or present but refused on the context's host platform (e.g. the
  # linux-only minimal-bootstrap hex0 on aarch64-darwin pkgs) — tryEval keeps
  # the bundle evaluable, and a walk FOD claiming the name then has no
  # template to match and fails closed. tryEval only forces WHNF, so force the
  # drvPath (which is where the check-meta platform refusal fires).
  tryEval_ = e: let r = builtins.tryEval (e.drvPath); in if r.success then e else null;
  # fetchPnpmDeps' supported fetcherVersion differs per nixpkgs rev (and per
  # pnpm major): attempt the versions the tree's closures are known to use.
  pnpmBase = { pname = "fodcheck"; version = "0.0.0"; src = jsonSrc; hash = pkgs.lib.fakeHash; };
  tryPnpm = args0:
    let cand = builtins.tryEval (pkgs.fetchPnpmDeps (pnpmBase // args0));
    in if cand.success then cand.value else null;
  pnpmDrv = builtins.foldl' (acc: a: if acc != null then acc else tryPnpm a) null [
    { fetcherVersion = 3; }
    { fetcherVersion = 3; pnpm = pkgs.pnpm_10; }
    { fetcherVersion = 4; }
  ];
in
builtins.filter (d: d != null) [
  # Order must match _TEMPLATE_NAME_MAP; templates are mapped back by drv name.
  (pkgs.fetchurl { name = "fodcheck-fetchurl"; url = "https://example.com/"; sha256 = "0000000000000000000000000000000000000000000000000000"; })
  (pkgs.fetchzip { name = "fodcheck-fetchzip"; url = "https://example.com/"; sha256 = "0000000000000000000000000000000000000000000000000000"; })
  (pkgs.fetchzip { name = "fodcheck-fetchzip-nostrip"; url = "https://example.com/archive.zip"; sha256 = "0000000000000000000000000000000000000000000000000000"; stripRoot = false; })
  (pkgs.fetchpatch { name = "fodcheck-patch"; url = "https://example.com/f.patch"; hash = pkgs.lib.fakeHash; })
  (if pkgs ? fetchpatch2 then (pkgs.fetchpatch2 { name = "fodcheck-patch2"; url = "https://example.com/f.patch"; hash = pkgs.lib.fakeHash; }) else (pkgs.fetchpatch { name = "fodcheck-patch2"; url = "https://example.com/f.patch"; hash = pkgs.lib.fakeHash; }))
  (pkgs.fetchgit { name = "fodcheck-fetchgit"; url = "https://example.com/repo.git"; rev = "61f98e459f7f9d5fad6a79992f0dd310de359e10"; hash = pkgs.lib.fakeHash; })
  # NB: fetchFromGitHub is makeOverridable-wrapped and ignores an outer
  # overrideAttrs name; its template drv names itself `source` here (the
  # url-derived default), mapped below.
  (pkgs.fetchFromGitHub { owner = "fodcheck"; repo = "fodcheckfgh"; rev = "61f98e459f7f9d5fad6a79992f0dd310de359e10"; hash = pkgs.lib.fakeHash; })
  ((pkgs.fetchhg { url = "https://example.com/hg"; rev = "0.1.0"; hash = pkgs.lib.fakeHash; }).overrideAttrs (o: { name = "fodcheck-fetchhg"; }))
  (pkgs.fetchsvn { name = "fodcheck-fetchsvn"; url = "https://example.com/svn"; rev = "1"; sha256 = pkgs.lib.fakeSha256; })
  (pkgs.fetchNpmDeps { name = "fodcheck-npmdeps"; src = jsonSrc; hash = pkgs.lib.fakeHash; })
  pnpmDrv
  ((pkgs.buildGoModule { pname = "fodcheck"; version = "0.0.0"; src = fakeSrc; vendorHash = pkgs.lib.fakeHash; }).goModules)
  ((pkgs.buildGoModule { pname = "fodcheck-proxy"; version = "0.0.0"; src = fakeSrc; vendorHash = pkgs.lib.fakeHash; proxyVendor = true; }).goModules)
  ((pkgs.caddy.withPlugins { plugins = []; }).src)
  ((pkgs.rustPlatform.buildRustPackage { pname = "fodcheck"; version = "0.0.0"; src = fakeSrc; cargoHash = pkgs.lib.fakeHash; }).cargoDeps.vendorStaging)
  (pkgs.fetchYarnDeps { name = "fodcheck-yarn"; yarnLock = yarnSrc; sha256 = pkgs.lib.fakeSha256; })
  (tryEval_ pkgs.cantarell-fonts)
  (tryEval_ pkgs.minimal-bootstrap.stage0-posix.hex0)
  (tryEval_ pkgs.minimal-bootstrap-sources.minimal-bootstrap-sources)
  (tryEval_ pkgs.emptyDirectory)
  (tryEval_ pkgs.dart.src)
  (tryEval_ pkgs.tesseract.languages.all)
]
"""

_TEMPLATE_FAMILIES = (
    "fetchurl",
    "fetchzip",
    "fetchpatch",
    "fetchgit",
    "fetchgithub",
    "fetchhg",
    "fetchsvn",
    "npmDeps",
    "pnpmDeps",
    "goModules",
    "caddyDeps",
    "cargoDeps",
    "yarnDeps",
)


# template drv-name prefix -> template label (the classifier keys)
_TEMPLATE_NAME_MAP = (
    ("fodcheck-fetchurl", "fetchurl"),
    ("fodcheck-fetchzip-nostrip", "fetchzip"),
    ("fodcheck-fetchzip", "fetchzip"),
    ("fodcheck-patch", "fetchpatch"),
    ("fodcheck-fetchgit", "fetchgit"),
    ("source", "fetchgithub"),
    ("fodcheck-fetchhg", "fetchhg"),
    ("fodcheck-fetchsvn", "fetchsvn"),
    ("fodcheck-npmdeps", "npmDeps"),
    ("fodcheck-pnpm-deps", "pnpmDeps"),
    ("fodcheck-0.0.0-go-modules", "goModules"),
    (
        "fodcheck-proxy-0.0.0-go-modules",
        "goModules",
    ),  # proxyVendor variant: folded into the goModules family below
    ("caddy-src-with-plugins-", "caddyDeps"),
    ("fodcheck-0.0.0-vendor-staging", "cargoDeps"),
    ("fodcheck-yarn", "yarnDeps"),
    ("cantarell-fonts-", "nat:cantarell-fonts"),
    ("hex0-", "nat:hex0"),
    ("stage0-posix-", "nat:stage0-posix"),
    ("empty-directory", "nat:empty-directory"),
    ("dart-source-deps", "nat:dart-source-deps"),
    ("all", "nat:all"),
)


# Strict pattern for the 7 containers that self-pin nixpkgs via a literal
# fetchTarball in default.nix. Minimal and fail-closed: if a default.nix
# contains a fetchTarball (a self-pin-looking call) that does not match, the
# container is red ("cannot determine the nixpkgs source"), never silently
# re-contexted.
_SELF_PIN = re.compile(
    r"fetchTarball\s*\{\s*url\s*=\s*\"(https://github\.com/NixOS/nixpkgs/archive/[a-f0-9]{40}\.tar\.gz)\"\s*;\s*sha256\s*=\s*\"([a-z0-9]{52})\"\s*;",
    re.DOTALL,
)


class EvalError(Exception):
    """An evaluation/instantiation/walk failure (fail closed -> red)."""


# --------------------------------------------------------------------------
# Store resolution
# --------------------------------------------------------------------------
def _default_store_usable() -> bool:
    """True when the default store is writable (CI runners). A landlock'd
    talos pod keeps /nix read-only even under correct POSIX ownership; probe
    by writing a unique file."""
    for probe_dir in ("/nix/store", "/nix/var/nix/db"):
        probe = os.path.join(probe_dir, f".fod-eval-check-probe-{os.getpid()}")
        try:
            fd = os.open(probe, os.O_WRONLY | os.O_CREAT, 0o600)
            os.close(fd)
            os.unlink(probe)
        except OSError:
            return False
    return True


def resolve_store(explicit: str | None = None) -> str | None:
    """The effective nix store for every eval: the explicit `--store` (CLI or
    FOD_EVAL_CHECK_STORE) beats the default store, which is used when
    writable; otherwise a local store under `$XDG_CACHE_HOME` is created
    (documented in the README; gitignored by the repo). CI: no overrides ->
    the default store is writable -> unchanged behaviour."""
    if explicit:
        return explicit
    override = os.environ.get("FOD_EVAL_CHECK_STORE")
    if override:
        return override
    if _default_store_usable():
        return None
    cache = pathlib.Path(
        os.environ.get("XDG_CACHE_HOME") or (pathlib.Path.home() / ".cache")
    )
    store = cache / "fod-eval-check-store"
    store.mkdir(parents=True, exist_ok=True)
    return str(store)


def _run(
    binary: str,
    args: list[str],
    *,
    store: str | None,
    env: dict[str, str],
    cwd: pathlib.Path,
) -> subprocess.CompletedProcess[str]:
    full = [binary] + (["--store", store] if store else []) + args
    return subprocess.run(
        full,
        check=False,
        capture_output=True,
        text=True,
        env=env,
        cwd=cwd,
        timeout=1800,
    )


def _last_line(text: str, rc: int) -> str:
    lines = [l for l in text.strip().splitlines() if l.strip()]
    return lines[-1] if lines else f"exit {rc}"


def instantiate_container(
    default_nix: pathlib.Path, *, store: str | None, env: dict[str, str]
) -> str:
    """Instantiate one containers/*/default.nix to its drv path (IFD off,
    system pinned; eval error -> EvalError)."""
    r = _run(
        "nix-instantiate",
        [
            str(default_nix),
            "--system",
            PINNED_SYSTEM,
            "--option",
            "allow-import-from-derivation",
            "false",
        ],
        store=store,
        env=env,
        cwd=default_nix.parent,
    )
    if r.returncode != 0:
        raise EvalError(f"instantiate failed: {_last_line(r.stderr, r.returncode)}")
    lines = [l for l in r.stdout.splitlines() if l.strip()]
    if len(lines) != 1:
        raise EvalError(
            f"instantiate yielded {len(lines)} output lines, expected exactly one drv"
        )
    return lines[0].strip()


def eval_toplevel_drv(
    flake_ref: str,
    attr: str,
    *,
    store: str | None,
    env: dict[str, str],
    repo: pathlib.Path,
) -> str:
    """Eval a flake output's toplevel drvPath (pure, IFD off)."""
    r = _run(
        "nix",
        [
            "eval",
            "--raw",
            "--extra-experimental-features",
            FEATURES_EVAL,
            "--option",
            "allow-import-from-derivation",
            "false",
            f"{flake_ref}#{attr}",
        ],
        store=store,
        env=env,
        cwd=repo,
    )
    if r.returncode != 0:
        raise EvalError(f"eval failed: {_last_line(r.stderr, r.returncode)}")
    return r.stdout.strip().splitlines()[-1]


def walk_drv(drv: str, *, store: str | None, env: dict[str, str]) -> dict:
    """`nix derivation show -r` over a drv path; walk failure -> EvalError."""
    r = _run(
        "nix",
        [
            "derivation",
            "show",
            "-r",
            "--extra-experimental-features",
            FEATURES_WALK,
            drv,
        ],
        store=store,
        env=env,
        cwd=pathlib.Path.cwd(),
    )
    if r.returncode != 0:
        raise EvalError(f"walk failed: {_last_line(r.stderr, r.returncode)}")
    return json.loads(r.stdout)


def show_drv(drv: str, *, store: str | None, env: dict[str, str]) -> dict:
    r = _run(
        "nix",
        ["derivation", "show", "--extra-experimental-features", FEATURES_WALK, drv],
        store=store,
        env=env,
        cwd=pathlib.Path.cwd(),
    )
    if r.returncode != 0:
        raise RuntimeError(
            f"derivation show {drv}: {_last_line(r.stderr, r.returncode)}"
        )
    doc = json.loads(r.stdout)
    m = doc.get("derivations", doc)
    return next(iter(m.values()))


class Context:
    """One nixpkgs context — the pkgs the entry points (and their templates)
    are evaluated against — with its cached template bundle.

    A context may span several nixpkgs sources: a host flake's toplevel
    closure mixes the packages of every nixpkgs-type input it locks (ringtail
    pulls nixpkgs-services and nixpkgs-snowflake derivations into one graph),
    so the flake contexts carry one pkgs expression per locked nixpkgs
    source *and per system variant* (ringtail's steam multilib closure uses
    the same sources' `pkgsi686Linux`, whose builders/stdenvs are distinct
    store paths) and the classifier accepts a family match against any of
    them. The multilib variants are only evaluated for host-flake contexts
    (``extend_multilib=True``); container closures are single-system.
    """

    def __init__(
        self,
        key: str,
        pkgs_exprs: list[str],
        *,
        store: str | None,
        env: dict[str, str],
        repo: pathlib.Path,
        system: str | None,
        extend_multilib: bool = False,
    ):
        self.key = key
        self.pkgs_exprs = pkgs_exprs
        self.store = store
        self.env = env
        self.repo = repo
        self.system = system
        self.extend_multilib = extend_multilib
        self.anchor_errors: list[str] = []  # set by main() after flake_pkgs_sources
        self._templates: dict[str, dict | list[dict]] | None = None

    def templates(self) -> dict[str, dict | list[dict]]:
        if self._templates is None:
            self._templates = self._evaluate_templates()
        return self._templates

    def _multilib_exprs(self) -> list[str]:
        out = []
        for expr in self.pkgs_exprs:
            out.append(
                f"((let p = {expr}; in if p ? pkgsi686Linux then p.pkgsi686Linux else ({expr})))"
            )
        return out

    def _evaluate_source(self, pkgs_expr: str) -> dict[str, dict | list[dict]]:
        expr = _TEMPLATE_EXPR.replace("{pkgsSource}", pkgs_expr)
        args = [
            "--json",
            "--option",
            "allow-import-from-derivation",
            "false",
            "--expr",
            expr,
        ]
        if self.system:
            args = ["--system", self.system] + args
        # flakes feature needed for `builtins.getFlake` in the flake contexts
        r = _run(
            "nix-instantiate",
            args
            + (
                ["--extra-experimental-features", FEATURES_EVAL]
                if "getFlake" in pkgs_expr
                else []
            ),
            store=self.store,
            env=self.env,
            cwd=self.repo,
        )
        if r.returncode != 0:
            raise RuntimeError(
                f"template bundle for {self.key} failed:\n{_last_line(r.stderr, r.returncode)}"
            )
        paths = [l for l in r.stdout.splitlines() if l.strip()]
        result: dict[str, dict | list[dict]] = {}
        for p in paths:
            drv = show_drv(p, store=self.store, env=self.env)
            try:
                label = _template_label(drv["name"])
            except RuntimeError:
                # a template drv whose name matches no known shape (e.g. the
                # aarch64-darwin dart package's src is a plain fetchurl of the
                # SDK zip, not dart-source-deps) is a shape the walk itself
                # classifies; skip it — the fixed family items stay required.
                continue
            if label == "goModules":  # vendor + proxyVendor variants are one family
                result.setdefault("goModules", [])
                assert isinstance(result["goModules"], list)
                result["goModules"].append(drv)  # type: ignore[union-attr]
            elif label == "fetchpatch":  # fetchpatch + fetchpatch2 variants
                result.setdefault("fetchpatch", [])
                assert isinstance(result["fetchpatch"], list)
                result["fetchpatch"].append(drv)  # type: ignore[union-attr]
            elif label == "fetchzip":  # the stripRoot true/false variants
                result.setdefault("fetchzip", [])
                assert isinstance(result["fetchzip"], list)
                result["fetchzip"].append(drv)  # type: ignore[union-attr]
            else:
                result[label] = drv
        missing = [f for f in _TEMPLATE_FAMILIES if f not in result]
        if missing:
            raise RuntimeError(
                f"template bundle for {self.key} missing families: {missing}"
            )
        return result

    def _evaluate_templates(self) -> dict[str, dict | list[dict]]:
        exprs = self.pkgs_exprs
        if self.extend_multilib:
            exprs = exprs + self._multilib_exprs()
        merged: dict[str, dict | list[dict]] = {}
        for expr in exprs:
            source = self._evaluate_source(expr)
            for label, drv in source.items():
                cur = merged.get(label)
                if cur is None:
                    merged[label] = drv
                elif isinstance(cur, list) and isinstance(drv, list):
                    merged[label] = cur + drv  # type: ignore[operator]
                elif isinstance(cur, list):
                    merged[label] = cur + [drv]  # type: ignore
                else:
                    merged[label] = [cur, drv]  # type: ignore
        # de-duplicate repeated templates (e.g. ringtail's nixpkgs and
        # nixpkgs-services lock the same rev; the i686 variant of a source
        # whose pkgs have no pkgsi686Linux falls back to itself): keep the
        # first occurrence. The key includes the evaluated system, because
        # two genuinely-distinct templates may share (name, builder) — e.g.
        # the stage0-posix-source NAT entry differs between x86_64 and i686
        # only in `env.system`.
        seen: set[tuple[str, str, str]] = set()
        deduped: dict[str, dict | list[dict]] = {}
        for label, drv in merged.items():
            items = drv if isinstance(drv, list) else [drv]
            keep: list[dict] = []
            for d in items:
                key = (d["name"], d["builder"], str((d.get("env") or {}).get("system")))
                if key not in seen:
                    seen.add(key)
                    keep.append(d)
            if isinstance(drv, list):
                deduped[label] = keep
            elif keep:
                deduped[label] = keep[0]  # type: ignore[assignment]
        return deduped


def _template_label(name: str) -> str:
    for prefix, label in _TEMPLATE_NAME_MAP:
        if name == prefix or name.startswith(prefix):
            return label
    raise RuntimeError(f"unrecognised template drv name: {name!r}")


def selfpin_extract(default_nix: pathlib.Path) -> tuple[str, str] | None:
    """Extract a self-pinned nixpkgs fetchTarball from a containers/*
    default.nix. Returns (url, sha256) on a strict match; None when the file
    has no fetchTarball; raises SelfPinFailure when a fetchTarball is present
    but does not match the strict pattern (never silently
    re-context an unparseable self-pin)."""
    text = default_nix.read_text(encoding="utf-8")
    if "fetchTarball" not in text:
        return None
    m = _SELF_PIN.search(text)
    if m is None:
        raise SelfPinFailure(default_nix.name)
    return (m.group(1), m.group(2))


class SelfPinFailure(Exception):
    """A containers/*/default.nix uses fetchTarball but not as the strict
    nixpkgs self-pin -> the container's nixpkgs source cannot be determined
    -> red."""


def catalogues(catalogue_dir: pathlib.Path | None = None) -> dict[str, dict]:
    """The hand-written catalogue — the CLOSED post-#1852 list
    the directory must contain exactly the declared pnames
    (DECLARED_CATALOGUE) and each declared pname must have a file. Any other
    file (a PR adding `catalogue/evil.json`) or missing file fails closed."""
    d = catalogue_dir or REPO_ROOT / "fod-eval-check" / "catalogue"
    files = {f.stem: f for f in d.glob("*.json")}
    extra = sorted(set(files) - DECLARED_CATALOGUE)
    if extra:
        raise RuntimeError(
            f"catalogue is closed: unexpected file(s) {extra} (extend DECLARED_CATALOGUE in the same reviewed diff)"
        )
    missing = sorted(DECLARED_CATALOGUE - set(files))
    if missing:
        raise RuntimeError(f"catalogue is closed: missing declared pname(s) {missing}")
    return {
        key: json.loads(files[key].read_text(encoding="utf-8"))
        for key in sorted(DECLARED_CATALOGUE)
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--repo", default=".", help="repo root (default: cwd)")
    parser.add_argument(
        "--flake-src",
        default=None,
        help="git flake ref for the host flakes (in-pod: git+file:///abs/path)",
    )
    parser.add_argument(
        "--store", default=None, help="nix store to use (explicit; default: auto)"
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="run the fixture meta-tests instead of the full tree",
    )
    parser.add_argument(
        "--catalogue",
        default=None,
        help="catalogue dir (default: fod-eval-check/catalogue next to this file)",
    )
    args = parser.parse_args(argv)

    repo = pathlib.Path(args.repo).resolve()
    env = dict(os.environ)
    env.setdefault("HOME", str(repo))
    env.setdefault("XDG_CACHE_HOME", str(repo / ".cache"))
    store = resolve_store(args.store)
    if store:
        print(f"store: {store}")

    if args.self_test:
        import pytest

        return pytest.main(["-q", str(REPO_ROOT / "fod-eval-check" / "test_check.py")])

    # ---- trust anchor: the containers nixpkgs pin ----
    try:
        containers_lock = json.loads(
            (repo / "containers" / "flake.lock").read_text(encoding="utf-8")
        )
    except OSError as e:
        print(f"ERROR: cannot read containers/flake.lock: {e}", file=sys.stderr)
        return 1
    containers_identity = _lock_node_identity(containers_lock, "nixpkgs")
    violations_total = 0
    if not _canonical_identity(containers_identity):
        print(
            f"ERROR: containers/flake.lock pins an untrusted nixpkgs source: {containers_identity} "
            "(the template source for the 24 <nixpkgs> containers must be github:NixOS/nixpkgs)",
            file=sys.stderr,
        )
        return 1

    # ---- the in-repo nixpkgs pin (containers/flake.lock) -> NIX_PATH ----
    containers_ref = (
        f"{args.flake_src}?dir=containers" if args.flake_src else "./containers"
    )
    try:
        nixpkgs_path = eval_toplevel_drv(
            containers_ref, "nixpkgsPath", store=store, env=env, repo=repo
        )
    except EvalError as e:
        if not args.flake_src:
            print(
                f"ERROR: cannot resolve the containers nixpkgs pin ({containers_ref}): {e}",
                file=sys.stderr,
            )
            return 1
        # in-pod shim (--flake-src given): the worktree is not libgit2-readable,
        # so retry with an explicit `path:` flake ref (same lock, same outPath).
        path_ref = f"path:{repo / 'containers'}#nixpkgsPath"
        try:
            nixpkgs_path = eval_toplevel_drv(
                path_ref, "nixpkgsPath", store=store, env=env, repo=repo
            )
        except EvalError as e2:
            print(
                f"ERROR: cannot resolve the containers nixpkgs pin ({containers_ref}): {e2}",
                file=sys.stderr,
            )
            return 1
    # the eval printed the store-relative path (/nix/store/…) which nix
    # remaps into the configured store; make it host-visible for the isdir
    # sanity check (NIX_PATH keeps the store-relative form).
    if nixpkgs_path.startswith("/nix/store/") and store:
        local_nixpkgs = (
            pathlib.Path(store) / "nix/store" / pathlib.Path(nixpkgs_path).name
        )
    else:
        local_nixpkgs = pathlib.Path(nixpkgs_path)
    if not os.path.isdir(local_nixpkgs):
        print(
            f"ERROR: resolved nixpkgs path is not a directory: {nixpkgs_path}",
            file=sys.stderr,
        )
        return 1
    env["NIX_PATH"] = f"nixpkgs={nixpkgs_path}"

    # ---- catalogue (closed list; a PR adding a file fails closed) ----
    try:
        catalogue = catalogues(pathlib.Path(args.catalogue) if args.catalogue else None)
    except RuntimeError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1

    # ---- contexts ----
    contexts: dict[str, Context] = {}
    contexts["containers"] = Context(
        "containers",
        ["import <nixpkgs> {}"],
        store=store,
        env=env,
        repo=repo,
        system=PINNED_SYSTEM,
    )
    for ident, subdir, config_attr, system in (
        ("ringtail", "nixos/ringtail", "nixosConfigurations.ringtail", PINNED_SYSTEM),
        ("darwin", "darwin/indri", "darwinConfigurations.indri", "aarch64-darwin"),
    ):
        exprs, anchor = flake_pkgs_sources(
            repo,
            args.flake_src,
            subdir,
            config_attr,
            system,
            store=store,
            lock_for_anchor=True,
        )
        contexts[ident] = Context(
            ident,
            exprs,
            store=store,
            env=env,
            repo=repo,
            system=None,
            extend_multilib=(system == PINNED_SYSTEM),
        )
        contexts[ident].anchor_errors = anchor

    # ---- entry points ----
    entries: list[tuple[str, str, Context]] = []
    selfpin_failures: list[str] = []
    for default_nix in sorted((repo / "containers").glob("*/default.nix")):
        ident = default_nix.parent.name
        try:
            pin = selfpin_extract(default_nix)
        except SelfPinFailure:
            selfpin_failures.append(ident)
            continue
        if pin is not None:
            key = f"selfpin:{pin[1][:8]}"
            if key not in contexts:
                contexts[key] = Context(
                    key,
                    [
                        f'import (fetchTarball {{ url = "{pin[0]}"; sha256 = "{pin[1]}"; }}) {{}}'
                    ],
                    store=store,
                    env=env,
                    repo=repo,
                    system=PINNED_SYSTEM,
                )
                contexts[key].anchor_errors = []
            entries.append(("container", ident, contexts[key]))
        else:
            entries.append(("container", ident, contexts["containers"]))
    for ident in selfpin_failures:
        violations_total += 1
        print(
            f"violation: container {ident}: self-pinned nixpkgs fetchTarball does not match the strict "
            "https://github.com/NixOS/nixpkgs/archive/<40hex>.tar.gz pattern — cannot determine the nixpkgs source",
            file=sys.stderr,
        )

    ring_ref = host_flake_ref(repo, args.flake_src, "nixos/ringtail")
    dar_ref = host_flake_ref(repo, args.flake_src, "darwin/indri")
    entries.append(("ringtail", "ringtail", contexts["ringtail"]))
    entries.append(("darwin", "darwin", contexts["darwin"]))

    # ---- run ----
    eval_errors = 0
    for kind, ident, ctx in entries:
        anchor = getattr(ctx, "anchor_errors", None)
        if anchor:
            for msg in anchor:
                violations_total += 1
                print(f"violation: {ident}: {msg}", file=sys.stderr)
            continue
        # self-pinning contexts anchor their source by construction (the
        # strict pattern above); a mismatch already failed red.
        try:
            if kind == "container":
                drv = instantiate_container(
                    repo / "containers" / ident / "default.nix", store=store, env=env
                )
            else:
                attr = {
                    "ringtail": "nixosConfigurations.ringtail.config.system.build.toplevel",
                    "darwin": "darwinConfigurations.indri.config.system.build.toplevel",
                }[ident]
                ref = ring_ref if ident == "ringtail" else dar_ref
                drv = eval_toplevel_drv(ref, attr, store=store, env=env, repo=repo)
            walk_json = walk_drv(drv, store=store, env=env)
            violations = classify_walk(walk_json, ctx.templates(), catalogue)
            m = walk_drvs(walk_json)
            fods = sum(1 for d in m.values() if is_fod(d))
            violations_total += len(violations)
            print(
                f"{ident}: {len(m)} drvs, {fods} FODs, {len(violations)} violation(s)"
            )
            for v in violations:
                print(f"  violation: {ident}: {v.name}: {v.reason}", file=sys.stderr)
        except EvalError as e:
            eval_errors += 1
            print(f"ERROR {ident}: {e}", file=sys.stderr)
        except RuntimeError as e:
            eval_errors += 1
            print(f"ERROR {ident}: {e}", file=sys.stderr)

    print(f"== {violations_total} violation(s), {eval_errors} eval error(s)")
    return 0 if violations_total == 0 and eval_errors == 0 else 1


def flake_pkgs_sources(
    repo: pathlib.Path,
    flake_src: str | None,
    subdir: str,
    config_attr: str,
    system: str,
    store: str | None = None,
    lock_for_anchor: bool = False,
) -> tuple[list[str], list[str]]:
    """The pkgs sources of a host flake context: the flake's own config pkgs
    plus, generically, every input the flake locks (its closure can pull FODs
    from any of them — ringtail overlays in nixpkgs-services and
    nixpkgs-snowflake derivations). Each is wrapped so an input without the
    attr (or one that is refused on the platform) is skipped, never fatal.

    When `lock_for_anchor` is set the flake.lock is read and
    every input that is actually *used* as a template source (its
    legacyPackages has a usable fetchurl) must be locked to the canonical
    NixOS/nixpkgs identity; an unauthenticated used source returns an anchor
    violation (the entry point is red), never a silent fallback. An input
    with empty/absent legacyPackages is not a template source and needs no
    anchor (current behaviour). The flake's own pkgs anchor on the flake's
    nixpkgs input.

    Returns (exprs, anchor-violations) when lock_for_anchor, else the exprs.
    """
    if flake_src:
        template_ref = f"{flake_src}?dir={subdir}"
    else:
        template_ref = f"git+file://{repo}?dir={subdir}"
    exprs = [f'(builtins.getFlake "{template_ref}").{config_attr}.pkgs']
    primary = exprs[0]
    anchor: list[str] = []
    try:
        lock = json.loads((repo / subdir / "flake.lock").read_text(encoding="utf-8"))
    except OSError:
        return (exprs, anchor)
    inputs = sorted(lock.get("nodes", {}).get("root", {}).get("inputs", {}))
    if lock_for_anchor and inputs:
        # the flake's own pkgs derive from its nixpkgs input
        primary_identity = _lock_node_identity(lock, "nixpkgs")
        if not _canonical_identity(primary_identity):
            anchor.append(
                f"flake {subdir}: the primary pkgs source is not locked to github:NixOS/nixpkgs"
                f" (locked as {primary_identity})"
            )
        try:
            used = _used_inputs(
                lock, inputs, template_ref, config_attr, system, repo, store=store
            )
        except RuntimeError as e:
            anchor.append(f"flake {subdir}: cannot evaluate input usage: {e}")
            used = set()
        for name in inputs:
            identity = _lock_node_identity(lock, name)
            if name in used and not _canonical_identity(identity):
                anchor.append(
                    f"flake {subdir}: input `{name}` is used as a template nixpkgs source but is not "
                    f"github:NixOS/nixpkgs (locked as {identity})"
                )
    for name in inputs:
        # inputs without a usable *complete* legacyPackages.<system> fall back to
        # the flake's own pkgs (redundant templates; deduplicated by the
        # context). `fetchurl` presence is the bundle's minimum requirement;
        # `?`/hasAttr guards are needed because builtins.tryEval does not
        # catch "attribute missing" on a flake input attrset.
        exprs.append(
            f'((let f = builtins.getFlake "{template_ref}"; '
            f'lp = (f.inputs."{name}").legacyPackages or null; '
            f'sys = if lp != null && builtins.hasAttr "{system}" lp then lp."{system}" else null; '
            f'good = sys != null && builtins.hasAttr "fetchurl" sys; '
            f"pkgs0 = if good then sys else ({primary}); "
            f"r = builtins.tryEval pkgs0; "
            f"in if r.success then r.value else ({primary})))"
        )
    return (exprs, anchor)


def _used_inputs(
    lock: dict,
    inputs: list[str],
    template_ref: str,
    config_attr: str,
    system: str,
    repo: pathlib.Path,
    store: str | None,
) -> set[str]:
    """Which locked inputs have a usable legacyPackages.<system> (the same
    `good` predicate the source wrappers use): only those are template
    sources and need an identity anchor."""
    names = " ".join(f'"{n}"' for n in inputs)
    expr = (
        'let f = builtins.getFlake "' + template_ref + '"; '
        f"names = [ {names} ]; "
        f'good = n: let lp = ((f.inputs.${{n}}.legacyPackages or {{}})."{system}" or null); '
        f'in lp != null && builtins.hasAttr "fetchurl" lp; '
        "in builtins.listToAttrs (builtins.map (n: { name = n; value = good n; }) names)"
    )
    env = dict(os.environ)
    env.setdefault("HOME", str(repo))
    env.setdefault("XDG_CACHE_HOME", str(repo / ".cache"))
    # Two hardening properties (round-4 review):
    # - allow-import-from-derivation is OFF, like every other eval in this
    #   check: the probe must not be able to trigger IFD builds from the PR's
    #   own flake code mid-probe (a failure routes to the anchor-red path).
    # - --impure is REQUIRED here and cannot be dropped: builtins.getFlake
    #   refuses ANY unlocked flake ref (git+file://, path:, bare path) in pure
    #   eval mode ("cannot call 'getFlake' on unlocked flake reference … use
    #   --impure to override"), and the probe must read the worktree's
    #   UNCOMMITTED state, so no rev-locked ref is possible. Both host flakes
    #   themselves evaluate purely (the entry-point evals run pure, IFD off);
    #   the probe only READS the locked inputs' legacyPackages attribute
    #   PRESENCE. Kept --impure here only, with this comment, per review.
    r = _run(
        "nix",
        [
            "eval",
            "--impure",
            "--json",
            "--extra-experimental-features",
            FEATURES_EVAL,
            "--option",
            "allow-import-from-derivation",
            "false",
            "--expr",
            expr,
        ],
        store=store,
        env=env,
        cwd=repo,
    )
    if r.returncode != 0:
        raise RuntimeError(_last_line(r.stderr, r.returncode))
    used = {k for k, v in json.loads(r.stdout).items() if v is True}
    return used


def host_flake_ref(repo: pathlib.Path, flake_src: str | None, subdir: str) -> str:
    """Host flake ref for an entry point: the explicit `--flake-src` git ref
    in-pod, the plain relative path ref from the checkout in CI."""
    if flake_src:
        return f"{flake_src}?dir={subdir}"
    return f"./{subdir}"


if __name__ == "__main__":
    sys.exit(main())
