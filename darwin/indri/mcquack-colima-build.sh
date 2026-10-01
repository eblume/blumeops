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
# the pinned nix-darwin's serviceConfig options, so the wait for the colima
# profile (rendered by the forgejo_runner role after the human registers the
# runner) is emulated here: idle until it exists. /nix/store needs no wait -
# this script is a store path, so nix is mounted whenever it runs.

profile=/Users/indri-build/.colima/indri-build/colima.yaml
while [ ! -e "$profile" ]; do
    sleep 30
done

# A failed start exits nonzero: KeepAlive + ThrottleInterval retry in ~10s.
colima start --profile indri-build || exit 1

# colima start returned 0 and the VM is running; hold the KeepAlive job so
# launchd does not respawn us.
while true; do
    sleep 30
done
