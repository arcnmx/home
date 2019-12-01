{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.laptop = mkEnableOption "a laptop";
  };

  config = mkIf config.home.profiles.laptop {
    hardware.bluetooth.enable = true;

    networking = {
      wireless = {
        enable = true;
        networks = {
          # TODO: fill in this instead of using connman
          dummy = {}; # XXX: force nixos to write out wpa_supplicant.conf, otherwise connman won't work
        };
      };
    };
    services.connman = {
      enable = true;
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

    boot.extraModulePackages = [ config.boot.kernelPackages.ax88179_178a ];

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
          "${pkgs.systemd}/bin/systemctl stop bluetooth"
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
