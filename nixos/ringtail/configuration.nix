{ config, pkgs, lib, ... }:

let
  # Libraries needed by mise-compiled runtimes (python-build, etc.)
  buildDeps = with pkgs; [ zlib readline bzip2 xz libffi ncurses sqlite openssl ];
in
{
  imports = [
    ./agent-workspaces.nix
    ./factorio.nix
    ./heph-eblume.nix
  ];

  # Allow unfree packages (NVIDIA drivers, Steam)
  nixpkgs.config.allowUnfree = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # No TPM module on this board
  systemd.tpm2.enable = false;

  # Networking
  # Wired interface (enp5s0) uses a static IP configured by NixOS scripted
  # networking; NetworkManager is left enabled for the wireless fallback only.
  networking.hostName = "ringtail";
  networking.networkmanager = {
    enable = true;
    unmanaged = [ "interface-name:enp5s0" ];
  };
  networking.useDHCP = false;
  networking.interfaces.enp5s0.ipv4.addresses = [{
    address = "192.168.1.21";
    prefixLength = 24;
  }];
  networking.defaultGateway = "192.168.1.1";
  networking.nameservers = [ "192.168.1.1" "1.1.1.1" ];

  # Pin sifaka (Synology NAS) to its LAN IP so NFS mounts resolve over the LAN
  # rather than via tailscale MagicDNS. This keeps NFS traffic off the tailnet
  # and makes it immune to tailscale node-key churn: on 2026-06-26 sifaka's
  # tailscale node key expired, MagicDNS kept resolving `sifaka` to the dead
  # node, and every NFS mount hung. /etc/hosts (nsswitch `files`) wins over
  # MagicDNS, so this is authoritative. sifaka's NFS export already permits
  # 192.168.1.0/24. NOTE: assumes sifaka stays at .203 — keep a DHCP reservation.
  networking.hosts."192.168.1.203" = [ "sifaka" "sifaka.tail8d86e.ts.net" ];

  # K3s pod networking and Tailscale tunnel routing require IP forwarding.
  # NixOS leaves this off by default; previously it was being enabled
  # implicitly by NM/scripted-DHCP setup, but with static networking we
  # have to set it explicitly.
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # Time zone
  time.timeZone = "America/Los_Angeles";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";

  # NVIDIA proprietary drivers
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # Use proprietary driver for RTX 4080
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # NVIDIA container toolkit (CDI specs + runtime for containerd/k3s GPU pods)
  hardware.nvidia-container-toolkit.enable = true;

  # Stable path to NVIDIA driver libraries for k3s device plugin pod mounts.
  # Avoids mounting all of /nix/store — only the driver derivation is needed.
  environment.etc."nvidia-driver/lib".source = "${config.hardware.nvidia.package}/lib";

  # Stable-path wrapper for nvidia-container-runtime.cdi (the CDI-based OCI
  # runtime that injects GPU devices/libs from NixOS-generated CDI specs).
  # The wrapper adds runc to PATH since k3s doesn't ship a standalone runc binary.
  environment.etc."nvidia-container-runtime/nvidia-runtime-cdi-wrapper" = {
    mode = "0755";
    text = ''
      #!/bin/sh
      export PATH="${pkgs.runc}/bin:$PATH"
      exec ${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-container-runtime.cdi "$@"
    '';
  };

  # NFS client support (required for k3s to mount NFS PersistentVolumes)
  boot.supportedFilesystems = [ "nfs" ];

  # Wayland / Sway
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export WLR_NO_HARDWARE_CURSORS=1
    '';
    extraPackages = with pkgs; [
      swaylock
      swayidle
      wezterm # terminal
      wmenu # app launcher
      mako # notifications
      grim # screenshots
      slurp # region selection
    ];
  };
  security.polkit.enable = true;
  security.pam.services.swaylock = {}; # Allow swaylock to authenticate
  security.sudo.wheelNeedsPassword = false;

  # Enable greetd as display manager for sway
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd 'sway --unsupported-gpu'";
        user = "greeter";
      };
    };
  };

  # PipeWire for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Fish shell
  programs.fish.enable = true;

  # Firefox with 1Password extension
  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = {
        "{d634138d-c276-4fc8-924b-40a0ea21d284}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/1password-x-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };
  };

  # 1Password (modules handle CLI group/setgid and polkit for GUI integration)
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "eblume" ];
  };

  # K3s single-node cluster
  services.k3s = {
    enable = true;
    role = "server";
    tokenFile = "/etc/k3s/token";
    extraFlags = toString [
      "--disable=traefik"
      "--disable=servicelb"
      "--disable=metrics-server"
      # 0600, NOT 0644: ringtail is multi-user now (the unprivileged `agent`
      # user runs the agent workspaces). A world-readable admin kubeconfig would
      # hand `agent` cluster-admin — and via the argocd-* secrets, a deploy path
      # — bypassing the vault gate that is supposed to keep agents author-only.
      # Root still reads it; ansible provisions via `k3s kubectl` as root, and a
      # human on the host uses `sudo k3s kubectl`. See agent-workspaces.md.
      "--write-kubeconfig-mode=600"
      "--tls-san=ringtail.tail8d86e.ts.net"
      # Kubelet refuses to start when swap is present unless told otherwise.
      # We run zram swap (below) as an OOM pressure valve since this is a
      # gaming+homelab host. Default swapBehavior is NoSwap, so pod cgroups
      # still get memory.swap.max=0 (RAM-bound, OOM at limit as before) — only
      # host processes (the game, system.slice) may use the zram swap.
      "--kubelet-arg=fail-swap-on=false"
    ];
    containerdConfigTemplate = ''
      {{ template "base" . }}

      [plugins.'io.containerd.cri.v1.runtime']
        enable_cdi = true
        cdi_spec_dirs = ["/var/run/cdi", "/etc/cdi"]

      [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.nvidia]
        privileged_without_host_devices = false
        runtime_type = "io.containerd.runc.v2"
      [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.nvidia.options]
        BinaryName = "/etc/nvidia-container-runtime/nvidia-runtime-cdi-wrapper"
    '';
  };

  # Raise memlock rlimit for k3s so eBPF workloads (Beyla/Alloy tracing) can
  # call setrlimit(RLIMIT_MEMLOCK, unlimited) inside privileged containers.
  systemd.services.k3s.serviceConfig.LimitMEMLOCK = "infinity";

  # Allow BPF in privileged containers (Beyla eBPF tracing). NixOS defaults
  # to 2 (block BPF outside init namespace even with CAP_BPF). Value 1 allows
  # BPF for processes with CAP_BPF/CAP_SYS_ADMIN in any namespace.
  boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = 1;

  # Compressed RAM-backed swap as an OOM pressure valve. This box is a
  # gaming + ~25-service homelab on 32G with no headroom; a game spike (e.g.
  # Diablo 4) previously pushed the host over the top and the kernel OOM-killed
  # k3s pods (no swap to fall back on). zram lets cold anonymous pages (idle
  # services, the game's untouched pages) compress into RAM instead of
  # triggering kills — no disk thrash, no SSD wear. zstd ~3:1 on such pages.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50; # max uncompressed logical size; real RAM cost is /ratio
  };

  # Only swap under genuine pressure — keep the game's hot working set resident.
  boot.kernel.sysctl."vm.swappiness" = 10;

  # systemd-oomd swap-kill. The zram valve above stops the *kernel* OOM-killer
  # from firing on a host memory spike, but adds no real capacity — a game spike
  # (CK3, Diablo 4) can still fill zram to ~95% and thrash the whole host into a
  # multi-minute memory-pressure stall (everything frozen, sshd included). oomd
  # was running but monitored nothing.
  #
  # Goal: when the host exhausts swap, NON-k3s processes die first. Pods are
  # pinned to no-swap (fail-swap-on=false + NoSwap policy above), so the only
  # cgroups holding swap are host/user procs — chiefly the gaming session
  # (user.slice ~15G swap vs k3s.service ~47M, kubepods ~0). ManagedOOMSwap=kill
  # on the root slice makes oomd kill the heaviest-swap cgroup when swap crosses
  # SwapUsedLimit, which is therefore always a non-k3s process. Pod OOM remains
  # the job of each pod's memory limit + the kernel cgroup OOM-killer, untouched.
  #
  # We deliberately avoid systemd.oomd.enableRootSlice: it enrolls the root slice
  # for *pressure*-based killing, which picks a victim by memory footprint across
  # all descendants and could reap a big pod (immich) before the game — the
  # opposite of "non-k3s first".
  systemd.slices."-".sliceConfig.ManagedOOMSwap = "kill";

  # Act before zram is fully saturated — at 90% of a 15G zram the host is already
  # thrashing. 80% gives oomd room to kill while reclaim still works.
  environment.etc."systemd/oomd.conf.d/ringtail.conf".text = ''
    [OOM]
    SwapUsedLimit=80%
  '';

  # oomd reads oomd.conf only at startup and NixOS won't restart it for a drop-in
  # change; restart oomd when our SwapUsedLimit override changes.
  systemd.services.systemd-oomd.restartTriggers = [
    config.environment.etc."systemd/oomd.conf.d/ringtail.conf".source
  ];

  # K3s containerd registry mirrors (pull through Zot on indri)
  environment.etc."rancher/k3s/registries.yaml".source = ./k3s-registries.yaml;

  # Tailscale
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-routes" "--ssh" ];
  };

  # Trust Tailscale and k3s CNI interfaces
  # - tailscale0: ArgoCD on indri connects via tailnet
  # - cni0/flannel.1: k3s pod overlay network (pods must reach host API server)
  networking.firewall.trustedInterfaces = [ "tailscale0" "cni0" "flannel.1" ];

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # User account
  users.users.eblume = {
    isNormalUser = true;
    shell = pkgs.fish;
    extraGroups = [ "wheel" "networkmanager" "video" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILmh1SSCdDAyu3vkSQH7kAXEPDi8APyjo9JXDTjtha2j"
    ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    git
    kubectl
    python3 # required for Ansible
    vim
    htop
    curl
    wget
    chezmoi
    neovim
    eza
    fd
    fzf
    zoxide
    starship
    atuin
    bat
    ripgrep
    mise
    uv
    gcc
    gnumake
    pkg-config
    openssl
    gnupg
    unzip
    fuzzel
    pulseaudio
  ];

  # Allow running dynamically linked binaries (mise-installed runtimes, etc.)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = buildDeps ++ [ pkgs.icu ];

  # Compile-time flags for mise python-build and similar source builds
  environment.sessionVariables = {
    PKG_CONFIG_PATH = lib.makeSearchPath "lib/pkgconfig" (map lib.getDev buildDeps);
    CFLAGS = lib.concatMapStringsSep " " (p: "-I${lib.getDev p}/include") buildDeps;
    LDFLAGS = lib.concatMapStringsSep " " (p: "-L${lib.getLib p}/lib") buildDeps;
  };

  # Fonts
  fonts.packages = with pkgs; [
    nerd-fonts.victor-mono
  ];

  # Home Manager (minimal — chezmoi owns dotfiles, this is ringtail-specific)
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.eblume = {
    home.stateVersion = "25.11";

    # External-IP helper, managed declaratively so it can't drift again. Renamed
    # from `ip`: the old stray ~/.config/fish/functions/ip.fish shadowed
    # iproute2's real `ip`, so `ip addr`/`ip route` silently curled ipinfo.io.
    # The stray ip.fish (and a broken prettyping-less ping.fish) are removed at
    # deploy; this keeps the helper available as `myip`.
    xdg.configFile."fish/functions/myip.fish".text = ''
      function myip --description 'Show public IP (no arg) or look up an IP via ipinfo.io'
          if count $argv >/dev/null
              curl ipinfo.io/$argv
          else
              curl checkip.amazonaws.com
          end
      end
    '';

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
        "text/html" = [ "firefox.desktop" ];
      };
    };

    wayland.windowManager.sway = {
      enable = true;
      checkConfig = false;
      config = {
        terminal = "wezterm";
        modifier = "Mod4";
        fonts = {
          names = [ "VictorMono Nerd Font" ];
          size = 10.0;
        };
        bars = [{ command = "waybar"; }];
        gaps = {
          inner = 8;
          outer = 4;
        };
        window = {
          border = 2;
          titlebar = false;
          commands = [
            { command = "inhibit_idle fullscreen"; criteria = { class = ".*"; }; }
            { command = "inhibit_idle fullscreen"; criteria = { app_id = ".*"; }; }
            { command = "fullscreen enable"; criteria = { class = "steam_app_1174180"; }; }
          ];
        };
        colors = {
          focused = {
            border = "#8aadf4";
            background = "#24273a";
            text = "#cad3f5";
            indicator = "#c6a0f6";
            childBorder = "#8aadf4";
          };
          focusedInactive = {
            border = "#494d64";
            background = "#1e2030";
            text = "#a5adcb";
            indicator = "#494d64";
            childBorder = "#494d64";
          };
          unfocused = {
            border = "#363a4f";
            background = "#1e2030";
            text = "#6e738d";
            indicator = "#363a4f";
            childBorder = "#363a4f";
          };
          urgent = {
            border = "#ed8796";
            background = "#24273a";
            text = "#cad3f5";
            indicator = "#ed8796";
            childBorder = "#ed8796";
          };
        };
        input = {
          "*" = {
            xkb_options = "ctrl:nocaps";
          };
        };
        output = {
          "DP-1" = {
            mode = "2560x1440@165Hz";
            # VRR off: the OMEN 27i IPS pumps gamma/brightness when the panel
            # refresh swings into its low VRR range (e.g. low-fps game
            # cutscenes), producing a ~20Hz flicker that compounds over a long
            # session until a reboot. Fixed refresh at 165Hz eliminates it.
            # If you want VRR back, cap in-game fps so refresh never dips low.
            adaptive_sync = "off";
            bg = "~/.config/sway/wallpaper.jpg fill";
          };
        };
        # Extend (not replace) the home-manager default sway keybindings.
        # lib.mkForce is needed on keys whose defaults we want to override
        # (same priority otherwise conflicts). Audio keys and Mod+d (wmenu-run
        # vs the default menu binding) don't collide with defaults.
        keybindings = let mod = "Mod4"; in lib.mkOptionDefault {
          "${mod}+Return" = lib.mkForce "exec wezterm";
          "${mod}+d" = lib.mkForce "exec wmenu-run";
          "${mod}+space" = lib.mkForce "exec fuzzel";
          "${mod}+l" = lib.mkForce "exec swaylock -f";
          "${mod}+F1" = "exec grep '^bindsym' ~/.config/sway/config | fuzzel --dmenu";
          "--locked XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
          "--locked XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -5%";
          "--locked XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +5%";
          "--locked XF86AudioMicMute" = "exec pactl set-source-mute @DEFAULT_SOURCE@ toggle";
        };
        startup = [
          { command = "1password"; }
          { command = "steam"; }
        ];
      };
    };

    programs.swaylock = {
      enable = true;
      settings = {
        color = "24273a";
        font = "VictorMono Nerd Font";
        font-size = 24;
        indicator-radius = 100;
        indicator-thickness = 7;
        inside-color = "24273a";
        inside-clear-color = "24273a";
        inside-ver-color = "24273a";
        inside-wrong-color = "24273a";
        key-hl-color = "8aadf4";
        bs-hl-color = "ed8796";
        ring-color = "363a4f";
        ring-clear-color = "f5a97f";
        ring-ver-color = "8aadf4";
        ring-wrong-color = "ed8796";
        line-color = "00000000";
        line-clear-color = "00000000";
        line-ver-color = "00000000";
        line-wrong-color = "00000000";
        separator-color = "00000000";
        text-color = "cad3f5";
        text-clear-color = "cad3f5";
        text-ver-color = "cad3f5";
        text-wrong-color = "ed8796";
        show-failed-attempts = true;
      };
    };

    services.swayidle = {
      enable = true;
      events = [
        { event = "before-sleep"; command = "${pkgs.swaylock}/bin/swaylock -f"; }
        { event = "lock"; command = "${pkgs.swaylock}/bin/swaylock -f"; }
      ];
      timeouts = [
        {
          timeout = 900; # 15 minutes — lock screen
          command = "${pkgs.swaylock}/bin/swaylock -f";
        }
        {
          timeout = 3600; # 60 minutes — turn off display
          command = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
          resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
        }
      ];
    };

    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "VictorMono Nerd Font:size=14";
          terminal = "wezterm";
          width = 40;
          horizontal-pad = 16;
          vertical-pad = 8;
        };
        border = {
          radius = 8;
          width = 2;
        };
        colors = {
          background = "24273add";
          text = "cad3f5ff";
          match = "8aadf4ff";
          selection = "363a4fff";
          selection-text = "cad3f5ff";
          selection-match = "8aadf4ff";
          border = "8aadf4ff";
        };
      };
    };

    programs.waybar = {
      enable = true;
      settings = [{
        layer = "top";
        position = "top";
        height = 30;
        modules-left = [ "sway/workspaces" "sway/mode" ];
        modules-center = [ "sway/window" ];
        modules-right = [ "pulseaudio" "bluetooth" "network" "clock" "tray" ];
        tray = { spacing = 8; };
        clock = { format = "{:%a %b %d  %H:%M}"; };
        network = {
          interval = 2;
          format-ethernet = "{bandwidthDownBits} down  {bandwidthUpBits} up";
          format-wifi = "{essid} {bandwidthDownBits} down  {bandwidthUpBits} up";
          format-disconnected = "disconnected";
        };
        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = " muted";
          format-icons = {
            headphone = "";
            default = [ "" "" "" ];
          };
        };
      }];
      style = ''
        * {
          font-family: "VictorMono Nerd Font";
          font-size: 13px;
          border: none;
          border-radius: 0;
          min-height: 0;
        }
        window#waybar {
          background-color: rgba(30, 32, 48, 0.9);
          color: #cad3f5;
          margin: 4px 4px 0 4px;
        }
        #workspaces button {
          padding: 0 8px;
          margin: 0 2px;
          color: #6e738d;
          background: transparent;
          border-radius: 4px;
        }
        #workspaces button.focused {
          color: #8aadf4;
          background: #363a4f;
          border-bottom: 2px solid #8aadf4;
        }
        #workspaces button.urgent {
          color: #ed8796;
        }
        #window {
          color: #a5adcb;
        }
        #bluetooth {
          color: #8aadf4;
        }
        #bluetooth.off, #bluetooth.disabled {
          color: #6e738d;
        }
        #clock, #network, #pulseaudio, #bluetooth, #tray {
          padding: 0 12px;
          margin: 4px 2px;
          color: #cad3f5;
          background: #363a4f;
          border-radius: 4px;
        }
        #clock {
          color: #8aadf4;
        }
        #pulseaudio {
          color: #f5a97f;
        }
        #network {
          color: #a6da95;
        }
        #network.disconnected {
          color: #ed8796;
        }
      '';
    };
  };

  # Ensure mounted drives are owned by eblume
  systemd.tmpfiles.rules = [
    "d /mnt/games 0755 eblume users -"
    "d /mnt/storage1 0755 eblume users -"
    "d /mnt/storage2 0755 eblume users -"
  ];

  # Container config for skopeo (used by the forgejo runner to push images)
  # and for unqualified image pulls via Zot pull-through cache
  environment.etc."containers/policy.json".text = builtins.toJSON {
    default = [{ type = "insecureAcceptAnything"; }];
  };
  environment.etc."containers/registries.conf".text = ''
    unqualified-search-registries = ["registry.ops.eblu.me", "docker.io", "ghcr.io", "quay.io"]
  '';

  # Tor Snowflake proxy (anti-censorship bridge, not an exit node)
  systemd.services.snowflake-proxy = {
    description = "Tor Snowflake Proxy";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = toString [
        "${pkgs.snowflake}/bin/proxy"
        "-metrics" "-metrics-address" "0.0.0.0"
        "-geoipdb" "${pkgs.tor.geoip}/share/tor/geoip"
        "-geoip6db" "${pkgs.tor.geoip}/share/tor/geoip6"
      ];
      DynamicUser = true;
      Restart = "always";
      RestartSec = 10;
      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      MemoryDenyWriteExecute = true;
      MemoryMax = "512M";
    };
  };

  # Forgejo Actions runner (nix container builder)
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.nix_container_builder = {
      enable = true;
      name = "ringtail-nix-builder";
      url = "https://forge.ops.eblu.me";
      tokenFile = "/etc/forgejo-runner/token.env";
      labels = [ "nix-container-builder:host" ];
      hostPackages = with pkgs; [
        bash coreutils curl gawk gitMinimal gnused jq nodejs wget
        nix skopeo
      ];
      settings = {
        log.level = "info";
        runner = {
          capacity = 1;
          timeout = "3h";
        };
      };
    };
  };

  # Enable nix flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Allow the runner's dynamic user to access the nix daemon
  nix.settings.trusted-users = [ "gitea-runner" ];

  # Prevent machine from sleeping (workstation should stay on)
  systemd.sleep.extraConfig = ''
    AllowSuspend=no
    AllowHibernation=no
    AllowHybridSleep=no
    AllowSuspendThenHibernate=no
  '';

  # Cap systemd-coredump. Wine/Proton games (Diablo IV, etc.) segfault
  # regularly and dump multi-GB cores; with the stock (effectively unbounded)
  # limits, systemd-coredump then spends minutes streaming and compressing the
  # dump to disk — e.g. a single D4 crash produced a 4.6G core, read 13.7G and
  # wrote 17.4G, pinning the CPU and locking up the desktop for ~3.5 minutes.
  # Those cores are useless anyway: Nix .so files carry no build-id, so no
  # backtrace can be generated. Capping uncompressed size at 1G makes oversized
  # cores get logged-but-skipped (the kernel stops dumping once we stop reading)
  # while real service cores (well under 1G) are still captured. MaxUse bounds
  # the on-disk store so frequent game crashes can't accumulate (was at 8.6G).
  systemd.coredump.extraConfig = ''
    ProcessSizeMax=1G
    ExternalSizeMax=1G
    MaxUse=2G
  '';

  # NixOS release
  system.stateVersion = "25.11";
}
