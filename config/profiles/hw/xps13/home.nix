{ config, pkgs, lib, ... }: with lib; {
  options = {
    home.profiles.hw.xps13 = mkEnableOption "Dell XPS 13 (9343)";
  };

  config = mkIf config.home.profiles.hw.xps13 {
    home.profiles.hw.intel = true;
    home.profiles.laptop = true;
    home.profiles.personal = true;

    xsession.profileExtra = ''
      ${pkgs.xorg.xf86inputsynaptics}/bin/syndaemon -K -d -m 100 -i 0.1
    '';
    xsession.windowManager.i3.extraConfig = ''
      workspace 1 output eDP1
      workspace 0 output HDMI1 DP1
    '';
    services.polybar.settings = {
      "module/temp" = {
        interval = 2;
        hwmon_path = "/sys/devices/platform/coretemp.0/hwmon/hwmon5/temp1_input"; # coretemp package
        warn-temperature = 60;
      };
      "module/net-wlan" = {
        interface = "wlan0";
      };
    };
  };
}
