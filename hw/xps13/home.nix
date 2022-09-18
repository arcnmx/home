{ nixosConfig, config, pkgs, lib, ... }: with lib; {
  key = "Dell XPS 13 (9343)";

  config = {
    xsession.profileExtra = mkIf nixosConfig.services.xserver.synaptics.enable ''
      ${pkgs.xorg.xf86inputsynaptics}/bin/syndaemon -K -d -m 100 -i 0.1
    '';
    xsession.windowManager.i3.extraConfig = ''
      workspace 1 output eDP1
      workspace 10 output HDMI1 DP1
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
