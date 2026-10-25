"""Eval-based FOD classification core — pure over JSON, no Nix calls.

Implements the fod-only-downloads invariant check (docs/explanation/
talos-v0.5/fod-eval-check.md): *nothing downloaded executes inside a FOD*.

Given a ``nix derivation show -r`` walk document, the per-context family
templates (evaluated from the *same* nixpkgs source as the entry point) and
the hand-written catalogue fixtures, returns the list of unrecognised
fixed-output/impure derivations and setup-hook violations with reasons.

Every rule here is fail-closed: a derivation that matches no known shape,
or a template-driven comparison that fails, is a violation. There is no
exception list — a new builder means extending the known shapes first.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path

# The compared surface of a derivation: the
# whole derivation (env + structuredAttrs + top-level builder/args/name/system,
# the inputs.srcs builder scripts, and the outputs' method/flatness) is compared
# against the matched template, EXCEPT the family-declared instance-variable
# keys below. Everything not declared is strict-equal.
#
# Always compared, never instance vars:
#   - args, inputs.srcs — strict equality per template. The per-context
#     template bundle is evaluated from every nixpkgs source (and system
#     variant, e.g. pkgsi686Linux for the steam multilib closure) the entry
#     point uses, so every genuine instance's executing fetcher script IS its
#     own source's template script.
#   - buildCommand, the phase attrs, the hook-inheriting attrs, system,
#     outputs.<n>.method / impure-ness.
#   - builder: must equal the matched template's builder exactly. A builder
#     that is a store path produced by a downloaded derivation, or that no
#     derivation in the walk produces, is never accepted by the template
#     comparison (_builder_problem names it on unrecognised shapes).
#   - preFetch/postFetch/stdenv/mirrorsFile/nativeBuildInputs: strictly
#     compared, except postFetch on the fetchzip/fetchgithub/fetchpatch/
#     fetchgit families, which must be empty or exactly one of the texts in
#     allowed-postfetch.json (see _whole_drv_mismatch).

# Phase attrs compared structurally against the template. "Where present": an
# attr present in the derivation must equal the template's value for the same
# attr. The pre*/post* run-hooks are *instance arguments* (buildGoModule
# forwards a package's own preBuild into the goModules FOD, buildNpmPackage
# forwards prePatch/postPatch into the deps FOD) and are graded by the static
# pre-check, not compared.
PHASE_ATTRS = (
    "unpackPhase",
    "patchPhase",
    "configurePhase",
    "buildPhase",
    "checkPhase",
    "installPhase",
    "fixupPhase",
    "postFixupPhase",
)

# The hook-inheriting attrs: empty (or absent) on a checked derivation.
HOOK_INHERITING_ATTRS = ("propagatedNativeBuildInputs", "propagatedBuildInputs")

# Stdenv-family drvs whose input hooks define part of the allowed hook
# universe, on the walk side of the template-side seeds (see hook_universe).
# In this nixpkgs rev the stdenv drvs are named `stdenv-linux`,
# `stdenv-linux-no-cc`, `stdenv-darwin` … (the cross variants and the
# bootstrap stages similarly).
STDENV_NAME = re.compile(r"^(stdenv|bootstrap)")

# The marker a hook-providing derivation carries: its build command installs
# $out/nix-support/setup-hook (the nixpkgs setup.sh contract, cf.
# makeSetupHook in pkgs/build-support/trivial-builders).
HOOK_MARKER = "$out/nix-support/setup-hook"


# --------------------------------------------------------------------------
# Per-family instance-variable keys
# --------------------------------------------------------------------------
# One entry per family label: the key names (in env or structuredAttrs) whose
# VALUE legitimately varies per instance (and/or whose presence may vary).
# Everything else — every key not listed — must be byte-equal to the matched
# template (after the text normalisations below). The sets were derived from
# the real closures (ringtail, darwin/indri, every container) and each family
# is documented in the README with the reason per key. Keys bearing * only
# vary in *presence* (the value, where present, is constant) — the key may be
# absent from the template.

UNIVERSAL_IVARS = frozenset({"SSL_CERT_FILE"})
# fetchurl's SSL_CERT_FILE is hash-derived (pkgs/build-support/fetchurl): a
# fake-hash template keeps TLS verification (${cacert}/ca-bundle.crt), a real
# instance disables it (/no-cert-file.crt, the FOD hash protects integrity).
# It is genuinely per-instance; everything else in the env stays strict.

# The hook-inheriting attrs (propagated*) stay strictly compared and the hook
# universe rule still inspects the FOD's input hooks.
ALLOWED_POSTFETCH_FILE = Path(__file__).with_name("allowed-postfetch.json")
_POSTFETCH_FAMILIES = frozenset({"fetchzip", "fetchgithub", "fetchpatch", "fetchgit"})


def _load_allowed_postfetch(path: Path) -> frozenset[str]:
    """The exact postFetch texts the postFetch families may carry. Fail closed:
    a missing, malformed or unreasoned entry raises at import."""
    doc = json.loads(path.read_text())
    if not isinstance(doc, dict) or set(doc) != {"texts"}:
        raise ValueError(f"{path}: expected a JSON object with only a `texts` key")
    entries = doc["texts"]
    if not isinstance(entries, list):
        raise ValueError(f"{path}: `texts` must be a list")
    texts: set[str] = set()
    for i, entry in enumerate(entries):
        if not isinstance(entry, dict) or set(entry) != {"text", "reason"}:
            raise ValueError(f"{path}: texts[{i}] needs exactly `text` and `reason`")
        text, reason = entry["text"], entry["reason"]
        if not isinstance(text, str) or not text.strip():
            raise ValueError(f"{path}: texts[{i}].text must be a non-empty string")
        if not isinstance(reason, str) or not reason.strip():
            raise ValueError(f"{path}: texts[{i}].reason must be a non-empty string")
        texts.add(text)
    return frozenset(texts)


_ALLOWED_POSTFETCH = _load_allowed_postfetch(ALLOWED_POSTFETCH_FILE)


def _postfetch_problem(value: object) -> str | None:
    """postFetch on a _POSTFETCH_FAMILIES instance: empty, or exactly an
    allow-listed text. Anything else is an unlisted executing surface."""
    if value is None or value == "":
        return None
    if isinstance(value, str) and value in _ALLOWED_POSTFETCH:
        return None
    return (
        "unlisted postFetch text (not in fod-eval-check/allowed-postfetch.json): "
        + json.dumps(value)
    )

# The package-FOD families whose builder also receives the fetched package
# SOURCE as an input script (the prefetch binaries read it): the only extra
# `inputs.srcs` entries tolerated are the declared per-instance env keys'
# store basenames. Every other script in the list is compared against the
# template bit-for-bit. Verified against the tree: buildNpmPackage's deps
# FOD carries its src; the plain fetchNpmDeps/fetchPnpmDeps do not.
_EXTRA_SRCS: dict[str, tuple[str, ...]] = {
    "npmDeps": ("src",),
    "pnpmDeps": ("src",),
    "goModules": ("src",),
    "cargoDeps": ("src",),
    "yarnDeps": ("yarnLock", "src"),
}


def pathlib_basename(path: str) -> str:
    return path.rsplit("/", 1)[-1]


# The extra `inputs.srcs` entries the package-FOD families may carry: the
# per-instance SOURCE/lockfile the prefetchers read, and the package-issued
# PATCH/DIFF files applied by the (strictly-compared) patchPhase. All are
# store-path-shaped data inputs (`<32hex>-<name>.patch|.diff`, `-Cargo.lock`,
# `-package-lock.json` …) — read and parsed by the fetcher, never executed as
# scripts (the executed code is the strictly-compared `args` scripts).
_DATA_SRC_SUFFIXES = (
    ".patch",
    ".diff",
    "-Cargo.lock",
    "-package-lock.json",
    "-yarn.lock",
)
# the cross stdenv's Meson cross-file threads into the fetchgit FOD's srcs as
# a `<hash>-cross-file.conf` data input (the wasi-libc instance, above); inert
# under the fetchgit builder (only builder.sh / nix-prefetch-git execute).
_FETCHGIT_SRC_SUFFIXES = _DATA_SRC_SUFFIXES + ("-cross-file.conf",)


def _store_root_basename(path: str) -> str:
    """The store-path basename of a path that may include a subpath, e.g.
    `/nix/store/<hash>-src/foo` -> `<hash>-src`."""
    parts = path.split("/")
    if len(parts) >= 4 and parts[:3] == ["", "nix", "store"]:
        return parts[3]
    return path.rsplit("/", 1)[-1]


def _allowed_extra_srcs(drv: dict, family: str) -> set[str]:
    """The tolerated extra `inputs.srcs` entries for this instance: the
    basenames of the family's declared per-instance source env keys (src,
    yarnLock, the patches list items) plus any store-path-shaped data input
    (a `<32hex>-<name>` basename ending in the data suffixes below)."""
    env = drv.get("env") or {}
    out: set[str] = set()
    for key in _EXTRA_SRCS.get(family or "", ()):
        value = env.get(key)
        if isinstance(value, str):
            items = (
                [value]
                if value.startswith("/nix/store/")
                else [i for i in value.split() if i.startswith("/nix/store/")]
            )
            out.update(_store_root_basename(i) for i in items)
        elif isinstance(value, list):
            out.update(
                _store_root_basename(i)
                for i in value
                if isinstance(i, str) and i.startswith("/nix/store/")
            )
    return out


def _is_data_src(basename: str, family: str | None = None) -> bool:
    # the cross stdenv's Meson cross-file threads into the fetchgit FOD's srcs
    # as a data input (the wasi-libc instance, above); inert under the fetchgit
    # builder (only builder.sh / nix-prefetch-git execute).
    suffixes = _FETCHGIT_SRC_SUFFIXES if family == "fetchgit" else _DATA_SRC_SUFFIXES
    stem = basename.split("-", 1)[0]
    return len(stem) == 32 and stem.isalnum() and basename.endswith(suffixes)


# Common fetcher instance vars: name/urls/rev are the fetcher parameters the
# call site supplies; hash/outputHash/outputHashAlgo/outputChecks and env:out
# are the fixed-output hash and the output path.
_FETCHER_COMMON = frozenset(
    {
        "name",
        "urls",
        "url",
        "rev",
        "hash",
        "outputHash",
        "outputHashAlgo",
        "outputChecks",
        "out",
    }
)

# The nixpkgs `fetchFromGitHub` fetcher-parameter keys (only the zip variant's
# are ivars here; the fetchgit variant is covered by the fetchgit family).
_FGH_PARAMS = frozenset(
    {"owner", "repo", "tag", "revCustom", "githubBase", "extension"}
)

# fetchzip parameters: the download-name extension hint and stripRoot.
_FETCHZIP_PARAMS = frozenset({"extension", "stripRoot"})

# fetchgit parameters (verify-2026-10 against ringtail/darwin/mealie/
# paperless/prowler/closures: every real member of the family sets exactly
# these): deepClone, leaveDotGit, sparseCheckout(+Text via
# sparseCheckoutToText), postCheckout (forwarded as the nix-prefetch-git
# NIX_PREFETCH_GIT_CHECKOUT_HOOK), fetchSubmodules, plus the fetchFromGitHub-
# over-fetchgit derivation-args keys (owner/repo/githubBase/tag/revCustom).
# Plus the cross-build artefacts of the ONE real-tree instance with evidence:
# nixpkgs cross-builds wasi-libc with `fetchFromGitHub { fetchSubmodules =
# true; }` under a cross stdenv whose static-build derivation args land in
# the FOD's env (cmakeFlags, configureFlags, mesonFlags, NIX_CFLAGS_LINK,
# dontDisableStatic, and the strictDeps flag of the cross stdenv) and whose
# Meson cross-file threads into the FOD's inputs.srcs as a
# `<hash>-cross-file.conf` data input (tolerated in the srcs check below).
# All are inert — the fetchgit builder script never reads the generic
# mkDerivation attrs and never executes the cross-file — and the executing
# surface (builder shell script + args) stays strict.
_FETCHGIT_PARAMS = frozenset(
    {
        "fetchSubmodules",
        "deepClone",
        "leaveDotGit",
        "sparseCheckout",
        "sparseCheckoutText",
        "owner",
        "repo",
        "githubBase",
        "tag",
        "revCustom",
        "cmakeFlags",
        "configureFlags",
        "mesonFlags",
        "NIX_CFLAGS_LINK",
        "dontDisableStatic",
        "strictDeps",
    }
)

# fetchurl-family: the call-site parameters plus the gitlab-archive-style URL
# basename (which the fetchzip text splices into its download rename).
_FETCHURL_IVARS = _FETCHER_COMMON | frozenset({"patches"})
# fetchzip: + the fetcher parameters; downloadToTemp is a real per-instance
# parameter (the darwin macOS-SDK helper sets it false while this rev's
# darwin fetchzip default is true — 2 differing darwin instances, verified).
_FETCHZIP_IVARS = (
    _FETCHER_COMMON
    | _FETCHZIP_PARAMS
    | frozenset({"pname", "version"})
    | frozenset({"downloadToTemp"})
)
_FETCHPATCH_IVARS = _FETCHER_COMMON
# fetchFromGitHub may be given a pname/version (dart-style) by packages
_FETCHGITHUB_IVARS = (
    _FETCHER_COMMON
    | _FETCHZIP_PARAMS
    | _FGH_PARAMS
    | frozenset({"pname", "version"})
    | frozenset({"downloadToTemp"})
)
_FETCHGIT_IVARS = _FETCHER_COMMON | _FETCHGIT_PARAMS
_FETCHHG_IVARS = _FETCHER_COMMON | frozenset({"name", "subrepoClause"})
_FETCHSVN_IVARS = _FETCHER_COMMON | frozenset({"name"})

# npmDeps (fetchNpmDeps): the FOD is a generic-builder derivation whose env
# carries the package's forwarded args. Instance vars — fetcher params
# (fetcherVersion / NPM_FETCHER_VERSION, forceGitDeps, forceEmptyCache), the
# package args (src, dontInstall, NIX_NPM_REGISTRY_OVERRIDES, sourceRoot, the
# forwarded pre*/post* run-hooks and patches) and the output hash/path.
_FETCHNPMDEPS_IVARS = frozenset(
    {
        "name",
        "src",
        "hash",
        "outputHash",
        "outputChecks",
        "out",
        "fetcherVersion",
        "NPM_FETCHER_VERSION",
        "forceGitDeps",
        "forceEmptyCache",
        "dontInstall",
        "NIX_NPM_REGISTRY_OVERRIDES",
        "sourceRoot",
        "patches",
        "patchFlags",
        "prePatch",
        "postPatch",
        "preBuild",
        "postBuild",
    }
)

# pnpmDeps (fetchPnpmDeps): fetcher params (fetcherVersion, the pnpm input,
# the resolved pnpm version, the pnpmWorkspaces --filter list), src lockfile,
# output hash/path. nativeBuildInputs carries the (per-instance) pnpm/node
# tools the deps FOD uses.
_FETCHPNPMDEPS_IVARS = frozenset(
    {
        "name",
        "src",
        "hash",
        "outputHash",
        "outputChecks",
        "out",
        "fetcherVersion",
        "pnpm",
        "version",
        "nativeBuildInputs",
        "pnpmWorkspaces",
        "sourceRoot",
    }
)

# goModules (buildGoModule's deps FOD): fetcher params (modRoot, the GO tool
# env vars that vary per package — GOFLAGS/CGO_ENABLED/GOOS/GOARCH/
# GO111MODULE — verified against the closure), the output hash, plus EVERY
# package-forwarded mkDerivation arg the real closures carry
# (buildGoModule threads the whole arg set through). GOTOOLCHAIN is NOT an
# instance var (round-4 review): every genuine goModules FOD in the tree and
# every goModules template carries GOTOOLCHAIN=local — an override
# (auto/goX.Y) makes go download and execute an un-hashed toolchain inside
# the FOD build, a true invariant violation, so it reds by construction
# (strict compare to the template's GOTOOLCHAIN=local). The generated text
# the generic builder actually executes — the phase attrs modulo the
# outputHash splice — stays strict.
_GOMODULES_IVARS = frozenset(
    {
        "name",
        "pname",
        "version",
        "src",
        "hash",
        "outputHash",
        "out",
        "modRoot",
        "sourceRoot",
        "setSourceRoot",
        "GOFLAGS",
        "CGO_ENABLED",
        "GOOS",
        "GOARCH",
        "GO111MODULE",
        "CGO_CFLAGS",
        "BASH_PATH",
        "NIX_MAIN_PROGRAM",
        "nativeBuildInputs",
        "buildInputs",
        "patches",
        "patchFlags",
        "preBuild",
        "prePatch",
        "postBuild",
        "postPatch",
        "preCheck",
        "postInstall",
        "preFixup",
        "postFixup",
        "deleteVendor",
        "proxyVendor",
        "allowGoReference",
        "subPackages",
        "excludedPackages",
        "tags",
        "ldflags",
        "checkFlags",
        "checkPhase",
        "installCheckPhase",
        "enableParallelBuilding",
        "enableParallelChecking",
        "enableParallelInstalling",
        "disallowedReferences",
        "dontFixup",
        "makeFlags",
        "impureEnvVars",
        "vendorHash",
        "goModules",
        "outputs",
        "__structuredAttrs",
        # one-off package passthrough args observed in the closure
        "WHAT",
        "convert",
        "derper",
        "ui",
        "tools",
        "man",
        "k3sKillallDeps",
        "k3sRuntimeDeps",
        "versionCheckProgram",
    }
)

# caddyDeps (caddy.withPlugins' src FOD): pname/name + output hash/path; the
# buildPhase embeds the --with plugin list (masked below).
_CADDY_IVARS = frozenset({"name", "pname", "outputHash", "hash", "out", "version"})

# cargoDeps (buildRustPackage vendor-staging FOD): package args cargoRoot,
# sourceRoot, patches, forwarded run-hooks, src, output hash/path.
_CARGODEPS_IVARS = frozenset(
    {
        "name",
        "src",
        "outputHash",
        "hash",
        "out",
        "cargoRoot",
        "sourceRoot",
        "patches",
        "postPatch",
        "preBuild",
        "postBuild",
    }
)

# yarnDeps (fetchYarnDeps): the lockfile, name ("offline"), output hash/path.
_YARN_IVARS = frozenset(
    {"name", "yarnLock", "outputHash", "outputHashAlgo", "outputChecks", "hash", "out"}
)

# nixpkgs-native package FODs ((re-)evaluated from the same nixpkgs): matched
# by exact name + whole-drv equality. The derivation is byte-identical to the
# re-evaluation from the same source+system (verified against the closure), so
# no instance vars are needed — a mismatch is red.
_NAT_IVARS = frozenset()

INSTANCE_VARS: dict[str, frozenset[str]] = {
    "fetchurl": _FETCHURL_IVARS,
    "fetchzip": _FETCHZIP_IVARS,
    "fetchpatch": _FETCHPATCH_IVARS,
    "fetchgithub": _FETCHGITHUB_IVARS,
    "fetchgit": _FETCHGIT_IVARS,
    "fetchhg": _FETCHHG_IVARS,
    "fetchsvn": _FETCHSVN_IVARS,
    "npmDeps": _FETCHNPMDEPS_IVARS,
    "pnpmDeps": _FETCHPNPMDEPS_IVARS,
    "goModules": _GOMODULES_IVARS,
    "caddyDeps": _CADDY_IVARS,
    "cargoDeps": _CARGODEPS_IVARS,
    "yarnDeps": _YARN_IVARS,
    # NAT labels share the NAT var set
    # nixpkgs-native package FODs and the catalogue fixtures are matched with
    # the `nat` ivar set (empty: byte-identical to the re-evaluation)
    "nat": _NAT_IVARS,
}

# --------------------------------------------------------------------------
# Text normalisations (fetcher-parameter splices into generated text)
# --------------------------------------------------------------------------
# The families whose phase text (and postFetch text) embed the instance's own
# fetcher parameters. Mirrors the nixpkgs generator byte-for-byte for the
# fragments; everything else is strict text equality.

# The fetchurl family's other fetched text (buildCommand) is never an instance
# var: fetchurl's own builder script is an input (never an env buildCommand);
# the generic stdenv builder (npmDeps etc.) runs the phases. A buildCommand on
# any FOD is an extra key the template lacks -> red (tampered-buildcommand).
# generic stdenv builder (npmDeps etc.) runs the phases. A buildCommand on
# any FOD is an extra key the template lacks -> red (the
# tampered-buildcommand fixture).


def _normalise(text: str, fragments: list[tuple[str, str]]) -> str:
    for pattern, repl in fragments:
        text = re.sub(pattern, repl, text)
    return text


# Fetcher-parameter fragments nixpkgs splices into a family's phase text.
_PHASE_NORMALIZATIONS: dict[str, list[tuple[str, str]]] = {
    "npmDeps": [
        (
            r'outputHash="sha256-[A-Za-z0-9+/=]{44}" prefetch-npm-deps',
            r'outputHash="<hash>" prefetch-npm-deps',
        ),
    ],
    "pnpmDeps": [
        (r"'--filter=[^']*'", "'--filter=…'"),
        (r"(?:'--filter=…' )*\\", r"\\"),
        (r"(?m)^[ \t]+\\$", r"\\"),
        (r"pnpm version [0-9]+", "pnpm version <v>"),
        (r"(lockfileVersion:0:1} -gt )[0-9]+", r"\1<v>"),
        (r"( -gt )[0-9]+", r"\1<v>"),
        (r"( -ge )[0-9]+", r"\1<v>"),
        (r"(\[\[ )[0-9]+( -ge )", r"\1<v>\2"),
        (r"(echo )[0-9]+( > \$out/.fetcher-version)", r"\1<v>\2"),
    ],
    "caddyDeps": [
        (r"--with [^ ]+ ", ""),
    ],
    "goModules": [
        (r'outputHash="sha256-[A-Za-z0-9+/=]{44}"', r'outputHash="<hash>"'),
    ],
}


def _normalised_phase(drv_or_tpl: dict, family: str | None) -> dict[str, str]:
    attrs = phase_attrs(drv_or_tpl)
    if family is None or family not in _PHASE_NORMALIZATIONS:
        return attrs
    out = dict(attrs)
    for pattern, repl in _PHASE_NORMALIZATIONS[family]:
        for k, v in out.items():
            out[k] = re.sub(pattern, repl, v)
    return out


# nixpkgs-native FODs / catalogue fixtures are matched by name first.
NAT_ATTRIBUTES = (
    (lambda n: n.startswith("cantarell-fonts-"), "nat:cantarell-fonts"),
    (lambda n: n.startswith("hex0-"), "nat:hex0"),
    (lambda n: n.startswith("stage0-posix-"), "nat:stage0-posix"),
    (lambda n: n == "empty-directory", "nat:empty-directory"),
    (lambda n: n == "dart-source-deps", "nat:dart-source-deps"),
    (lambda n: n == "all", "nat:all"),
)


@dataclass(frozen=True)
class Violation:
    """One fail-closed finding for a derivation in a walk."""

    drv: str  # store basename of the .drv, e.g. "abcd1234-name.drv"
    name: str
    reason: str


def walk_drvs(walk: dict) -> dict[str, dict]:
    """The basename -> derivation map of a `nix derivation show -r` document."""
    m = walk.get("derivations", walk)
    assert isinstance(m, dict), "walk document is not a derivation map"
    return m


# --------------------------------------------------------------------------
# The builder rule
# --------------------------------------------------------------------------
def _store_root(path: str) -> str:
    """The store-root basename of a (possibly sub-pathed) store path: a walk
    serialises output paths store-relative (`<hash>-<name>`) while the
    top-level `builder` is absolute (`/nix/store/<hash>-<name>/bin/bash`);
    both normalise to the same root. A non-store path (e.g. `/bin/sh`) is
    returned unchanged (it can then never match an output root)."""
    parts = path.split("/")
    if len(parts) >= 4 and parts[:3] == ["", "nix", "store"]:
        return parts[3]
    return parts[-1] if parts else ""


def builder_producers(walk: dict) -> dict[str, str]:
    """Output store-root -> producing drv basename, over the walk's derivations.
    A builder store path (the output of exactly one drv in the closure) maps
    to that drv (the FOD's own `inputs.drvs` contains it)."""
    m = walk_drvs(walk)
    out: dict[str, str] = {}
    for key, drv in m.items():
        for o in (drv.get("outputs") or {}).values():
            p = o.get("path")
            if p:
                out[_store_root(str(p))] = key
    return out


def _builder_problem(
    builder: str, drv: dict, producers: dict[str, str], walk: dict
) -> str | None:
    """The producing-derivation rule for a store-path builder that is not the template's.
    None == the builder is acceptable because its producing derivation exists
    in the walk and is a non-FOD (its outputs are path outputs). A builder
    that is the OUTPUT of a FOD — a downloaded binary used as another FOD's
    interpreter: downloaded code executing inside a FOD — and a builder no
    derivation in the walk produces (undeterminable, fail closed) are red.
    `builtin:fetchurl` never reaches here (classify_fod returns early).

    Resolution: (1) the walk serialises an output `path` only when the output
    is realised — non-FOD outputs always are, and a realised FOD output is;
    (2) an unrealised FOD output has NO path in the walk, so the producing
    FOD is found among the checked FOD's OWN `inputs.drvs` (the parent
    resolution: "a builder path is the output of exactly one derivation in
    the closure — the FOD's own inputs.drvs will contain it"): an input FOD
    with a single output whose store basename matches the builder's. Step 2
    can only conclude FOD-produced or undeterminable — never "non-FOD OK" —
    so it cannot silently approve a hole; an ambiguity (several same-named
    FOD inputs) is fail-closed red."""
    m = walk_drvs(walk)
    root = _store_root(builder)
    key = producers.get(root)
    if key is not None:
        prod = m.get(key) or {}
        if is_fod(prod):
            return _downloaded_builder(builder, prod, key)
        return None
    # step 2: the producing drv is a FOD whose (realised) path the walk does
    # not carry; find it among the checked FOD's own inputs by store basename.
    dash = root.find("-")
    if dash > 0 and walk is not None:
        want = root[dash + 1 :]
        cands = [
            i
            for i in (drv.get("inputs", {}).get("drvs") or [])
            if _input_drv_is_single_fod_named(m.get(i), want)
        ]
        if len(cands) == 1:
            prod = m.get(cands[0]) or {}
            return _downloaded_builder(builder, prod, cands[0])
    return (
        f"builder `{builder}` is not produced by any derivation in the walk "
        "(a store path with no producing derivation) - undeterminable, fail closed"
    )


def _input_drv_is_single_fod_named(prod: dict | None, store_name: str) -> bool:
    """True when `prod` is a fixed-output/impure derivation whose single
    output's store basename (the drv name for a single-output drv) matches
    `store_name` — the shape of a producing drv for a path-less FOD output."""
    if prod is None or not is_fod(prod):
        return False
    outs = prod.get("outputs") or {}
    if len(outs) != 1 or "out" not in outs:
        return False
    return (prod.get("name") or "") == store_name


def _downloaded_builder(builder: str, prod: dict, key: str) -> str:
    return (
        f"builder is a downloaded derivation: `{builder}` is the output of the "
        f"fixed-output/impure derivation `{prod.get('name') or key}` "
        "(downloaded code executing inside a FOD)"
    )


def is_fod(drv: dict) -> bool:
    """True for a fixed-output derivation (an output carries a hash) or an
    impure derivation (an output is unhashed and `impure: true`)."""
    for out in (drv.get("outputs") or {}).values():
        if out.get("hash") is not None or out.get("impure") is True:
            return True
    return False


def build_command(drv: dict) -> str:
    sa = drv.get("structuredAttrs") or {}
    if isinstance(sa.get("buildCommand"), str) and sa["buildCommand"]:
        return sa["buildCommand"]
    env = drv.get("env") or {}
    return env.get("buildCommand") or ""


def is_hook_provider(drv: dict) -> bool:
    """A derivation provides a setup hook iff its build command installs
    $out/nix-support/setup-hook (see HOOK_MARKER)."""
    return HOOK_MARKER in build_command(drv)


def is_stdenv_family(name: str) -> bool:
    return STDENV_NAME.match(name) is not None


def phase_attrs(drv: dict) -> dict[str, str]:
    """The phase attrs present on a derivation (from structuredAttrs or env)."""
    sa = drv.get("structuredAttrs") or {}
    env = drv.get("env") or {}
    out: dict[str, str] = {}
    for p in PHASE_ATTRS:
        if p in sa and isinstance(sa[p], str):
            out[p] = sa[p]
        elif p in env and isinstance(env[p], str):
            out[p] = env[p]
    return out


def hook_inheriting_attrs(drv: dict) -> dict[str, str]:
    sa = drv.get("structuredAttrs") or {}
    env = drv.get("env") or {}
    return {
        k: (str(sa.get(k)) if k in sa else str(env.get(k) or ""))
        for k in HOOK_INHERITING_ATTRS
    }


def _empty(value: object) -> bool:
    if value is None:
        return True
    if isinstance(value, str):
        return value.strip() == ""
    if isinstance(value, list):
        return len(value) == 0
    return False


def _tpl_label(template: dict) -> str:
    return template.get("name") or "?"


def _env_map(drv: dict) -> dict[str, object]:
    """The flat comparison map: every serialised key of the derivation."""
    out: dict[str, object] = {}
    env = drv.get("env") or {}
    sa = drv.get("structuredAttrs") or {}
    for k, v in env.items():
        out["env:" + k] = v
    for k, v in sa.items():
        out["sa:" + k] = v
    return out


def _normalised_text_value(key: str, value: str, family: str | None) -> str:
    if family is None:
        return value
    if key in PHASE_ATTRS and family in _PHASE_NORMALIZATIONS:
        return _normalise(value, _PHASE_NORMALIZATIONS[family])
    return value


def _whole_drv_mismatch(
    drv: dict,
    template: dict,
    *,
    family: str | None,
    template_label: str,
    producers: dict[str, str] | None = None,
    walk: dict | None = None,
) -> list[str]:
    """Strict whole-derivation comparison: every env and
    structuredAttrs key not declared an instance var must equal the
    template's, builder/args/inputs.srcs/system must be byte-equal, and the
    outputs' methods must match. Returns the mismatch list.

    `builder` must equal the template's exactly; any difference is a violation.

    `producers`/`walk` are the per-walk maps (computed once by classify_walk).
    """
    problems: list[str] = []

    if drv.get("builder") != template.get("builder"):
        problems.append(
            f"builder `{drv.get('builder')}` != template `{template.get('builder')}`"
        )
    if drv.get("args") != template.get("args"):
        problems.append(f"args differ from the {template_label} template")
    if drv.get("system") != template.get("system"):
        problems.append(
            f"system `{drv.get('system')}` != template `{template.get('system')}`"
        )
    # (inputs.srcs equality is checked below, with the package-FOD families'
    # declared per-instance source entries tolerated.)

    # outputs: same names; per output the method (flat/nar/recursive) and the
    # impure flag must equal; the hash itself is per-instance.
    do = drv.get("outputs") or {}
    to = template.get("outputs") or {}
    if sorted(do) != sorted(to):
        problems.append(f"outputs {sorted(do)} != template outputs {sorted(to)}")
    else:
        for name in do:
            if (do[name].get("method")) != (to[name].get("method")):
                problems.append(
                    f"output `{name}` method {do[name].get('method')} != template {to[name].get('method')}"
                )
            if bool(do[name].get("impure")) != bool(to[name].get("impure")):
                problems.append(
                    f"output `{name}` impure flag differs from the template"
                )

    ivars = INSTANCE_VARS.get(family or "", frozenset()) | UNIVERSAL_IVARS

    # inputs.srcs: the builder scripts must be byte-equal to the template's;
    # the package-FOD families additionally carry their per-instance SOURCE as
    # an input script entry (the fetcher reads the source to prefetch from it)
    # — the entries whose basenames the family declares (`src`, `yarnLock`)
    # are the only tolerated extra entries; a foreign script is red.
    ds = drv.get("inputs", {}).get("srcs") or []
    ts = template.get("inputs", {}).get("srcs") or []
    if ds != ts:
        allowed = _allowed_extra_srcs(drv, family or "")
        extra = set(ds) - set(ts)
        if (
            (set(ts) - set(ds))
            or (len(ds) - len(ts) != len(extra))
            or not all(e in allowed or _is_data_src(e, family) for e in extra)
        ):
            problems.append(
                "builder-script inputs (`inputs.srcs`) differ from the template"
            )

    dim = _env_map(drv)
    tim = _env_map(template)
    for key, value in dim.items():
        short = key.split(":", 1)[1]
        if short in ivars:
            continue
        if short == "builder":
            # the structuredAttrs/env copy of the builder is the same string as
            # the top-level `builder`, which is compared above
            # above; a second env-map complaint would double-report it.
            continue
        if short == "postFetch" and family in _POSTFETCH_FAMILIES:
            problem = _postfetch_problem(value)
            if problem is not None:
                problems.append(problem)
            continue
        if key not in tim:
            problems.append(
                f"unexpected attr `{short}` (not in the {template_label} template)"
            )
            continue
        tv = tim[key]
        if isinstance(value, str) and isinstance(tv, str):
            value = _normalised_text_value(short, value, family)
            tv = _normalised_text_value(short, tv, family)
        elif key == "sa:env" and isinstance(value, dict) and isinstance(tv, dict):
            # the structuredAttrs `env` aggregate embeds every env var; compare
            # the residual after dropping the declared instance vars (the
            # fetcher params and the hash-derived SSL toggle) — everything
            # else in the env must be byte-equal to the template's.
            def residual(d: dict) -> dict:
                return {k: v for k, v in d.items() if k not in ivars}

            value, tv = residual(value), residual(tv)
        if value != tv:
            problems.append(
                f"attr `{short}` differs from the {template_label} template"
            )
    for key in tim:
        short = key.split(":", 1)[1]
        if short in ivars:
            continue
        if short == "builder":
            continue
        if short == "postFetch" and family in _POSTFETCH_FAMILIES:
            continue
        if key not in dim:
            problems.append(
                f"attr `{short}` is missing (the {template_label} template has it)"
            )

    return problems


def match_template(
    drv: dict,
    template: dict,
    template_label: str,
    family: str | None = None,
    *,
    producers: dict[str, str] | None = None,
    walk: dict | None = None,
) -> str | None:
    """Strict structural match of a walk FOD against one template. Returns
    None when the derivation matches, else the mismatch reason. The phase
    attrs and the hook-inheriting attrs are subsumed by the whole-drv
    compare (a differing phase attr, or a phase attr the template lacks, is an
    `attr differs`/`unexpected attr` finding; a non-empty
    propagatedNativeBuildInputs differs from the template's empty value).

    `producers`/`walk` feed the builder naming for a non-template builder that
    does not equal the template's (see _whole_drv_mismatch)."""
    if template is None:
        return f"no {template_label} template available for this context"
    if family is None:
        # nixpkgs-native / catalogue matches share the NAT instance vars
        family = "nat"
    problems = _whole_drv_mismatch(
        drv,
        template,
        family=family,
        template_label=template_label,
        producers=producers,
        walk=walk,
    )
    if problems:
        return "; ".join(problems)
    return None


def _phase_mismatch(drv: dict, template: dict) -> list[str]:
    mismatches = []
    drv_phases = phase_attrs(drv)
    tpl_phases = phase_attrs(template)
    for p, val in drv_phases.items():
        tpl = tpl_phases.get(p)
        if tpl is None:
            mismatches.append(
                f"unexpected phase attr `{p}` (not in the {_tpl_label(template)} template)"
            )
        elif val != tpl:
            mismatches.append(
                f"phase attr `{p}` differs from the {_tpl_label(template)} template"
            )
    for p, tpl in tpl_phases.items():
        if p not in drv_phases:
            mismatches.append(
                f"phase attr `{p}` is missing (the {_tpl_label(template)} template has it)"
            )
    return mismatches


def _hook_inheriting_problem(drv: dict) -> str | None:
    bad = [k for k, v in hook_inheriting_attrs(drv).items() if not _empty(v)]
    if bad:
        return "hook-inheriting attr(s) not empty: " + ", ".join(bad)
    return None


def match_exact_template(
    drv: dict,
    template: dict,
    *,
    producers: dict[str, str] | None = None,
    walk: dict | None = None,
) -> str | None:
    """Exact match of a nixpkgs-native package FOD or a catalogue fixture
    against its re-evaluated template: same name and same whole serialised
    body (modulo the NAT instance vars, i.e. output paths)."""
    if drv.get("name") != template.get("name"):
        return f"name `{drv.get('name')}` != template `{template.get('name')}`"
    return match_template(
        drv,
        template,
        template.get("name") or "nat",
        family=None,
        producers=producers,
        walk=walk,
    )


def _env(sa_or_env: dict | None) -> dict:
    return sa_or_env or {}


def family_of(drv: dict) -> str | None:
    """The fetcher family a FOD belongs to, by its attr key set and the
    generated text markers (see the README's known-shapes table)."""
    sa = _env(drv.get("structuredAttrs"))
    env = drv.get("env") or {}
    builder = drv.get("builder") or ""
    if builder == "builtin:fetchurl":
        return "builtin:fetchurl"
    if "urls" in sa:
        if "owner" in sa or "repo" in sa:
            return "fetchgithub"
        if "recursiveHash" in sa:
            return "fetchzip"
        pf = sa.get("postFetch") or ""
        if "$TMPDIR/patch" in pf or 'tmpfile="$TMPDIR/patch"' in pf:
            return "fetchpatch"
        return "fetchurl"
    if "rev" in sa and (
        "fetchSubmodules" in sa or "deepClone" in sa or "leaveDotGit" in sa
    ):
        return "fetchgit"
    if (
        "SVN_SSH" in env
        or "ignoreExternals" in env
        or "SVN_SSH" in sa
        or "ignoreExternals" in sa
    ):
        return "fetchsvn"
    nbi = env.get("nativeBuildInputs") or sa.get("nativeBuildInputs") or ""
    nbi = " ".join(nbi) if isinstance(nbi, list) else str(nbi)
    if (env.get("url") or sa.get("url")) and "mercurial" in nbi:
        return "fetchhg"
    if "NPM_FETCHER_VERSION" in env:
        return "npmDeps"
    if "fetcherVersion" in env:
        return "pnpmDeps"
    if (drv.get("name") or "").startswith("caddy-src-with-plugins-"):
        return "caddyDeps"
    if "GOTOOLCHAIN" in env and "modRoot" in env:
        return "goModules"
    if "create-vendor-staging" in (env.get("buildPhase") or ""):
        return "cargoDeps"
    if "prefetch-yarn-deps" in (env.get("buildPhase") or ""):
        return "yarnDeps"
    return None


def nat_of(name: str) -> str | None:
    """The nixpkgs-native template key a drv name claims."""
    for matcher, key in NAT_ATTRIBUTES:
        if matcher(name):
            return key
    return None


def catalogue_of(drv: dict, catalogue: dict) -> str | None:
    """Catalogue key for a hand-written FOD: matched by pname (the catalogue
    entries are the two post-#1852 hand-written FODs, keyed by their stable
    pname)."""
    env = drv.get("env") or {}
    pname = env.get("pname")
    if pname and pname in catalogue:
        return pname
    name = drv.get("name") or ""
    for key in catalogue:
        if name.startswith(key + "-"):
            return key
    return None


def hook_universe(
    walk: dict, templates: dict[str, dict | list[dict]] | None = None
) -> set[str]:
    """The allowed setup-hook universe for a walk.

    The universe is the set of hook-providing derivations reachable
    (transitively through the input graph) from the **template-side seeds**
    only:
    - the derivations of the context's template bundle for this entry point
      (the goModules/pnpm templates legitimately carry make-wrapper /
      writable-tmpdir hooks), and
    - the stdenv-family derivations of the context's template sources (the
      stdenv drvs the templates reference; their bootstrap chains hold
      install-shell-files, make-shell-wrapper-hook, writable-tmpdir-as-home-
      hook, …).

    The old walk-wide clause — hooks referenced by ANY non-FOD derivation —
    is GONE (a planted `evil-hook = makeSetupHook` added to a normal
    package's nativeBuildInputs must NOT legitimise the hook).
    """
    m = walk_drvs(walk)
    providers = {k for k, v in m.items() if is_hook_provider(v)}

    def inputs_of(drv: dict) -> set[str]:
        return set(drv.get("inputs", {}).get("drvs", []))

    queue: list[str] = []
    seen: set[str] = set()
    for tpl in (templates or {}).values():
        if tpl is None:
            continue
        for t in tpl if isinstance(tpl, list) else [tpl]:
            if t is None or not isinstance(t, dict):
                continue
            for inp in inputs_of(t):
                if inp not in seen:
                    seen.add(inp)
                    queue.append(inp)
            # the stdenv-family derivations of the template sources
            for inp in inputs_of(t):
                if (
                    inp in m
                    and is_stdenv_family(m[inp].get("name") or "")
                    and inp not in seen
                ):
                    seen.add(inp)
                    queue.append(inp)
    # an input not present in the walk map (e.g. the template evaluated from a
    # source whose drvs aren't all materialised in this walk) is a dead end —
    # but the stdenv drv of a template source IS queried by name below.
    universe: set[str] = set()
    while queue:
        k = queue.pop(0)
        if k in providers:
            universe.add(k)
        node = m.get(k)
        if node is None:
            continue
        for i in inputs_of(node):
            if i not in seen:
                seen.add(i)
                queue.append(i)
    return universe


def effective_hooks(fod_key: str, walk: dict, providers: set[str]) -> list[str]:
    """The FOD's effective hooks: the hook-providing
    derivations linked to the FOD through hook-providing drvs — its direct
    hook inputs, plus the hooks those hooks depend on, recursively. (The
    chain is the semantic one: the hooks that RUN inside the FOD's build are
    its direct input hooks plus anything they source; a hook buried under
    nodejs's build closure does not execute in the FOD's own build.) A hook
    that itself inputs another hook-providing drv — or sources one from its
    inputs — is in the effective set and must be in the universe."""
    m = walk_drvs(walk)
    queue = [fod_key]
    seen: set[str] = set()
    hooks: set[str] = set()
    while queue:
        k = queue.pop(0)
        if k in seen:
            continue
        seen.add(k)
        node = m.get(k)
        if node is None:
            continue
        # descend from the FOD itself and from hook-providing drvs only: a
        # non-provider's own input hooks never run inside the FOD's build.
        if k != fod_key and k not in providers:
            continue
        for i in node.get("inputs", {}).get("drvs", []):
            if i in providers:
                hooks.add(i)
            if i not in seen:
                queue.append(i)
    return sorted(hooks)


def classify_walk(
    walk: dict,
    templates: dict[str, dict | list[dict]],
    catalogue: dict[str, dict] | None = None,
) -> list[Violation]:
    """Classify every fixed-output/impure derivation in a walk.

    Returns violations in walk order (deterministic: sorted by basename).
    An empty list means the entry point is green.
    """
    catalogue = catalogue or {}
    m = walk_drvs(walk)
    producers = builder_producers(walk)
    universe = hook_universe(walk, templates)
    providers = {k for k, v in m.items() if is_hook_provider(v)}
    violations: list[Violation] = []
    for basename, drv in sorted(m.items()):
        outputs = drv.get("outputs") or {}
        fod = any(o.get("hash") is not None for o in outputs.values())
        impure = any(o.get("impure") is True for o in outputs.values())
        if not fod and not impure:
            continue
        reason = classify_fod(drv, templates, catalogue, walk=m, producers=producers)
        if reason is not None:
            violations.append(Violation(basename, drv.get("name") or basename, reason))
        # Setup-hook rule: the hooks this FOD would execute are the
        # hook-providing derivations in its transitive input graph; every one
        # must be in the template-side universe.
        for hook in effective_hooks(basename, walk, providers):
            if hook not in universe:
                name = m[hook].get("name", hook) if hook in m else hook
                violations.append(
                    Violation(
                        basename,
                        drv.get("name") or basename,
                        f"setup hook `{name}` is outside the allowed hook universe",
                    )
                )
    return violations


def classify_fod(
    drv: dict,
    templates: dict[str, dict | list[dict]],
    catalogue: dict[str, dict],
    *,
    walk: dict | None = None,
    producers: dict[str, str] | None = None,
) -> str | None:
    """Classify a single FOD/impure derivation. None == accepted.

    `walk`/`producers` (the walk derivations map and its output->drv index,
    computed once by classify_walk) feed the builder naming."""
    family = family_of(drv)
    if family == "builtin:fetchurl":
        # The Nix built-in fetcher: no builder script exists, Nix itself
        # performs the download against the fixed hash. Nothing can execute.
        return None
    if family is not None:
        # Multiple canonical templates per family (the goModules vendor +
        # proxyVendor variants, the per-source system variants, the fetchzip
        # stripRoot variants, the fetchgit cross-stdenv variant): accepted when ANY of them matches the strict
        # whole-drv comparison.
        candidates = templates.get(family)
        if family in ("fetchurl", "fetchpatch"):
            # postFetch on these shapes follows the allow-list rule, not the
            # template text; the fetchpatch postFetch text was the ONLY structural difference
            # between the fetchurl and fetchpatch shapes in this nixpkgs rev
            # (identical key sets, byte-identical builder/args/inputs.srcs —
            # verified against the closure: no surviving key discriminates
            # them; the fetchpatch parameters are consumed into the postFetch
            # TEXT, which is source content). So the urls-shaped families
            # share both template shapes; the family label still names the
            # discriminator (for the violation message).
            extra = templates.get("fetchpatch")
            if extra:
                if not isinstance(candidates, list):
                    candidates = [candidates] if candidates else []
                if isinstance(extra, list):
                    candidates = list(candidates) + extra
                else:
                    candidates = list(candidates) + [extra]
        if not isinstance(candidates, list):
            candidates = [candidates] if candidates else []
        reasons = []
        for tpl in candidates:
            if tpl is None:
                continue
            reason = match_template(
                drv, tpl, family, family, producers=producers, walk=walk
            )  # type: ignore[arg-type]
            if reason is None:
                return None
            reasons.append(reason)
        return f"FOD looks like {family} but fails the template match: {'; '.join(reasons)}"
    # nixpkgs-native package FODs (exact re-evaluation from the same nixpkgs;
    # a host flake context may carry several nixpkgs sources — match any)
    key = nat_of(drv.get("name") or "")
    if key is not None:
        tbl = templates.get(key)
        for t in tbl if isinstance(tbl, list) else [tbl]:
            if (
                t is not None
                and match_exact_template(drv, t, producers=producers, walk=walk) is None
            ):
                return None
        return f"nixpkgs-native FOD `{key}` fails the exact-template match"
    # hand-written catalogue (the two post-#1852 entries)
    key = catalogue_of(drv, catalogue)
    if key is not None:
        fixture = catalogue[key]
        reason = match_exact_template(drv, fixture, producers=producers, walk=walk)
        if reason is None:
            return None
        return f"catalogue entry `{key}` fails the fixture match: {reason}"
    # Before failing an unrecognised shape, name a non-template builder that is
    # a downloaded derivation's output or that no derivation in the walk
    # produces; a builder equal to a template's is left to the shape check.
    builder = drv.get("builder") or ""
    if builder != "builtin:fetchurl" and walk is not None and producers is not None:
        template_builders = {
            t.get("builder")
            for fam, items in templates.items()
            for t in (items if isinstance(items, list) else [items])
            if t is not None
        }
        if builder not in template_builders:
            problem = _builder_problem(builder, drv, producers, walk)
            if problem is not None:
                return problem
    return "unrecognised FOD shape (no family key set, no nixpkgs-native template, no catalogue entry)"
