{ tf, inputs, pkgs, options, config, lib, ... }: with lib; let
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
  inherit (config.networking.firewall) free;
in {
  imports = [
    ./remote-user.nix
    ./ddclient.nix
    ./wlan.nix
    ../nftables
    ../tailscale
    ../task
    ../mpd
    ../ssh/personal.nix
  ];

  config = {
    home-manager.users.arc.imports = [ ./home.nix ];
    home.profileSettings.base.defaultNameservers = true;
    home.os.enable = mkDefault true;

    deploy.personal.enable = true;
    deploy.tf.variables = {
      CRATES_TOKEN_ARC.bitw.name = "crates-arcnmx";
      SYSTEMD2MQTT_PASSWORD = mkIf config.services.systemd2mqtt.enable {
        bitw.name = "mqtt-systemd2mqtt";
      };
    };
    console = {
      packages = [pkgs.tamzen];
      font = "Tamzen7x14";
      earlySetup = true;
      getty = {
        greetingPrefix = let
          dpms = config.hardware.display.dpms or { };
        in ''\e[H\e[2J'' # topleft
        + optionalString dpms.enable or true ''\e[9;${toString dpms.standbyMinutes or 10}]''; # setterm blank/powersave
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

    hardware.xpadneo.enable = true;
    hardware.enableAllFirmware = true;

    systemd.network.wait-online = {
      enable = mkIf config.services.connman.enable (mkDefault false);
      anyInterface = mkDefault true;
    };
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
      firewall = mkMerge [ {
        free.enable = mkDefault true;
        allowedTCPPorts = [
          5201 # iperf
          5000 # mkchromecast
          1137 # riifs
        ];
        allowedUDPPorts = [
          4010 # scream
          1137 # riifs
          5353 # mkchromecast
        ];
        allowedUDPPortRanges = [
          { from = 32768; to = 61000; } # mkchromecast
        ];
      } (mkIf (free.enable && free.base != null) {
        allowedTCPPortRanges = [
          rec { from = free.base + free.offset; to = from + free.size; }
        ];
        allowedUDPPortRanges = [
          rec { from = free.base + free.offset; to = from + free.size; }
        ];
      }) ];
      interfaces.ethb2b = {
        useDHCP = true;
      };
      wireless.iwd.settings = {
        Network.EnableIPv6 = mkDefault true;
        Rank.BandModifier5Ghz = mkDefault 1.25;
        Scan = {
          InitialPeriodicScanInterval = mkDefault 4;
          MaximumPeriodicScanInterval = mkDefault 180;
        };
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
    security.rtkit.enable = true;
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

    services.${if options ? services.dpms-standby then "dpms-standby" else null} = {
      enable = mkIf config.services.xserver.enable (mkDefault true);
      user = mkIf config.services.xserver.displayManager.startx.enable (mkDefault "arc");
    };
    security.polkit.users."" = mkIf config.services.dpms-standby.enable or false {
      systemd.units = singleton "dpms-standby.service";
    };

    services.systemd2mqtt = mkIf tf.state.enable {
      mqtt.secretPassword = mkIf config.services.systemd2mqtt.enable tf.variables.SYSTEMD2MQTT_PASSWORD.ref;
    };

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
        SUBSYSTEM=="usb", ATTR{idVendor}=="1d79", ATTR{idProduct}=="0100", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="0f0d", ATTR{idProduct}=="0083", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="0b12", GROUP="plugdev"
        # Moonlander: https://github.com/zsa/wally/wiki/Live-training-on-Linux
        SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
        # GMMK
        SUBSYSTEM=="usb", ATTR{idVendor}=="0c45", ATTR{idProduct}=="652f", GROUP="plugdev"
        # Naga
        SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="0067", GROUP="plugdev"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="0040", GROUP="plugdev"
      '';
      uinput = ''
        ACTION=="add", SUBSYSTEM=="input", DEVPATH=="/devices/virtual/input/*", MODE="0660", ${assignLocalGroup}
      '';
      uvc = ''
        SUBSYSTEM=="usb", ATTR{idVendor}=="0c45", ATTRS{idProduct}=="6366", GROUP="video"
        SUBSYSTEM=="usb", ATTR{idVendor}=="1d6c", GROUP="video"
        KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTR{index}=="0", ATTRS{idVendor}=="0c45", ATTRS{idProduct}=="6366", ATTRS{product}=="USB Live camera", SYMLINK+="video-hd682h", TAG+="systemd"
        KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTR{index}=="0", ATTRS{idVendor}=="0c45", ATTRS{idProduct}=="6366", ATTRS{product}=="USB  Live camera", SYMLINK+="video-hd826", TAG+="systemd"
        KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", SUBSYSTEMS=="usb", ATTR{index}=="0", ATTRS{idVendor}=="1d6c", ATTRS{idProduct}=="1278", ATTRS{manufacturer}=="YGTek", ATTRS{product}=="Webcam", ATTRS{serial}=="YG_U600D.4653_4K.2103121705", SYMLINK+="video-yg4k", TAG+="systemd"
        KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", ATTR{name}=="OBS Virtual Camera", SYMLINK+="video-obs", TAG+="systemd"
      '';
    in ''
      ${devBoards}
      ${i2c}
      ${inputs}
      ${uinput}
      ${uvc}
    '';
    services.udev.packages = [
      pkgs.android-udev-rules
    ];

    users = {
      users.arc = {
        extraGroups = [ "uinput" "plugdev" "input" "adbusers" ];
        systemd.translate.system.enable = mkDefault true;
      };
      groups = {
        uinput = { };
        adbusers = { };
        plugdev = { };
      };
    };

    services.usbmuxd.enable = true;
    services.openssh = {
      startWhenNeeded = true;
      forwardX11 = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "yes"; # "prohibit-password"
      };
    };
    services.tailscale = {
      trust = mkDefault true;
    };
    services.kanidm = {
      clientSettings = {
        verify_ca = mkDefault true;
        verify_hostnames = mkDefault true;
      };
    };
    services.locate = {
      enable = mkDefault true;
      locate = mkDefault pkgs.mlocate;
      interval = mkDefault "05:00";
      localuser = mkDefault null; # for `mlocate`
    };
    services.resolved = {
      enable = true;
      dnssec = "false";
    };
    services.wireplumber = {
      logLevel = mkDefault 3;
      policy.roles.enable = mkDefault true;
      service.moduleDir = let
        wireplumber-scripts-arc = pkgs.callPackage (inputs.wireplumber-scripts.outPath + "/derivation.nix") { };
        modules = pkgs.symlinkJoin {
          name = "wireplumber-modules";
          paths = [ pkgs.wireplumber wireplumber-scripts-arc ];
        };
      in "${modules}/lib/wireplumber-${versions.majorMinor pkgs.wireplumber.version}";
    };
    services.physlock.enable = true;
    security.sudo.wheelNeedsPassword = false;
    systemd.services = {
      nix-daemon.serviceConfig.OOMScoreAdjust = -100;
    };
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
