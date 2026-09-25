Move indri's jellyfin LaunchAgent (unit) to nix-darwin under the
role's historical mcquack.jellyfin label and plist path (the in-place
swap forbids renaming it), keeping the DMG-installed app binary (the
nixpkgs package is a server package, not the app bundle) — the role's
gate now covers only the plist + load tasks (rollback re-write), which
a DMG version bump also uses to re-point the plist. Part of
eblume/blumeops#1291.
