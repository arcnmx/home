{ config, pkgs, lib, ... }:
let
  hugepages = { where, options }: {
    before = ["sysinit.target"];
    unitConfig = {
      DefaultDependencies = "no";
      ConditionPathExists = "/sys/kernel/mm/hugepages";
      ConditionCapability = "CAP_SYS_ADMIN";
      ConditionVirtualization = "!private-users";
    };
    what = "hugetlbfs";
    where = where;
    type = "hugetlbfs";
    options = options;
    mountConfig = {
      Group = "kvm";
    };
  };
in {
  options = {
    home.profiles.base = lib.mkEnableOption "home profile: base";
  };

  config = lib.mkIf config.home.profiles.base {
    fonts.fontconfig.enable = lib.mkDefault false;
    i18n = {
      consolePackages = [pkgs.tamzen];
      consoleFont = "Tamzen7x14";
      consoleColors = let # Solarized dark
        S_base03 = "002b36";
        S_base02 = "073642";
        S_base01 = "586e75";
        S_base00 = "657b83";
        S_base0 = "839496";
        S_base1 = "93a1a1";
        S_base2 = "eee8d5";
        S_base3 = "fdf6e3";
        S_yellow = "b58900";
        S_orange = "cb4b16";
        S_red = "dc322f";
        S_magenta = "d33682";
        S_violet = "6c71c4";
        S_blue = "268bd2";
        S_cyan = "2aa198";
        S_green = "859900";
      in [
        S_base02 S_red S_green S_yellow S_blue S_magenta S_cyan S_base2
        S_base03 S_orange S_base01 S_base00 S_base0 S_violet S_base1 S_base3
      ];
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
        "ja_JP.UTF-8/UTF-8"
        "en_US/ISO-8859-1"
      ];
    };

    time.timeZone = "America/Vancouver";

    services.resolved.enable = true;
    programs.zsh.promptInit = lib.mkForce "";
    environment = {
      pathsToLink = ["/share/zsh" "/share/bash-completion"];
      systemPackages = with pkgs; [
        usbutils
        pciutils
        iputils
        utillinux
        coreutils
        iproute
        bind.dnsutils
        (if config.home.profiles.gui
          then duc
          else duc.override { pango = null; cairo = null; })
      ] ++ (lib.optional config.services.yggdrasil.enable pkgs.yggdrasilctl);
    };

    boot = {
      kernelPackages = pkgs.linuxPackages_latest;
      blacklistedKernelModules = ["pcspkr"];
      extraModprobeConfig = ''
        options snd_hda_intel power_save=1 power_save_controller=Y
        options kvm_amd avic=1
      '';
      kernel.sysctl = {
        "net.ipv6.conf.all.accept_ra_rt_info_max_plen" = 128;
        "net.ipv6.conf.default.accept_ra_rt_info_max_plen" = 128;
      };
    };
    # TODO: initrd compression

    hardware.enableAllFirmware = true;

    services.openssh = {
      enable = true;
      ports = [22];
      startWhenNeeded = true;
      forwardX11 = true;
      allowSFTP = true;
      permitRootLogin = "yes"; # "prohibit-password"
      gatewayPorts = "yes";
      challengeResponseAuthentication = false;
      #authorizedKeysFiles = [".ssh/authorized_keys"];
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
      ACTION=="add", SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", GROUP="uinput"
      ACTION=="add", SUBSYSTEM=="input", DEVPATH=="/devices/virtual/input/*", MODE="0666", GROUP="users"
    '';

    services.timesyncd.enable = true;
    services.fstrim.enable = true;
    services.usbmuxd.enable = true;

    systemd.network.links.b2b128 = {
      matchConfig = {
        MACAddress = "00:50:b6:14:85:e0";
      };

      linkConfig = {
        Description = "Belkin B2B128 USB Ethernet";
        Name = "ethb2b";
      };
    };
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

    networking.firewall.enable = false;
    #networking.nftables.enable = true;
    # TODO: migrate nftables config

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
    systemd.mounts = [
      (hugepages { where = "/dev/hugepages"; options = "mode=0775"; })
      (hugepages { where = "/dev/hugepages1G"; options = "pagesize=1GB,mode=0775"; })
    ];
  };
}
