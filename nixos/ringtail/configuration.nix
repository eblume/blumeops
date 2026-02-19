{ config, pkgs, lib, ... }:

let
  # Libraries needed by mise-compiled runtimes (python-build, etc.)
  buildDeps = with pkgs; [ zlib readline bzip2 xz libffi ncurses sqlite openssl ];
in
{
  # Allow unfree packages (NVIDIA drivers, Steam)
  nixpkgs.config.allowUnfree = true;

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # No TPM module on this board
  systemd.tpm2.enable = false;

  # Networking
  networking.hostName = "ringtail";
  networking.networkmanager.enable = true;

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

  # 1Password (modules handle CLI group/setgid and polkit for GUI integration)
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "eblume" ];
  };

  # Steam
  programs.steam = {
    enable = true;
    dedicatedServer.openFirewall = true;
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
      "--write-kubeconfig-mode=644"
      "--tls-san=ringtail.tail8d86e.ts.net"
    ];
  };

  # K3s containerd registry mirrors (pull through Zot on indri)
  environment.etc."rancher/k3s/registries.yaml".source = ./k3s-registries.yaml;

  # Tailscale
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-routes" "--ssh" ];
  };

  # Trust Tailscale interface (ArgoCD on indri connects via tailnet)
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

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
    gcc
    gnumake
    pkg-config
    openssl
    gnupg
    unzip
    fuzzel
    pulseaudio
    librewolf
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
            adaptive_sync = "on";
            bg = "~/.config/sway/wallpaper.jpg fill";
          };
        };
        keybindings = let mod = "Mod4"; in {
          "${mod}+Return" = "exec wezterm";
          "${mod}+Shift+q" = "kill";
          "${mod}+d" = "exec wmenu-run";
          "${mod}+space" = "exec fuzzel";
          "${mod}+Shift+c" = "reload";
          "${mod}+l" = "exec swaylock -f";
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
          border-radius = 8;
          border-width = 2;
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
        bash coreutils curl gawk gitMinimal gnused nodejs wget
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

  # NixOS release
  system.stateVersion = "25.11";
}
