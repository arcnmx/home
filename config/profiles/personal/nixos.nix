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
  in "\\e]P${lib.toHexUpper n}${value}";
in {
  options = {
    home.profiles.personal = lib.mkEnableOption "used as a day-to-day personal system";
  };

  config = mkIf config.home.profiles.personal {
    i18n = {
      consolePackages = [pkgs.tamzen];
      consoleFont = "Tamzen7x14";
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

    base16.console.enable = true;

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
      greetingPrefix =
        ''\e[H\e[2J'' + # topleft
        ''\e[9;10]''; # setterm blank/powersave = 10 minutes
      greeting =
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
      strace
    ];

    services.udev.extraRules = let
      localGroup = "users";
      assignLocalGroup = ''GROUP="${localGroup}"'';
      devBoards = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ${assignLocalGroup}"
        SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic GDB Server", ${assignLocalGroup}, SYMLINK+="ttyBMP"
        SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic UART Port", ${assignLocalGroup}, SYMLINK+="ttyBMPuart"
      '';
      i2c = ''
        SUBSYSTEM=="i2c-dev", ${assignLocalGroup}, MODE="0660"
      ''; # for DDC/monitor control
      gamepads = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="1d79", ATTR{idProduct}=="0100", ${assignLocalGroup}
        SUBSYSTEM=="usb", ATTR{idVendor}=="0f0d", ATTR{idProduct}=="0083", ${assignLocalGroup}
      '';
      uinput = ''
        ACTION=="add", SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", ${assignLocalGroup}
        ACTION=="add", SUBSYSTEM=="input", DEVPATH=="/devices/virtual/input/*", MODE="0666", ${assignLocalGroup}
      '';
    in ''
      ${devBoards}
      ${i2c}
      ${gamepads}
      ${uinput}
    '';

    services.usbmuxd.enable = true;
    services.openssh = {
      passwordAuthentication = true;
      startWhenNeeded = true;
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
