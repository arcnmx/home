{ config, pkgs, lib, ... }: with lib; {
  config = {
    home-manager.users.arc.imports = [ ./home.nix ];
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = mkDefault false;
    };
    hardware.display.dpms.standbyMinutes = mkDefault 5;
    networking.wireless.mainInterface.isMain = mkDefault true;

    # TODO: fill in wireless.networks or iwd.networks instead of using connman?
    services.connman = {
      enable = mkDefault true;
      enableVPN = false;
      wifi.backend = mkDefault "iwd";
      extraFlags = ["--nodnsproxy"];
      extraConfig = ''
        AllowHostnameUpdates=false
        DefaultAutoConnectTechnologies=wifi
        PreferredTechnologies=wifi,bluetooth
        SingleConnectedTechnology=false
      '';
    };
    networking.wireless.iwd.settings = {
      General = {
        RoamThreshold = -60;
        RoamThreshold5G = -86;
        RoamRetryInterval = 30;
      };
      Rank = {
        BandModifier5Ghz = 1.75;
      };
    };

    services.xserver = {
      synaptics = mapAttrs (_: mkDefault) {
        enable = !config.services.xserver.libinput.enable;
        accelFactor = "0.275";
        minSpeed = "0.30";
        maxSpeed = "1.30";
        palmDetect = true;
        palmMinWidth = 8;
        palmMinZ = 100;
        twoFingerScroll = true;
        scrollDelta = -40;
        tapButtons = true;
        fingersMap = [1 3 2];

        # Sets up soft buttons at the bottom
        # First 40% - Left Button
        # Middle 20% - Middle Button
        # Right 40% - Right Button
        additionalOptions = ''
          Option "ClickPad" "true"
          Option "SoftButtonAreas" "60% 0 82% 0 40% 59% 82% 0"
        '';
      };
      libinput.touchpad = mapAttrs (_: mkDefault) {
        accelSpeed = config.services.xserver.synaptics.accelFactor;
        naturalScrolling = true;
        tappingDragLock = false; # XXX: timeout is too long and is not configurable
        clickMethod = "buttonareas";
      };
    };

    boot.kernel.sysctl = {
      "vm.swappiness" = 1;
      "vm.vfs_cache_pressure" = 50;
      "kernel.nmi_watchdog" = 0;
      "vm.laptop_mode" = 5;
    };

    environment.systemPackages = with pkgs; [
      acpi
      acpilight
      wirelesstools
      bluez
    ];

    services.tlp.enable = true;

    services.udev.extraRules = ''
      SUBSYSTEM=="backlight", ACTION=="add", \
        RUN+="${pkgs.coreutils}/bin/chgrp users %S%p/brightness", \
        RUN+="${pkgs.coreutils}/bin/chmod g+w %S%p/brightness"
    '';

    systemd.network.wait-online.anyInterface = true;
    systemd.services = {
      net-suspend = rec {
        description = "stop wifi+bluetooth before sleep";
        wantedBy = [ "sleep.target" ];
        before = wantedBy;
        conflicts = [ "bluetooth.service" ];
        unitConfig.StopWhenUnneeded = true;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = mkMerge [
            [ "${pkgs.coreutils}/bin/true" ]
            (mkIf config.services.connman.enable [
              "${pkgs.connman}/bin/connmanctl disable wifi"
            ])
          ];
          ExecStop = mkIf config.services.connman.enable [
            "${pkgs.connman}/bin/connmanctl enable wifi"
            "${pkgs.connman}/bin/connmanctl scan wifi"
          ];
          TimeoutSec = 30;
        };
      };
      bt-shutdown = rec {
        enable = config.hardware.bluetooth.enable;
        description = "block bluetooth on shutdown";
        wantedBy = mkMerge [
          [ "network.target" ]
          (mkIf config.services.connman.enable [ "connman.service" ])
        ];
        bindsTo = wantedBy;
        after = wantedBy;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = [
            "${pkgs.coreutils}/bin/true"
          ];
          ExecStop = mkMerge [
            (mkIf config.services.connman.enable [
              "${pkgs.connman}/bin/connmanctl disable bluetooth"
            ])
            (mkDefault [
              "${pkgs.util-linux}/bin/rfkill block bluetooth"
            ])
          ];
          TimeoutSec = 10;
        };
      };
    };
  };
}
