# forge-sources-only

Supply-chain control: a source fetched by a build comes from a forge mirror, a
known package registry, or a deliberately reviewed exception. A new source on
a third-party host is a decision made in review, not an accident.

**Tripwire, not boundary.** This aspect is a tripwire behind PR review, not a
boundary: it reads text, and a determined author can hide a fetch from it. Its
job is to make a new unreviewed source show up as a failing check, so a
reviewer sees it. It does not replace reviewing the diff.

Scans every `*.nix` file (flake inputs included), every `flake.lock` (each
locked node), and every `Dockerfile*`/`Containerfile*` in blumeops for fetches:
`url =` (bare or quoted key, single line or across lines) in a fetcher or a
pinned source attrset, `urls = [ ... ]` lists of fetchers (a `urls` value that is not a plain
list of string literals, such as one joined with `++`, is a violation), `builtins.fetchTree`/
`fetchGit` attrsets naming a type/host/owner/repo (a non-literal argument or an
unresolvable one is a violation), flake `github:`/`git+` inputs, Go module paths
in plugin lists, `fetchFromGitHub`, `fetchFromGitLab`, `fetchFromGitea` and
`fetchFromForgejo` (which name no URL, so they never match an exception), and
Dockerfile fetches: `git clone` (https, `ssh://`, `git://`, scp-style
`[user@]host:path` with or without a user, after git global options such as
`git -C dir` or `git -c k=v`), `ADD` (flags allowed before the source, and JSON or quoted
forms; any `http(s)://`, `git://`, `ssh://` or scp-style `[user@]host:path`
source), and `curl`/`wget` URLs and scheme-less
host targets. Backslash line continuations are joined before scanning, with
comment and blank lines inside one skipped. A fetch target containing `$` (a
shell variable) and any `url.<x>.insteadOf` in a Dockerfile fails
closed, as does an unresolved Nix interpolation. Shell fetches inside
a Nix build are the `fod-only-downloads` aspect's concern, not this one's.
Each source is graded by rule. A forge-hosted source (`forge.ops.eblu.me`,
over https, `ssh://`, `git+https` or `git+ssh`) is allowed only when its owner
is `eblume` or `mirrors`; any other owner, `talos/*` included, is a violation.
This is a fail-closed allowlist: the talos bot can push to other owners, and
bot-authored code behind a talos-owned pin never appears in a PR for review.
An allowed owner's path can still serve a commit that exists only in a fork
PR head (`/eblume/<repo>/archive/<sha>`, or a fetchgit `rev`); a text scan
cannot see that, so review of the pinning PR is the control.
The owner list is kept in step with `mise-tasks/validate-argocd-apps` and
enforced by `tests/test_forge_owner_agreement.py`. PyPI
(`files.pythonhosted.org/packages/`) and nixpkgs source tarballs and flake
input are the other rule classes. Anything else must have an entry in
`aspects/forge-sources-only/exceptions.json`, and every entry must carry a
`kind` (`exceptional` with a one-line reason, or `pending-removal` with a
tracking reference). An entry that matches no source is stale and fails, so
the list holds only live exceptions.

**Residual gaps (not fixed here).**

- (a) `${…}` in a Nix url/urls string is not graded beyond the literal prefix
  (pre-existing). An interpolated host such as `https://${h}/...` is a
  violation.
- (b) Variable- and `inherit`-fed fetcher arguments are not graded. Data-driven
  fetches, such as the authentik lock data, are reviewed in their data file.
- (c) Attrset-form inputs in `flake.nix` are backstopped by the `flake.lock`
  scan, not by this one.
- (d) Other package managers' git sources (pip, npm, go) are not scanned.

**Why an invariant, not a ratchet.** A stored baseline of full URLs goes stale
with every version bump, and registry traffic (hundreds of wheel URLs) would
bloat it. Rules classify registry and mirror traffic by host and path, so only
the odd sources live in the list.

**Scope.** `APPLIES_TO = ["eblume/blumeops"]`. The scan skips `aspects/` (this
aspect's fixtures) and `fixtures/` trees. Mirroring is not required: integrity
comes from FOD content hashes, and this aspect makes a new source a reviewed
decision.

**Alternatives rejected.** A full-URL ratchet baseline (see above). A denylist
of `talos/` (unknown bot-writable owners would pass). An
`nix-instantiate --parse` scan (exact, but eval-sized, past the 10 s/test
budget). Interpolated hosts beyond the literal prefix are not resolved; the
exception list records what the text scan can see.
