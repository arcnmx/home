{ pkgs, config, lib, ... }: with lib; let
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
  bluephone = pkgs.writeShellScriptBin "bluephone" ''
    ${pkgs.python3.withPackages (p: with p; [ dbus-python /*pygobject3*/ ])}/bin/python ${./files/bluephone.py} "$@"
  '';
in {
  imports = [ ./ddclient.nix ];

  options = {
    home.profiles.personal = lib.mkEnableOption "used as a day-to-day personal system";
  };

  config = mkIf config.home.profiles.personal {
    deploy.personal.enable = true;
    console = {
      packages = [pkgs.tamzen];
      font = "Tamzen7x14";
      earlySetup = true;
      getty = {
        greetingPrefix =
          ''\e[H\e[2J'' + # topleft
          ''\e[9;10]''; # setterm blank/powersave = 10 minutes
        greeting =
          "\n" +
          lib.concatStringsSep "\n" nixos +
          "\n\n" +
          ''\e[1;32m>>> NixOS ${config.system.nixos.label} (Linux \r) - \l\e[0m'';
      };
    };
    i18n.supportedLocales = [
      "ja_JP.UTF-8/UTF-8"
    ];
    services.getty = {
      helpLine = lib.mkForce "";
    };
    boot = {
      loader = {
        timeout = 1;
        systemd-boot.configurationLimit = 8;
      };
      initrd.preLVMCommands = lib.mkAfter ''
        printf '\e[2J' >> /dev/console
      '';
      blacklistedKernelModules = ["pcspkr"];
      modprobe.modules = {
        snd_hda_intel.options = {
          power_save = mkDefault true;
          power_save_controller = mkDefault "Y";
        };
        kvm_amd.options.avic = true;
      };
      kernel.sysctl = {
        "net.ipv6.conf.all.accept_ra_rt_info_max_plen" = 128;
        "net.ipv6.conf.default.accept_ra_rt_info_max_plen" = 128;
        "kernel.unprivileged_userns_clone" = 1;
        "kernel.sysrq" = 1;
      };
    };

    base16.console.enable = true;

    hardware.enableAllFirmware = true;

    systemd.network.links = {
      "10-b2b128" = {
        matchConfig = {
          MACAddress = "00:50:b6:14:85:e0";
        };

        linkConfig = {
          Description = "Belkin B2B128 USB Ethernet";
          Name = "ethb2b";
          NamePolicy = "";
        };
      };
    };

    networking = {
      firewall.enable = false;
      nameservers = mkDefault [ "1.1.1.1" "1.0.0.1" ];
      nftables = {
        enable = true;
        ruleset = mkMerge [
          (mkBefore (builtins.readFile ./files/nftables.conf))
          (mkIf config.services.yggdrasil.enable ''
            define yggdrasil_peer_listen_tcp = ${last (splitString ":" (head config.services.yggdrasil.listen))}
            ${builtins.readFile ./files/nftables-yggdrasil.conf}
          '')
        ];
      };
      interfaces.ethb2b = {
        useDHCP = true;
      };
    };

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
    ] ++ optional config.services.ofono.enable bluephone;

    services.udev.extraRules = let
      localGroup = "users";
      assignLocalGroup = ''GROUP="${localGroup}"'';
      devBoards = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="0483", ${assignLocalGroup}
        SUBSYSTEM=="usb", ATTR{idVendor}=="2047", ${assignLocalGroup}
        SUBSYSTEM=="usb", ATTR{idVendor}=="03eb", ${assignLocalGroup}
        SUBSYSTEM=="tty", ATTRS{interface}=="MSP Tools Driver", ${assignLocalGroup}
        SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic GDB Server", ${assignLocalGroup}, SYMLINK+="ttyBMP"
        SUBSYSTEM=="tty", ATTRS{interface}=="Black Magic UART Port", ${assignLocalGroup}, SYMLINK+="ttyBMPuart"
      '';
      i2c = ''
        SUBSYSTEM=="i2c-dev", ${assignLocalGroup}, MODE="0660"
      ''; # for DDC/monitor control
      inputs = ''
        # Gamepads
        SUBSYSTEM=="usb", ATTR{idVendor}=="1d79", ATTR{idProduct}=="0100", ${assignLocalGroup}
        SUBSYSTEM=="usb", ATTR{idVendor}=="0f0d", ATTR{idProduct}=="0083", ${assignLocalGroup}
        # Moonlander: https://github.com/zsa/wally/wiki/Live-training-on-Linux
        SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
      '';
      uinput = ''
        ACTION=="add", SUBSYSTEM=="input", DEVPATH=="/devices/virtual/input/*", MODE="0660", ${assignLocalGroup}
      '';
    in ''
      ${devBoards}
      ${i2c}
      ${inputs}
      ${uinput}
    '';
    services.udev.packages = [
      pkgs.android-udev-rules
    ];

    users = {
      users.arc.extraGroups = [ "uinput" "plugdev" "input" "adbusers" ];
      groups = {
        uinput = { };
        adbusers = { };
        plugdev = { };
      };
    };

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
    services.resolved = {
      enable = true;
      dnssec = "false";
    };
    services.physlock.enable = true;
    security.sudo.wheelNeedsPassword = false;
    systemd.mounts = let
      hugepages = { where, options }: {
        before = ["sysinit.target"];
        unitConfig = {
          DefaultDependencies = "no";
          ConditionPathExists = "/sys/kernel/mm/hugepages";
          ConditionCapability = "CAP_SYS_ADMIN";
          ConditionVirtualization = "!private-users";
        };
        what = "hugetlbfs";
        inherit where options;
        type = "hugetlbfs";
        mountConfig = {
          Group = "kvm";
        };
        wantedBy = ["sysinit.target"];
      };
    in [
      (hugepages { where = "/dev/hugepages"; options = "mode=0775"; })
      (hugepages { where = "/dev/hugepages1G"; options = "pagesize=1GB,mode=0775"; })
    ];
  };
}
