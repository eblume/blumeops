# Static per-instance users for the nix-container-builder runners
# (eblume/blumeops#2442). The module's DynamicUser puts every builder on one
# uid and one state tree, and that state tree sits in the private tmpfs
# DynamicUser mounts under /var/lib/private (noexec). Each builder gets its
# own static user; the hardening DynamicUser implied is re-declared, as the
# priv runner does in configuration.nix.
{ builders }:
{ lib, pkgs, ... }:
let
  dirOf = b: "/var/lib/${b.user}/${b.key}";
  # Carries the forge registration over from the DynamicUser state dir, so
  # each instance keeps its identity instead of registering a second runner.
  # Runs as root ("+"), before the module's registration script; a no-op once
  # .runner exists in the new dir.
  # .runner is copied last: it is the guard, so a partial copy is retried.
  migrate = b: pkgs.writeShellScript "nix-builder-migrate-state-${b.key}" ''
    set -euo pipefail
    new=${dirOf b}
    old=/var/lib/private/gitea-runner/${b.key}
    if [ ! -e "$new/.runner" ] && [ -e "$old/.runner" ]; then
      install -d -o ${b.user} -g ${b.user} -m 0755 "$new"
      for f in .labels .token-hash .runner; do
        install -o ${b.user} -g ${b.user} -m 0600 "$old/$f" "$new/$f"
      done
    fi
  '';
in
{
  users.users = lib.listToAttrs (map (b: lib.nameValuePair b.user {
    isSystemUser = true;
    group = b.user;
    home = "/var/lib/${b.user}";
  }) builders);
  users.groups = lib.listToAttrs (map (b: lib.nameValuePair b.user { }) builders);

  systemd.services = lib.listToAttrs (map (b: lib.nameValuePair "gitea-runner-${b.key}" {
    environment.HOME = lib.mkForce (dirOf b);
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce b.user;
      Group = lib.mkForce b.user;
      StateDirectory = lib.mkForce b.user;
      WorkingDirectory = lib.mkForce "-${dirOf b}";
      # What DynamicUser=yes implied.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      PrivateTmp = true;
      RemoveIPC = true;
      RestrictSUIDSGID = true;
      ExecStartPre = lib.mkBefore [ "+${migrate b}" ];
    };
  }) builders);
}
