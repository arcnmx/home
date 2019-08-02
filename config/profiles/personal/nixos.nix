{ pkgs, config, lib, ... }: with lib; let
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
  c1 = ''\e[22;34m'';
  c2 = ''\e[1;35m'';
  nixos = [
    " ${c1}          ::::.    ${c2}':::::     ::::'          "
    " ${c1}          ':::::    ${c2}':::::.  ::::'           "
    " ${c1}            :::::     ${c2}'::::.:::::            "
    " ${c1}      .......:::::..... ${c2}::::::::             "
    " ${c1}     ::::::::::::::::::. ${c2}::::::    ${c1}::::.     "
    " ${c1}    ::::::::::::::::::::: ${c2}:::::.  ${c1}.::::'     "
    " ${c2}           .....           ::::' ${c1}:::::'      "
    " ${c2}          :::::            '::' ${c1}:::::'       "
    " ${c2} ........:::::               ' ${c1}:::::::::::.  "
    " ${c2}:::::::::::::                 ${c1}:::::::::::::  "
    " ${c2} ::::::::::: ${c1}..              ${c1}:::::           "
    " ${c2}     .::::: ${c1}.:::            ${c1}:::::            "
    " ${c2}    .:::::  ${c1}:::::          ${c1}'''''    ${c2}.....    "
    " ${c2}    :::::   ${c1}':::::.  ${c2}......:::::::::::::'    "
    " ${c2}     :::     ${c1}::::::. ${c2}':::::::::::::::::'     "
    " ${c1}            .:::::::: ${c2}'::::::::::            "
    " ${c1}           .::::''::::.     ${c2}'::::.           "
    " ${c1}          .::::'   ::::.     ${c2}'::::.          "
    " ${c1}         .::::      ::::      ${c2}'::::.         "
  ];
  makeColorCS = n: value: let
    positions = [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "A" "B" "C" "D" "E" "F" ];
  in "\\e]P${lib.elemAt positions (n - 1)}${value}";
in {
  options = {
    home.profiles.personal = lib.mkEnableOption "used as a day-to-day personal system";
  };

  config = mkIf config.home.profiles.personal {
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
      supportedLocales = [
        "ja_JP.UTF-8/UTF-8"
      ];
    };
    boot = {
      loader.timeout = 1;
      initrd.preLVMCommands = lib.mkAfter ''
        printf '\e[2J' >> /dev/console
      '';
      blacklistedKernelModules = ["pcspkr"];
      earlyVconsoleSetup = true;
      extraModprobeConfig = ''
        options snd_hda_intel power_save=1 power_save_controller=Y
        options kvm_amd avic=1
      '';
      kernel.sysctl = {
        "net.ipv6.conf.all.accept_ra_rt_info_max_plen" = 128;
        "net.ipv6.conf.default.accept_ra_rt_info_max_plen" = 128;
        "kernel.unprivileged_userns_clone" = 1;
      };
    };

    hardware.enableAllFirmware = true;

    systemd.network.links.b2b128 = {
      matchConfig = {
        MACAddress = "00:50:b6:14:85:e0";
      };

      linkConfig = {
        Description = "Belkin B2B128 USB Ethernet";
        Name = "ethb2b";
      };
    };

    services.mingetty = {
      greetingLine =
        lib.concatImapStrings makeColorCS config.i18n.consoleColors +
        ''\e[H\e[2J'' + # topleft
        ''\e[9;10]'' + # setterm blank/powersave = 10 minutes
        "\n" +
        lib.concatStringsSep "\n" nixos +
        "\n\n" +
        ''\e[1;32m>>> NixOS ${config.system.nixos.label} (Linux \r) - \l\e[0m'';
      helpLine = lib.mkForce "";
    };

    networking.firewall.enable = false;
    #networking.nftables.enable = true;
    # TODO: migrate nftables config

    # allow wheel to do things without password
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
    environment.systemPackages = with pkgs; [
      usbutils
      libimobiledevice
      hdparm
      smartmontools
      gptfdisk
      efibootmgr
      ntfs3g
      fuse
      config.boot.kernelPackages.cpupower
      gdb
      strace
    ];

    services.usbmuxd.enable = true;
    services.openssh = {
      forwardX11 = true;
      permitRootLogin = "yes"; # "prohibit-password"
    };
    services.locate = {
      enable = true;
      interval = "05:00";
    };
    services.resolved.enable = true;
    services.physlock.enable = true;
    security.sudo.extraRules = mkAfter [
      { commands = [ { command = "ALL"; options = ["NOPASSWD"]; } ]; groups = [ "wheel" ]; }
    ];
    systemd.services.dev-hugepages.wantedBy = ["sysinit.target"];
    systemd.services.dev-hugepages1G.wantedBy = ["sysinit.target"];
    systemd.mounts = [
      (hugepages { where = "/dev/hugepages"; options = "mode=0775"; })
      (hugepages { where = "/dev/hugepages1G"; options = "pagesize=1GB,mode=0775"; })
    ];
  };
}
