Shower app container now bakes the wheel + Python deps into the image
at build time via `buildPythonPackage` instead of pip-installing on
first boot. Boots are deterministic and don't depend on forge PyPI
being reachable from the pod. The `wheelHash` in
`containers/shower/default.nix` is the sha256 sourced from the
[forge PyPI simple index](https://forge.eblu.me/api/packages/eblume/pypi/simple/adelaide-baby-shower-app/);
bumping the version means bumping that hash too.

Borgmatic now covers the shower app: SQLite is dumped from the live
pod via `kubectl exec` (mirroring the existing mealie entry, with
`context: k3s-ringtail`), and the prize-photo media share is picked up
through `/Volumes/shower` (sifaka SMB mount on indri, same pattern as
`/Volumes/photos`).
