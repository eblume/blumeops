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
{
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
