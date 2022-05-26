{ tf, inputs, config, pkgs, lib, ... }:
let
in {
  imports = [
    ./base16.nix
  ];

  options = {
    home.minimalSystem = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    home.profileSettings.base.duc = lib.mkOption {
      type = lib.types.package;
      default = pkgs.duc-cli;
    };
    home.profileSettings.base.defaultNameservers = lib.mkOption {
      type = lib.types.bool;
      default = !config.networking.useDHCP;
    };
  };

  config = {
    home-manager.users.arc.imports = [ ./home.nix ];
    home-manager.users.root.imports = [ ./home.nix ];

    fonts.fontconfig.enable = lib.mkDefault false;

    time.timeZone = "America/Vancouver";

    programs.zsh = {
      promptInit = lib.mkForce "";
      enableGlobalCompInit = false;
    };
    environment = {
      systemPackages = with pkgs; [
        pciutils
        iputils
        utillinux
        coreutils
        iproute
      ] ++ lib.optionals (!config.home.minimalSystem) [
        bind.dnsutils
        config.home.profileSettings.base.duc
      ];
    };

    i18n = {
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
        "en_US/ISO-8859-1"
      ];
    };

    boot = {
      kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
      kernel = {
        customBuild = lib.mkMerge [
          (lib.mkDefault config.boot.kernel.bleedingEdge)
          # actions provides way too little disk space for compiling a kernel
          (lib.mkIf (builtins.getEnv "CI_PLATFORM" == "gh-actions") (lib.mkForce false))
        ];
        arch = lib.mkIf (lib.versionAtLeast config.boot.kernelPackages.kernel.stdenv.cc.version "11.1") (lib.mkOverride 1400 "x86-64-v3");
      };
      tmpOnTmpfs = true;
      initrd = {
        compressor = lib.mkDefault (pkgs: "${pkgs.zstd}/bin/zstd");
        compressorArgs = lib.mkDefault [ "-19" ];
      };
      modprobe.modules.msr.options = {
        allow_writes = lib.mkDefault "on";
      };
    };
    system.requiredKernelConfig = with config.lib.kernelConfig; [
      (isYes "RD_ZSTD")
    ];
    powerManagement = {
      cpuFreqGovernor = lib.mkDefault "schedutil";
    };
    documentation.enable = lib.mkDefault (!config.home.minimalSystem);
    documentation.info.enable = lib.mkDefault false;
    documentation.man.enable = lib.mkDefault (!config.home.minimalSystem);
    programs.command-not-found.enable = lib.mkDefault false;
    services.udisks2.enable = lib.mkDefault (!config.home.minimalSystem);

    deploy.tf.variables.github-access = {
      export = true;
      bitw.name = "github-public-access";
    };

    nix = {
      distributedBuilds = true;
      accessTokens = lib.mkIf tf.state.enable {
        "github.com" = tf.variables.github-access.get;
      };
      experimentalFeatures = [ "nix-command" "flakes" "recursive-nix" "ca-derivations" "impure-derivations" ];
      settings = {
        builders-use-substitutes = true;
        substituters = [ "https://arc.cachix.org" ];
        trusted-public-keys = [ "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY=" ];
      };
      package = lib.mkMerge [
        (lib.mkDefault pkgs.nix)
        (lib.mkIf (!config.home.minimalSystem) pkgs.nix-readline)
      ];
      registry = {
        nixpkgs.to = {
          type = "github";
          owner = "NixOS";
          repo = "nixpkgs";
          inherit (inputs.nixpkgs.sourceInfo) lastModified rev narHash;
        };
        ci = {
          to = {
            type = "github";
            owner = "arcnmx";
            repo = "ci";
          };
          exact = false;
        };
      };
    };

    services.openssh = {
      enable = true;
      ports = lib.mkDefault [22]; # TODO: start using a different port for personal and server machines? way too much spam otherwise...
      startWhenNeeded = lib.mkDefault false;
      allowSFTP = true;
      gatewayPorts = "yes";
      kbdInteractiveAuthentication = false;
      passwordAuthentication = lib.mkDefault false;
      useDns = false;
      extraConfig = ''
        MaxSessions 100
        AllowAgentForwarding yes
        AllowTcpForwarding yes
        PrintMotd no
        PermitUserEnvironment yes
        Compression yes
        PermitTunnel yes
      '';
    };

    services.yggdrasil = {
      ifName = "y";
      nodeInfoPrivacy = true;
    };

    services.pipewire = {
      media-session = {
        enable = lib.mkDefault (config.services.pipewire.enable && !config.services.wireplumber.enable);
      };
      wireplumber.enable = lib.mkDefault false; # disable the built-in module
    };
    services.wireplumber.enable = lib.mkDefault false;

    security.sudo.enable = true;
    security.sudo.extraConfig = ''
      Defaults env_keep += "SSH_CLIENT"
    '';

    services.udev.extraRules = ''
      SUBSYSTEM=="i2c-dev", OWNER="root", GROUP="kvm", MODE="0660"
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
      SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", MODE="0660", GROUP="uinput"
      ACTION=="add", SUBSYSTEM=="input", DEVPATH=="/devices/virtual/input/*", MODE="0666", GROUP="users"
    '';

    services.timesyncd.enable = true;
    services.fstrim.enable = true;

    networking = {
      nameservers = lib.mkIf config.home.profileSettings.base.defaultNameservers (
        lib.mkDefault [ "8.8.8.8" "1.0.0.1" ]
      );
    };

    systemd = {
      watchdog = {
        enable = lib.mkDefault true;
        rebootTimeout = lib.mkDefault "5min";
      };
      extraConfig = ''
        DefaultStandardError=journal
        DefaultTimeoutStartSec=40s
        DefaultTimeoutStopSec=40s
        DefaultLimitMEMLOCK=infinity
      '';
      services.mdmonitor.enable = false;
    };
    #systemd.services."getty@tty1".wantedBy = ["getty.target"];
    #systemd.targets."getty".wants = ["getty@tty1.service"]; # TODO: how do I use template units???

    # TODO: what was root-remount.service for?
    # TODO: systemd units/services

    # systemd services
    /*systemd.services."hdd-apm@" = {
      description = "Hard drive power saving";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/usr/bin/hdparm -B 251 /dev/disk/by-id/wwn-%i";
      };
    };
    systemd.services.inactive-shutdown = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.bash}/bin/sh -ec 'if [ "$(${pkgs.systemd}/bin/loginctl list-sessions --no-pager --no-legend | ${pkgs.coreutils}/bin/wc -l)" -eq 0 ]; then ${pkgs.systemd}/bin/systemctl poweroff; fi'
        '';
      };
    };
    systemd.timers.inactive-shutdown = {
      timerConfig = {
        OnBootSec = "30m";
        OnUnitInactiveSec = "10m";
      };
    };
    systemd.services."remote-host-reachable@" = {
      description = "Tests if a remote host is reachable via ping";
      after = ["network.target"];
      serviceConfig = {
        Type = "oneshot";
        TimeoutSec = 30;
        ExecStart = "${pkgs.bash}/bin/sh -c 'while ! ${pkgs.iputils}/bin/ping -c 1 -W 2 %I > /dev/null; do true; done'";
      };
    };
    systemd.services."wake-on-lan@" = {
      description = "Broadcasts a Wake on LAN signal";
      after = ["network.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.wol}/bin/wol -v %i";
      };
    };*/
  };
}