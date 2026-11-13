# Everyday data, network, and debugging CLIs for interactive sessions on
# ringtail, so no per-repo mise pin is needed.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Core: data, files, and plumbing
    jq
    yq-go
    dnsutils # dig, nslookup
    tree
    file
    lsof
    pv
    rsync
    tmux
    moreutils # sponge, ts, vipe

    # Network. mtr comes from programs.mtr below (capability wrapper), not here.
    socat
    netcat-openbsd
    tcpdump # root-only by design
    nmap
    iperf3
    xh

    # Inspection
    strace
    dust
    duf
    btop

    # Text and dev
    sd
    delta
    difftastic
    hyperfine
    entr
    tldr
  ];

  # Installs mtr plus the mtr-packet wrapper (cap_net_raw+p), so it runs unprivileged.
  programs.mtr.enable = true;
}
