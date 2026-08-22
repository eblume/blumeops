# Erich's own heph spoke on ringtail: hephd running as `eblume`, synced to the
# indri hub, so interactive sessions on this host have a real `heph` CLI
# (`~/.cargo/bin/heph`, installed by the eblume-heph-install oneshot).
#
# Deliberately SEPARATE from the agent's spoke (agent-heph-spoke.nix): hephd
# sockets/dbs are per-user, and the two spokes hold different login identities —
# this one is Erich himself; the agent's is the independently revocable
# `heph-agents` user. Sharing one daemon would couple Erich's own heph access
# to the agent kill switches. Both spokes adopt the same hub owner id, so they
# operate on the same nodes.
{ config, pkgs, lib, ... }:

let
  heph = import ./heph-common.nix { inherit pkgs lib; };
  home = "/home/eblume";
  cargoBin = "${home}/.cargo/bin";

  # Token store: a 0600 JSON file (`hephd --token-file`, the headless-spoke
  # store), refreshed in place. The alternatives don't fit an always-on system
  # service: desktop `op` needs the unlocked 1Password GUI, and there is no
  # Secret Service keyring outside a desktop session. Plaintext-at-rest is
  # bounded by the eblume user boundary on Erich's own box — the same boundary
  # that protects ~/.ssh.
  #
  # One-time seed (interactively, as eblume on ringtail; approve in the browser
  # as yourself — no hub-side change needed, Erich is already the hub owner):
  #   ~/.cargo/bin/heph auth login --hub-url ${heph.hubUrl} \
  #     --issuer ${heph.issuer} --client-id heph \
  #     --token-file ~/.config/heph/hub-token.json
  tokenFile = "${home}/.config/heph/hub-token.json";

  spoke = pkgs.writeShellScript "eblume-heph-spoke" ''
    export HOME=${home}
    exec ${cargoBin}/hephd --mode local \
      --hub-url ${heph.hubUrl} \
      --owner-id ${heph.ownerId} \
      --oidc-issuer ${heph.issuer} \
      --oidc-client-id heph \
      --token-file ${tokenFile}
  '';

  installUnits = heph.mkInstallUnits {
    prefix = "eblume-heph";
    user = "eblume";
    group = "users";
    inherit home;
    who = "eblume";
    # Erich's spoke is a *desktop* spoke: on top of the daemon and CLI it gets
    # the agenda TUI and the quick-capture popover, which the agent's headless
    # spoke has no use for. configuration.nix puts shims for the same list on
    # the session PATH.
    bins = heph.desktopBins;
    # User-scope spoke; the oneshot has no XDG_RUNTIME_DIR, so point at the
    # user bus explicitly. The guard skips the restart when the user manager
    # is down (linger keeps it up from boot).
    restartSpoke = ''
      { [ -d /run/user/1000 ] && XDG_RUNTIME_DIR=/run/user/1000 systemctl --user try-restart eblume-heph-spoke.service; }
    '';
  };
in
{
  # The install oneshot + trigger timer are system units (they need
  # network-online and don't care about session env).
  systemd.services = installUnits.services;
  systemd.timers = installUnits.timers;

  # The spoke itself is a systemd USER service, unlike the agent's: hephd and
  # the `heph` CLI find each other via the default socket path, which is
  # XDG_RUNTIME_DIR-dependent. A system service has no XDG_RUNTIME_DIR and
  # binds the ~/.local/share fallback, while eblume's interactive shells look
  # in /run/user/1000 — they'd never meet. In the user manager both sides
  # resolve /run/user/1000/heph/hephd.sock. Lingering keeps the user manager
  # (and so the spoke) running from boot, no login needed.
  users.users.eblume.linger = true;

  systemd.user.services.eblume-heph-spoke = {
    description = "heph spoke for eblume (hephd synced to the indri hub)";
    unitConfig = {
      ConditionUser = "eblume";
      # Skip (cleanly, not failed) until eblume-heph-install produces hephd.
      ConditionPathExists = "${cargoBin}/hephd";
    };
    startLimitIntervalSec = 0;
    serviceConfig = {
      ExecStart = spoke;
      Restart = "always";
      RestartSec = 10;
    };
  };

  # Start the spoke the moment the install produces the binary (and at boot
  # when it already exists).
  systemd.user.paths.eblume-heph-spoke = {
    description = "Start eblume's heph spoke once hephd is installed";
    unitConfig.ConditionUser = "eblume";
    wantedBy = [ "default.target" ];
    pathConfig.PathExists = "${cargoBin}/hephd";
  };
}
