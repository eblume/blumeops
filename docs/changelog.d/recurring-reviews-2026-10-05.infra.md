Daily service review: ntfy (argocd, last reviewed 2026-06-17). Bumped the
Nix-built ntfy image (containers/ntfy) from v2.24.0 to v2.28.0, the latest
upstream release (2026-08-27). The v2.25.0-v2.28.0 span is hardening and
feature work only: template DoS hardening and unsafe-protocol stripping
(v2.26.0), opt-in abuse ban-feed (v2.26.3), template size caps plus
email-as-username login and de-experimentalized Postgres (v2.27.0), and
request-shape limits on title/tags/cache-replay (v2.28.0). None of it
touches our 6-line server.yml config, and the single producer
(frigate-notify camera alerts) does not approach the new caps. The
fetchgit hash was verified in-pod against the forge mirror with a full
nix build; npmDepsHash/vendorHash ride the PR build check's TOFU round.
The kustomization newTag lands in the follow-up PR horkos opens once the
merge-triggered build is green.
