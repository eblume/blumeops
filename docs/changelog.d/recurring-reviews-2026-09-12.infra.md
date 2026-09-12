Daily service review: shower (argocd, last reviewed 2026-05-15). Deployed
v1.1.3 is still the newest published version on the Forgejo PyPI simple
index (enumerated 1.0.0–1.1.3, each with wheel+sdist sha256 fragments).
The cycle-1 visibility gap is resolved: the simple index and file
endpoints that returned 401 during the planning cycle are now
anonymously readable, so upstream enumeration works from the pod with no
new grant. In-pod verification: the derivation parses under the same
nixpkgs flake the CI builder resolves, the wheel/sdist fetchurls download
live from forge.ops.eblu.me, and the pip-deps FOD installs cleanly
against today's pypi.ops.eblu.me (django 6.1.1, gunicorn 26.2.0,
pillow 12.3.0, numpy 2.5.3, scipy 1.18.1) — but its output no longer
matches the pinned outputHash: the unpinned transitive closure has
drifted since the v1.1.3-3645098-nix image build. The deployed image is
unaffected (immutable), but the next rebuild will need a TOFU hash round,
and the newer transitive deps (notably django 6.1) deserve a
compatibility check before any such rebuild is dispatched. Stamped
last-reviewed in service-versions.yaml; no version bump.
