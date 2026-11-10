#!/usr/bin/env python3
"""Detach every attachment of a disk image, wherever it happens to be mounted.

`hdiutil detach` takes a device node or a mount point; handing it the image
path fails with "No such file or directory". That is how an attachment left
behind by an interrupted run survives cleanup and makes the next
`hdiutil attach` fail with "Resource busy". Resolving the image's device
entries from `hdiutil info -plist` instead finds it wherever it landed --
the pinned mountpoint, /Volumes/Jellyfin Server, a re-attached second copy.

Prints one line per detached device and nothing at all when the image is not
attached, so the caller can decide changed/unchanged from stdout.
"""

import os
import plistlib
import subprocess
import sys

HDIUTIL = "/usr/bin/hdiutil"


def attached_devices(image):
    """Whole-disk device nodes currently backed by `image`."""
    info = plistlib.loads(
        subprocess.run(
            [HDIUTIL, "info", "-plist"], check=True, capture_output=True
        ).stdout
    )
    devices = []
    for img in info.get("images", []):
        paths = {
            os.path.realpath(p)
            for p in (img.get("image-path"), img.get("image-alias"))
            if p
        }
        if image not in paths:
            continue
        entries = [
            e["dev-entry"] for e in img.get("system-entities", []) if e.get("dev-entry")
        ]
        if entries:
            # The shortest dev-entry is the whole disk (/dev/disk4); detaching
            # it takes its partitions (/dev/disk4s1, ...) along with it.
            devices.append(min(entries, key=len))
    return devices


def main(argv):
    if len(argv) != 2:
        print(f"usage: {argv[0]} <image.dmg>", file=sys.stderr)
        return 2
    image = os.path.realpath(argv[1])
    for device in attached_devices(image):
        # -force: the volume is read-only, and a Spotlight indexer still
        # holding it should not fail the play.
        subprocess.run([HDIUTIL, "detach", "-force", device], check=True)
        print(f"detached {device}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
