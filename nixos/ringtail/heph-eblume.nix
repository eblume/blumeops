# Erich's own heph spoke on ringtail: hephd running as `eblume`, synced to the
# indri hub, so interactive sessions on this host have a real `heph` CLI
# (`~/.cargo/bin/heph`, installed by the eblume-heph-install oneshot).
#
# Deliberately SEPARATE from the agent's spoke (agent-workspaces.nix): hephd
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

  hephStack = heph.mkSpokeStack {
    prefix = "eblume-heph";
    user = "eblume";
    group = "users";
    inherit home;
    spokeExec = spoke;
    who = "eblume";
  };
in
{
  systemd.services = hephStack.services;
  systemd.timers = hephStack.timers;
  systemd.paths = hephStack.paths;
}
