# Factorio dedicated server — ringtail's first externally-shared service.
#
# Security model (see docs/how-to/host-factorio-for-a-guest.md and the research
# report "Hosting Factorio on ringtail for a friend"):
#   - The Tailscale ACL is the real boundary. ringtail's host firewall already
#     trusts the whole tailscale0 interface, so `openFirewall = false` keeps the
#     port closed on the LAN (enp5s0) and internet while the tailnet reaches it.
#   - Guests are *shared* onto ringtail (autogroup:shared), never *invited* as
#     members, so they inherit none of the member-facing grants. The ACL then
#     hands them exactly udp:34197 on tag:factorio. See pulumi/tailscale.
{ ... }:
let
  # TEMPORARY version pin: nixos-25.11 ships factorio-headless 2.0.76, but the
  # Steam client on gilbert auto-updated to 2.0.77 and Factorio refuses to join a
  # server on a different build. Override just the versions.json fed to the
  # upstream derivation so we track the client until nixpkgs catches up — then
  # delete this whole overlay and let the pinned nixpkgs provide the version.
  #
  # sha256 (hex) of the headless tarball, from:
  #   nix-prefetch-url https://factorio.com/get-download/2.0.77/headless/linux64 \
  #     --name factorio_headless_x64-2.0.77.tar.xz   # -> base32
  #   nix hash convert --hash-algo sha256 --to base16 <base32>
  factorioDist = {
    name = "factorio_headless_x64-2.0.77.tar.xz";
    version = "2.0.77";
    tarDirectory = "x64";
    url = "https://factorio.com/get-download/2.0.77/headless/linux64";
    needsAuth = false;
    sha256 = "c4efc11529f74d37c96933e291e0db73fd9f5aa4738913d9301b24680b3e947f";
  };
  factorioVersions = {
    x86_64-linux.headless = {
      stable = factorioDist;
      experimental = factorioDist;
    };
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      factorio-headless = prev.factorio-headless.override {
        versionsJson = final.writeText "factorio-versions.json" (
          builtins.toJSON factorioVersions
        );
      };
    })
  ];

  services.factorio = {
    enable = true;
    port = 34197; # UDP; the Factorio default
    game-name = "Erich & Ben";
    description = "Private tailnet server";

    public = false; # not advertised on factorio.com matchmaking
    lan = false; # remote friend, not LAN discovery
    requireUserVerification = false; # tailnet is the auth boundary; avoids a
    # hard runtime dependency on factorio.com's
    # auth server just to let someone join
    openFirewall = false; # tailscale0 is already a trusted interface — do NOT
    # punch a hole on the LAN/WAN side

    saveName = "benandi";
    nonBlockingSaving = true; # avoid autosave stutter on a shared game
    extraSettings = {
      max_players = 0; # unlimited
      # To require a game password, point `extraSettingsFile` at a JSON file
      # holding {"game_password":"..."} (sourced from the blumeops/agents vault)
      # rather than inlining it here — inline would be world-readable in the Nix
      # store. Omitted for now: the tailnet share is the access boundary.
    };
    # In-game admins are set by factorio.com username. Add yours here once known:
    #   admins = [ "<your-factorio.com-username>" ];
  };
}
