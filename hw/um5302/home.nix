{ nixosConfig, config, pkgs, lib, ... }: with lib; {
  key = "Zenbook S 13 OLED (UM5302)";

  config = {
    xsession.profileExtra = mkMerge [
      (mkIf nixosConfig.services.xserver.synaptics.enable ''
        ${pkgs.xorg.xf86inputsynaptics}/bin/syndaemon -K -d -m 100 -i 0.1
      '')
      ''
        xbacklight -set 15
      ''
    ];
    xsession.windowManager.i3.extraConfig = ''
      workspace 1 output eDP
      workspace 10 output DisplayPort-0 DisplayPort-1 DisplayPort-2 DisplayPort-3 DisplayPort-4 DisplayPort-5 DisplayPort-6
    '';
    services.polybar.settings = {
      "module/temp" = {
        interval = 2;
        hwmon_path = "/sys/devices/virtual/thermal/thermal_zone0/hwmon1"; # k10temp core
        warn-temperature = 60;
      };
      "module/battery" = {
        battery = "BATT";
        adapter = "ACAD";
      };
      "module/backlight" = {
        card = "amdgpu_bl0";
      };
    };

    # workaround for a bug where the backlight resets to a default level when waking from dpms
    systemd.user.services.dpms-standby = mkIf config.services.dpms-standby.enable {
      Service.ExecStop = [
        (with pkgs; writeShellScript "restore-backlight" ''
          ${getExe acpilight} -set $(${getExe acpilight} -get)
        '').outPath
      ];
    };
  };
}
