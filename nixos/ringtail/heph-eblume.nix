# Erich's own heph spoke on ringtail: hephd running as `eblume`, synced to the
# indri hub, so interactive sessions on this host have a real `heph` CLI (the
# store package's bin dir, on the session PATH via the shims in
# configuration.nix).
#
# Deliberately SEPARATE from the agent's spoke (agent-heph-spoke.nix): hephd
# sockets/dbs are per-user, and the two spokes hold different login identities —
# this one is Erich himself; the agent's is the independently revocable
# `talos-heph` user. Sharing one daemon would couple Erich's own heph access
# to the agent kill switches. Both spokes adopt the same hub owner id, so they
# operate on the same nodes.
{ config, pkgs, lib, hephPkg, ... }:

let
  heph = import ./heph-common.nix { inherit pkgs lib; };
  home = "/home/eblume";

  # Token store: a 0600 JSON file (`hephd --token-file`, the headless-spoke
  # store), refreshed in place. The alternatives don't fit an always-on system
  # service: desktop `op` needs the unlocked 1Password GUI, and there is no
  # Secret Service keyring outside a desktop session. Plaintext-at-rest is
  # bounded by the eblume user boundary on Erich's own box — the same boundary
  # that protects ~/.ssh.
  #
  # One-time seed (interactively, as eblume on ringtail; approve in the browser
  # as yourself — no hub-side change needed, Erich is already the hub owner):
  #   heph auth login --hub-url ${heph.hubUrl} \
  #     --issuer ${heph.issuer} --client-id heph \
  #     --token-file ~/.config/heph/hub-token.json
  tokenFile = "${home}/.config/heph/hub-token.json";

  spoke = pkgs.writeShellScript "eblume-heph-spoke" ''
    export HOME=${home}
    exec ${hephPkg}/bin/hephd --mode local \
      --hub-url ${heph.hubUrl} \
      --owner-id ${heph.ownerId} \
      --oidc-issuer ${heph.issuer} \
      --oidc-client-id heph \
      --token-file ${tokenFile}
  '';
in
{
  # The spoke is a systemd USER service, unlike the agent's: hephd and the
  # `heph` CLI find each other via the default socket path, which is
  # XDG_RUNTIME_DIR-dependent. A system service has no XDG_RUNTIME_DIR and
  # binds the ~/.local/share fallback, while eblume's interactive shells look
  # in /run/user/1000 — they'd never meet. In the user manager both sides
  # resolve /run/user/1000/heph/hephd.sock. Lingering keeps the user manager
  # (and so the spoke) running from boot, no login needed.
  #
  # No separate restart trigger: a pin bump rewrites this unit's ExecStart,
  # and the nixos switch restarts the unit — since nixos-25.11 the only switch
  # implementation is switch-to-configuration-ng, which restarts changed user
  # units for every user whose manager is running (logged-in or lingering),
  # and lingering keeps user@1000 running from boot.
  users.users.eblume.linger = true;

  systemd.user.services.eblume-heph-spoke = {
    description = "heph spoke for eblume (hephd synced to the indri hub)";
    unitConfig.ConditionUser = "eblume";
    wantedBy = [ "default.target" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      ExecStart = spoke;
      Restart = "always";
      RestartSec = 10;
    };
  };
}
