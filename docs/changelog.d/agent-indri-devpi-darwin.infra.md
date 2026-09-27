Move indri's devpi LaunchAgent to nix-darwin at the role's label and
plist path (mcquack.eblume.devpi), with the unit executing the
uv-managed venv's devpi-server at /Users/erichblume/devpi/venv — the
venv build, the pip install and the devpi-init seeding stay
role-rendered, so a version bump is role-only and the nix unit never
changes; the role's gate covers only the plist + load tasks (rollback
re-write). Part of eblume/blumeops#1291.
