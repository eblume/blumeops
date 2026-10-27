# forge-sources-only

Supply-chain control: a source fetched by a build comes from a forge mirror, a
known package registry, or a deliberately reviewed exception. A new source on
a third-party host is a decision made in review, not an accident.

Scans every `*.nix` file (flake inputs included) and every `Dockerfile*` in
blumeops for fetches: `url =` in a fetcher or a pinned source attrset, flake
`github:`/`git+` inputs, Go module paths in plugin lists, `fetchFromGitHub`
and `fetchFromGitLab` (which name no URL, so they never match an exception),
and `git clone` / `ADD` / `curl` / `wget` in Dockerfiles. Shell fetches inside
a Nix build are the `fod-only-downloads` aspect's concern, not this one's. Each source is
graded by rule: a forge-hosted source (`forge.ops.eblu.me`, mirrors included),
PyPI (`files.pythonhosted.org/packages/`), or nixpkgs source tarballs and
flake input. Anything else must have an entry in
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

**Alternatives rejected.** A full-URL ratchet baseline (see above). An
`nix-instantiate --parse` scan (exact, but eval-sized, past the 10 s/test
budget). Interpolated hosts beyond the literal prefix are not resolved; the
exception list records what the text scan can see.
