{ ... }:
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

  # Tahoe rewrote /etc/zshrc and /etc/zprofile as plain stock files whose
  # hashes are not in nix-darwin's known list, so a default (enabled) zsh
  # module aborts the etc check at activation. The login shell is
  # Homebrew's fish; zsh management buys nothing. See [[provision]].
  programs.zsh.enable = false;

  # MagicDNS for the tailnet, re-owned from the old nix-darwin generation
  # (its former /etc/static home). Written explicitly rather than via
  # services.tailscale, which would also emit a second tailscaled
  # LaunchDaemon beside the live Homebrew root daemon. See [[provision]].
  # The knownSha256Hashes are the etc-check's (re)adoption clause: a live
  # file that is not a nix-darwin /etc/static symlink must match one, or
  # activation aborts. First is this text as writeText (the old generation's
  # form); second is upstream tailscale module's, for a file tailscaled
  # itself wrote.
  environment.etc."resolver/ts.net".text = "nameserver 100.100.100.100";
  environment.etc."resolver/ts.net".knownSha256Hashes = [
    "8ec2fad1fddce9b9fec9f558d3623ce783d1b630ba516f8e58672dda3edbc9eb"
    "2c28f4fe3b4a958cd86b120e7eb799eee6976daa35b228c885f0630c55ef626c"
  ];

  # --- launchd label convention for the service migrations (PRs 2-8) ---
  # Each service moved from an ansible-templated plist to
  # launchd.user.agents here sets serviceConfig.Label = "mcquack.eblume.<svc>",
  # so the nix plist lands on the same path as ansible's; activation diffs it
  # and, on change, unloads, replaces and reloads it (one restart, never
  # dual-loaded). The label is what logrotate's globs and alloy's log tails
  # key on, so it must not change.
  #
  # Rollback order when a generation changes a service's plist is fixed:
  # darwin-rebuild --rollback first (nix-darwin unloads and deletes agents
  # the target generation does not declare, regardless of who wrote the
  # plist last - the service is down), then
  # `mise run provision-indri -- --tags <svc>` (ansible writes the plist
  # back). Never ansible first. See [[provision]] §Rolling back a service flip.
}
