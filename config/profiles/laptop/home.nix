{ config, pkgs, lib, ... } @ args: with lib; {
  options = {
    home.profiles.laptop = mkEnableOption "a laptop";
  };

  config = mkIf config.home.profiles.laptop {
    home.shell.functions = {
      bluenet = ''
        ${pkgs.systemd}/bin/systemctl start bluetooth
        ${pkgs.connman}/bin/connmanctl enable bluetooth
        ${pkgs.connman}/bin/connmanctl disable wifi
        ${pkgs.systemd}/bin/systemctl restart connman
      '';
      iosnet = ''
        ${pkgs.systemd}/bin/systemctl restart usbmuxd
        ${pkgs.connman}/bin/connmanctl disable wifi
        ${pkgs.connman}/bin/connmanctl disable bluetooth
        sleep 2.5
        ${pkgs.connman}/bin/connmanctl connect ethernet_f2796070f331_cable
      '';
      winet = ''
        ${pkgs.connman}/bin/connmanctl disable bluetooth
        ${pkgs.connman}/bin/connmanctl enable wifi
        ${pkgs.connman}/bin/connmanctl scan wifi
      '';
    };

    xsession.windowManager.i3.config.keybindings = let
      xbacklight = "${pkgs.acpilight}/bin/xbacklight"; # pkgs.xorg.xbacklight
    in {
      "XF86MonBrightnessUp" = "exec --no-startup-id ${xbacklight} -inc 10";
      "XF86MonBrightnessDown" = "exec --no-startup-id ${xbacklight} -dec 10";
    };
  };
}
