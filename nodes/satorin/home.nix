{ config, pkgs, lib, ... }: with lib; {
  config = {
      xdg.configFile = {
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
  };
}
