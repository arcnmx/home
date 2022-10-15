{ config, pkgs, lib, ... }: with lib; {
  config = {
    home-manager.users.arc.imports = [ ./home.nix ];
    hardware.bluetooth.enable = true;
    hardware.display.dpms.standbyMinutes = mkDefault 5;

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
        };
      };
    };
  };
}
