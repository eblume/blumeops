{ pkgs, ... }:
let
  mcquackLogrotate = pkgs.writeScript "mcquack-logrotate" (builtins.readFile ./mcquack-logrotate.sh);
in
{
  # Explicit target platform: indri is an M1 Mac mini, and pinning it
  # keeps the flake evaluable (and checkable) from off-box hosts.
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Determinate Nix owns the daemon, the /nix store, and the nix config
  # (/etc/nix/nix.custom.conf). nix-darwin aborts activation if
  # /usr/local/bin/determinate-nixd exists unless this is false, so this is a
  # hard requirement, not a preference. See [[indri]] §Nix.
  nix.enable = false;

  system.primaryUser = "erichblume";
  system.stateVersion = 6;

  programs.bash.enable = true;
  programs.fish.enable = true;

  # zsh management is off: the login shell is Homebrew's fish, and the
  # nix-darwin etc check aborts on the stock /etc/zshrc and /etc/zprofile
  # (their hashes are not in its known list). See [[provision]].
  programs.zsh.enable = false;

  # Rule: nothing that must work before the Nix Store mounts may live in
  # /etc/static. Every environment.etc entry is a symlink into the store,
  # dangling until Determinate's daemon mounts the volume (tens of seconds
  # after boot). Two consumers do not tolerate a dangling link:

  # - mDNSResponder's /etc/resolver scan skips one and never rescans, so
  #   /etc/resolver/ts.net (tailnet MagicDNS, nameserver 100.100.100.100)
  #   is a real file the indri play writes before the switch (its
  #   tailnet-dns task), not declared here - and not via services.tailscale,
  #   which would emit a second tailscaled daemon beside the live Homebrew
  #   root daemon.
  #
  # - sshd's `Include /etc/ssh/sshd_config.d/*` exits 1 on a missing file,
  #   refusing every ssh until the mount. So no sshd drop-in may be a
  #   nix-darwin /etc/static link:
  services.openssh.hostKeys = [];   # drops 099-host-keys.conf and its keygen script
  environment.etc."ssh/sshd_config.d/100-nix-darwin.conf".enable = false;
  environment.etc."ssh/sshd_config.d/101-authorized-keys.conf".enable = false;

  # /etc/shells: the retired 25.05 generation had replaced Apple's stock
  # file with its own symlink, and the first 26.05 generation (which
  # declares no environment.shells) removed it, leaving no /etc/shells at
  # all. Restore the stock list plus the login shell actually in use.
  environment.etc."shells".text = ''
    /bin/bash
    /bin/csh
    /bin/dash
    /bin/ksh
    /bin/sh
    /bin/tcsh
    /bin/zsh
    /opt/homebrew/bin/fish
  '';

  # Never sleep. indri is a server whose only sleep guard was Amphetamine,
  # a GUI app; on 2026-09-16 it segfaulted after 280 h and `pmset sleep 1`
  # put the box to sleep 4 minutes later (forge, registry and every
  # *.ops.eblu.me route dark until someone touched it). This is the
  # declarative `pmset -a sleep 0`; Amphetamine stays as the second layer.
  # See [[indri]] §Maintenance Notes.
  power.sleep.computer = "never";

  # --- launchd label convention for nix-managed services ---
  # Every nix-managed user agent sets serviceConfig.Label =
  # "mcquack.eblume.<svc>". Activation diffs the plist and, on change,
  # unloads, replaces and reloads it (one restart, never dual-loaded). The
  # label is what logrotate's globs and alloy's log tails key on, so it
  # must not change.
  #
  # Rollback when a generation breaks a service's plist is in a fixed
  # order: darwin-rebuild --rollback first (nix-darwin unloads agents the
  # target generation does not declare - the service is down), then run the
  # service's ansible role with its skip gate flipped, e.g. `mise run
  # provision-indri -- --tags logrotate -e logrotate_ansible_managed=true`.
  # Never ansible first. See [[provision]] §Rolling back a service flip.

  # logrotate: first service moved to nix-darwin (PR 2 of the series). The
  # Label fixes both the launchd identity and the plist filename, so the
  # generation and the (skipped-by-default) ansible role own one path,
  # ~/Library/LaunchAgents/mcquack.eblume.logrotate.plist, and swap in
  # place; the role's only job left is the rollback re-write. The log
  # paths stay the ones alloy tails and the script itself rotates.
  launchd.user.agents."mcquack.eblume.logrotate".serviceConfig = {
    Label = "mcquack.eblume.logrotate";
    ProgramArguments = [ "${mcquackLogrotate}" ];
    StartInterval = 3600;
    RunAtLoad = true;
    StandardOutPath = "/Users/erichblume/Library/Logs/mcquack.logrotate.out.log";
    StandardErrorPath = "/Users/erichblume/Library/Logs/mcquack.logrotate.err.log";
  };
}
