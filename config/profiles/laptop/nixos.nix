{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.laptop = mkEnableOption "a laptop";
  };

  config = mkIf config.home.profiles.laptop {
    hardware.bluetooth.enable = true;

    # TODO: fill in wireless.networks or iwd.networks instead of using connman?
    services.connman = {
      enable = true;
      enableVPN = false;
      wifi.backend = "iwd";
      extraFlags = ["--nodnsproxy"];
      extraConfig = ''
        AllowHostnameUpdates=false
        DefaultAutoConnectTechnologies=wifi
        PreferredTechnologies=wifi,bluetooth
        SingleConnectedTechnology=false
      '';
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

    systemd.services.net-suspend = {
      before = ["sleep.target"];
      unitConfig = {
        StopWhenUnneeded = "yes";
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          "${config.systemd.package}/bin/systemctl stop bluetooth"
          "${pkgs.connman}/bin/connmanctl disable wifi"
        ];
        ExecStop = [
          #"/usr/bin/systemctl start bluetooth"
          "${pkgs.connman}/bin/connmanctl enable wifi"
          "${pkgs.connman}/bin/connmanctl scan wifi"
        ];
      };
      wantedBy = ["sleep.target"];
    };
  };
}
