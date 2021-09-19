{ config, pkgs, lib, ... }:
let
in {
  imports = [
    ./base16.nix
  ];

  options = {
    home.profiles.base = lib.mkEnableOption "home profile: base";
  };

  config = lib.mkIf config.home.profiles.base {
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
        bind.dnsutils
        (if config.home.profiles.gui
          then duc
          else duc-cli)
      ] ++ (lib.optional config.services.yggdrasil.enable pkgs.yggdrasil);
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

    nix = {
      distributedBuilds = true;
      extraOptions = ''
        builders-use-substitutes = true
      '' + lib.optionalString (lib.versionAtLeast builtins.nixVersion "2.4") ''
        experimental-features = nix-command flakes
      '';
      binaryCaches = [ "https://arc.cachix.org" ];
      binaryCachePublicKeys = [ "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY=" ];
      package = pkgs.nix-readline;
    };

    # TODO: initrd compression

    services.openssh = {
      enable = true;
      ports = lib.mkDefault [22]; # TODO: start using a different port for personal and server machines? way too much spam otherwise...
      startWhenNeeded = lib.mkDefault false;
      allowSFTP = true;
      gatewayPorts = "yes";
      challengeResponseAuthentication = false;
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

    security.sudo.enable = true;
    security.sudo.extraConfig = ''
      Defaults env_keep += "SSH_CLIENT"
    '';

    services.udev.extraRules = ''
      SUBSYSTEM=="i2c-dev", OWNER="root", GROUP="kvm", MODE="0660"
      SUBSYSTEM=="usb", ATTR{idVendor}=="1d79", ATTR{idProduct}=="0100", OWNER="root", GROUP="kvm"
      SUBSYSTEM=="usb", ATTR{idVendor}=="0f0d", ATTR{idProduct}=="0083", OWNER="root", GROUP="kvm"
      SUBSYSTEM=="vfio", OWNER="root", GROUP="kvm"
      SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", MODE="0660", GROUP="uinput"
      ACTION=="add", SUBSYSTEM=="input", DEVPATH=="/devices/virtual/input/*", MODE="0666", GROUP="users"
    '';

    services.timesyncd.enable = true;
    services.fstrim.enable = true;

    systemd.extraConfig = ''
      DefaultStandardError=journal
      DefaultTimeoutStartSec=40s
      DefaultTimeoutStopSec=40s
      DefaultLimitMEMLOCK=infinity
      RuntimeWatchdogSec=60s
      ShutdownWatchdogSec=5min
    '';
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
