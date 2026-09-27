Move indri's jellyfin LaunchAgent (unit) to nix-darwin under the role's
historical mcquack.jellyfin label and plist path (in-place swap forbids
renaming), with the unit executing the DMG-installed app through the
stable ~/opt/jellyfin-current symlink the role's ungated tasks maintain
— the DMG stays pinned in the role, so a version bump is role-only and
the nix unit never changes; the role's gate covers only the plist +
load tasks (rollback re-write). Part of eblume/blumeops#1291.
