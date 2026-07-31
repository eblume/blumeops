# The `agent` user and its heph spoke on ringtail.
#
# The agent *workspace* (Claude Code Remote Control) was retired from the host on
# 2026-07-31 and now runs as a k3s pod — see
# docs/explanation/agent-containerization.md. What remains here is the `agent` OS
# user and its hephd **spoke**, deliberately kept host-level: the containerized
# agent pod SHARES this one hephd via a hostPath-mounted socket
# (`~agent/.local/share/heph/hephd.sock`) rather than running a per-pod daemon.
# heph is the intentional in-boundary substrate (see [[project_heph_in_agent_boundary]]).
#
# Secret placed by ansible (ansible/playbooks/ringtail.yml), NOT nix:
#   /etc/agents/op-token   agents-ringtail-rw service-account token (0400 agent)
{ config, pkgs, lib, ... }:

let
  agentHome = "/home/agent";
  opToken = "/etc/agents/op-token";

  # Transparent `op` shim: inject the service-account token, exec the real op.
  # Prepended to the spoke's PATH so its token load/save (op read/edit of the
  # heph-spoke-token in the agents vault) works without exporting the token.
  opShim = pkgs.writeShellScriptBin "op" ''
    if [ -z "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -r ${opToken} ]; then
      OP_SERVICE_ACCOUNT_TOKEN="$(cat ${opToken})"
      export OP_SERVICE_ACCOUNT_TOKEN
    fi
    exec ${pkgs._1password-cli}/bin/op "$@"
  '';

  # ── heph spoke ────────────────────────────────────────────────────────────
  # The agent runs a hephd *spoke* synced to the indri hub. heph is an
  # in-boundary agentic-workflow substrate, deliberately NOT isolated out (unlike
  # the blumeops vault). The containerized agent pod mounts this spoke's socket.
  cargoBin = "${agentHome}/.cargo/bin";
  # Shared spoke plumbing (version pin, hub/OIDC endpoints, install machinery) —
  # heph-eblume.nix builds Erich's own spoke from the same file, so the two
  # spokes can't drift apart on the heph version.
  heph = import ./heph-common.nix { inherit pkgs lib; };
  hephTokenRef = "op://agents/heph-spoke-token/token"; # in the agents vault

  # Persist the spoke's OIDC token in the agents 1Password vault (no plaintext at
  # rest). Reads the token JSON on stdin (from hephd `--token-save-cmd`) and
  # writes it to a CONCEALED field — NEVER via argv (`/proc/<pid>/cmdline` is
  # world-readable), using op template files + `jq --rawfile`.
  hephTokenSave = pkgs.writeShellScriptBin "heph-token-save" ''
    set -eu
    umask 077
    d="$(${pkgs.coreutils}/bin/mktemp -d)"
    trap '${pkgs.coreutils}/bin/rm -rf "$d"' EXIT
    ${pkgs.coreutils}/bin/cat > "$d/token" # token JSON on stdin
    if ${opShim}/bin/op item get heph-spoke-token --vault agents --format json </dev/null > "$d/item.json" 2>/dev/null; then
      ${pkgs.jq}/bin/jq --rawfile t "$d/token" \
        '(.fields |= map(if .label == "token" then .value = $t else . end))' \
        "$d/item.json" > "$d/new.json"
      ${opShim}/bin/op item edit heph-spoke-token --vault agents --template "$d/new.json" </dev/null >/dev/null
    else
      ${pkgs.jq}/bin/jq -n --rawfile t "$d/token" \
        '{title: "heph-spoke-token", category: "API_CREDENTIAL", fields: [{label: "token", type: "CONCEALED", value: $t}]}' \
        > "$d/new.json"
      ${opShim}/bin/op item create --vault agents --template "$d/new.json" </dev/null >/dev/null
    fi
  '';

  # The spoke daemon. Shares the default socket/db with the pod's `heph` CLI (the
  # pod mounts ~agent/.local/share/heph). The spoke ADOPTS the hub's owner id: the
  # `heph-agents` credential is only the login identity (revocable), not a
  # separate data owner.
  hephSpoke = pkgs.writeShellScript "agent-heph-spoke" ''
    export HOME=${agentHome}
    # pkgs.bash provides `sh`: hephd's command token store runs the load/save
    # commands via `Command::new("sh")`, which does a PATH lookup — without a
    # shell on PATH the token never loads and every hub sync 401s.
    export PATH="${opShim}/bin:${hephTokenSave}/bin:${lib.makeBinPath [ pkgs.jq pkgs.coreutils pkgs.bash ]}:${cargoBin}:$PATH"
    exec ${cargoBin}/hephd --mode local \
      --hub-url ${heph.hubUrl} \
      --owner-id ${heph.ownerId} \
      --oidc-issuer ${heph.issuer} \
      --oidc-client-id heph \
      --token-load-cmd "${opShim}/bin/op read ${hephTokenRef}" \
      --token-save-cmd "heph-token-save"
  '';

  # The agent's spoke unit quartet (install oneshot + timer + spoke + path unit)
  # comes from the shared machinery; only the launcher above is agent-specific.
  hephStack = heph.mkSpokeStack {
    prefix = "agent-heph";
    user = "agent";
    group = "agent";
    home = agentHome;
    spokeExec = hephSpoke;
    who = "the agent";
  };
in
{
  # uid/gid pinned so ansible can chown /etc/agents/* numerically before the user
  # exists in passwd on a first-ever deploy (secrets are written in pre_tasks, the
  # user is created later by nixos-rebuild). Also matches the containerized
  # agent's runAsUser (1500), so the pod can read the mounted heph socket.
  users.groups.agent.gid = 1500;
  users.users.agent = {
    isNormalUser = true;
    uid = 1500;
    home = agentHome;
    group = "agent";
    shell = pkgs.bash;
    description = "Claude Code agent — heph spoke (workspace now containerized)";
    # No extraGroups: deliberately not in wheel, networkmanager, or onepassword-cli.
  };

  # Timer + path unit for the agent's heph spoke (see heph-common.nix: the compile
  # stays off the activation path, and the spoke starts the moment the install
  # produces hephd — bootstrap never shows a failed unit).
  systemd.services = hephStack.services;
  systemd.timers = hephStack.timers;
  systemd.paths = hephStack.paths;
}
