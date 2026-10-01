#!/bin/sh
# mcquack-colima-build: the build runner's colima VM daemon wrapper
# (eblume/blumeops#1357).
#
# `colima start` is idempotent (a no-op, exit 0, on a running VM), so it
# cannot be kept alive directly - launchd would tight-loop it. On a clean
# start it blocks until the VM is booted (first start takes minutes);
# afterwards this wrapper sleeps forever, so the KeepAlive job has a
# long-lived process and launchd does not respawn us.
#
# WaitForPaths (a real boot guard in the daemon domain) is not expressible in
# the pinned nix-darwin's serviceConfig options, so it is emulated here:
# /nix/store must be mounted (this script is a store path) and the colima
# profile must exist (rendered by the forgejo_runner role). Bounded, so a
# wedged role never hangs the daemon forever.

wait_for_paths() {
    i=0
    while [ "$i" -lt 600 ]; do
        [ -e "/nix/store" ] && [ -e "/Users/indri-build/.colima/indri-build/colima.yaml" ] && return 0
        i=$((i + 1))
        sleep 1
    done
    echo "mcquack.colima-build: /nix/store or colima.yaml absent after 600s, starting anyway" >&2
    return 0
}

# PATH and HOME come from the launchd EnvironmentVariables.
wait_for_paths

colima start --profile indri-build

rc=$?
echo "mcquack.colima-build: colima start exited $rc, holding the KeepAlive job" >&2

while true; do
    sleep 30
done
