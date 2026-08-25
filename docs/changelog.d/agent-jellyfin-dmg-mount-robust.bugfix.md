The `jellyfin` Ansible role (indri) now detaches stray DMG mounts by image
path instead of a fixed list of guessed mountpoints, removes a stale
mountpoint directory before attaching, stops passing `-quiet` to
`hdiutil attach` so mount failures log the actual error, and asserts the app
bundle is visible at the pinned mountpoint before copying.
