{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.x570am = mkEnableOption "GIGABYTE X570 Aorus Master";
  };

  config = mkIf config.home.profiles.hw.x570am {
    home.profiles.hw.ryzen = true;

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
