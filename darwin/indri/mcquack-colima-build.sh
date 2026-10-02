#!/bin/sh
# mcquack-colima-build: the build runner's colima VM daemon wrapper
# (eblume/blumeops#1357).
#
# `colima start` is idempotent (a no-op, exit 0, on a running VM), so it
# cannot be kept alive directly - launchd would tight-loop it. On a clean
# start it blocks until the VM is booted (first start takes minutes);
# afterwards this wrapper polls `colima status` and exits nonzero if the VM
# ever stops, so KeepAlive + ThrottleInterval (10 s) restarts it.
#
# WaitForPaths (a real boot guard in the daemon domain) is not expressible in
# the pinned nix-darwin's serviceConfig options, so the wait for the colima
# profile (rendered by the forgejo_runner role after the human registers the
# runner) is emulated here: idle until it exists. /nix itself needs no wait:
# the unit's argv0 is the non-/nix mcquack.nix-wait wrapper (eblume/blumeops#1225),
# which blocks until the store mounts and execs this script.

profile=/Users/indri-build/.colima/indri-build/colima.yaml
while [ ! -e "$profile" ]; do
    sleep 30
done

# A failed start exits nonzero: KeepAlive + ThrottleInterval retry in ~10s.
colima start --profile indri-build || exit 1

# A dead VM is restartable: colima status exits nonzero while stopped.
while colima status --profile indri-build >/dev/null 2>&1; do
    sleep 30
done
exit 1
