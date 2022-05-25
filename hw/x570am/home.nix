{ config, pkgs, lib, ... }: with lib; {
  config = {
    services.polybar = {
      config = {
        "bar/base" = {
          modules-right = [ "net-eth" "net-eth25" ];
        };
      };
      settings = {
        "module/temp" = {
          interval = 2;
          hwmon-path = "/sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon7/temp1_input"; # Tctl
          warn-temperature = 75;
        };
        "module/net-eth" = {
          "inherit" = "module/net-wired";
          type = "internal/network";
          interface = "eth";
        };
        "module/net-eth25" = {
          "inherit" = "module/net-wired";
          type = "internal/network";
          interface = "eth25";
        };
      };
    };
  };
}
