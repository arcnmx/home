{ config, pkgs, lib, ... }: with lib; {
  options.home = {
    profiles.host.satorin = mkEnableOption "hostname: satorin";
  };

  config = mkMerge [
    {
      keychain.keys.satorin-ssh = {
        public = ./files/id_rsa.pub;
      };
    }
    (mkIf config.home.profiles.host.satorin {
      home.profiles.trusted = true;
      home.profiles.gui = true;
      home.profiles.hw.xps13 = true;

      xdg.configFile = {
        "i3status/config".source = ./files/i3status;
        /*"sway/satorin.conf".text = ''
          output eDP-1 resolution 1920x1080 position 1920,0
          output HDMI-A-1 resolution 1920x1080 position 0,0
          #  HDMI-A-1 resolution 1920x1080 position 1920,0

          # man 5 sway-input
          # swaymsg -t get_inputs
          input "1739:30381:DLL0665:01_06CB:76AD_To" {
              dwt enabled
              tap enabled
              natural_scroll enabled
              scroll_method two_finger
              accel_profile adaptive
              click_method clickfinger
              drag_lock enabled
              pointer_accel 0.1
          }
        '';*/
      };
    })
  ];
}
