`provision-ringtail` no longer hangs, or half-applies a switch, when activation
restarts the network under it. Two independent causes, one per fix:

`nixos-rebuild switch` ran as a child of the SSH session it was invoked over,
and activation restarts `sshd`, `tailscaled` and the network stack — so a session
teardown mid-activation could kill the switch partway through. It now runs as a
transient systemd unit (`blumeops-nixos-rebuild`) via `systemd-run`, outside the
session's lifetime; the play reconnects with `wait_for_connection`, polls the
unit to completion, and fails with the unit's journal if systemd's `Result` is
anything but `success`.

Separately, `ansible.cfg` had no `[ssh_connection]` keepalives. When the far end
goes away mid-task the TCP connection is not closed, only silent, so ssh waited
on it forever and a playbook that had finished its work hung until someone
noticed. `ServerAliveInterval=15` with `ServerAliveCountMax=20` bounds that to
about five minutes; `ConnectTimeout=30` bounds the initial dial, which the
keepalives do not cover. This applies to every playbook, indri included.
