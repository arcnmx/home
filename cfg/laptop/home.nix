{ base16, config, pkgs, lib, ... } @ args: with lib; {
  config = {
    home.shell.functions = {
      bluenet = ''
        ${config.systemd.package}/bin/systemctl start bluetooth
        ${pkgs.connman}/bin/connmanctl enable bluetooth
        ${pkgs.connman}/bin/connmanctl disable wifi
        ${config.systemd.package}/bin/systemctl restart connman
      '';
      iosnet = ''
        ${config.systemd.package}/bin/systemctl restart usbmuxd
        ${pkgs.connman}/bin/connmanctl disable wifi
        ${pkgs.connman}/bin/connmanctl disable bluetooth
        sleep 2.5
        ${pkgs.connman}/bin/connmanctl connect ethernet_629316761e6d_cable
      '';
      winet = ''
        ${pkgs.connman}/bin/connmanctl disable bluetooth
        ${pkgs.connman}/bin/connmanctl enable wifi
        ${pkgs.connman}/bin/connmanctl scan wifi
      '';
    };

    programs.starship.settings.battery = with base16.map.ansiStr; {
      disabled = false;
      # https://starship.rs/config/#battery
      # TODO: colour percentage based on charge status
      # use fg:${inserted} when charging, fg:${constant} when discharging (to be consistent with polybar
      display = [
        {
          threshold = 100;
          style = "fg:${inserted}";
        }
        {
          threshold = 90;
          style = "fg:${constant}";
        }
        {
          threshold = 20;
          style = "bold fg:${deleted}";
        }
      ];
    };
    services.polybar = {
      config = {
        "bar/base" = {
          modules-right = mkMerge [
            (mkOrder 490 [ "backlight" ])
            (mkOrder 1248 [ "battery" ])
          ];
        };
      };
      settings = with base16.map.hash.argb; {
        "module/backlight" = {
          type = "internal/backlight";
          card = mkDefault "intel_backlight"; # /sys/class/backlight/
          enable-scroll = true;
          format = "<ramp> <label>";
          ramp = [
            "🌕"
            "🌔"
            "🌓"
            "🌒"
            "🌑"
          ];
        };
        "module/battery" = {
          type = "internal/battery";
          battery = mkDefault "BAT0"; # ls /sys/class/power_supply/
          adapter = mkDefault "AC";
          poll-interval = 60;
          time-format = "%H:%M";
          label = {
            charging = {
              text = "⚡ %consumption%/%percentage%% %time%";
              foreground = inserted;
            };
            discharging = {
              text = "🔋 %consumption%/%percentage%% %time%";
              foreground = constant;
            };
            full = {
              text = "🔌 100%";
            };
          };
          low-at = 20;
          format.low.foreground = deleted;
        };
      };
    };
    xsession.windowManager.i3.config.keybindings = let
      xbacklight = "${pkgs.acpilight}/bin/xbacklight"; # pkgs.xorg.xbacklight
    in {
      "XF86MonBrightnessUp" = "exec --no-startup-id ${xbacklight} -inc 10";
      "XF86MonBrightnessDown" = "exec --no-startup-id ${xbacklight} -dec 10";
    };
  };
}
