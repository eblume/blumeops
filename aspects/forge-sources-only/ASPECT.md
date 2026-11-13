# forge-sources-only

Supply-chain control: a source fetched by a build comes from a forge mirror, a
known package registry, or a deliberately reviewed exception. A new source on
a third-party host is a decision made in review, not an accident.

Scans every `*.nix` file (flake inputs included) and every `Dockerfile*` in
blumeops for fetches: `url =` in a fetcher or a pinned source attrset, flake
`github:`/`git+` inputs, Go module paths in plugin lists, `fetchFromGitHub`,
`fetchFromGitLab`, `fetchFromGitea` and `fetchFromForgejo` (which name no URL,
so they never match an exception), and `git clone` / `ADD` / `curl` / `wget`
in Dockerfiles. Shell fetches inside
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
