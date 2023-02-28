{ base16, nixosConfig, config, pkgs, lib, ... } @ args: with lib; {
  config = {
    home.shell.functions = {
      bluenet = mkIf nixosConfig.hardware.bluetooth.enable (''
        systemctl start bluetooth
      '' + (if nixosConfig.services.connman.enable then ''
        connmanctl enable bluetooth
        connmanctl disable wifi
        systemctl restart connman
      '' else ''
        rfkill unblock bluetooth
        rfkill block wlan
      ''));
      iosnet = mkIf nixosConfig.services.usbmuxd.enable (''
        systemctl restart usbmuxd
      '' + (if nixosConfig.services.connman.enable then ''
        connmanctl disable wifi
        connmanctl disable bluetooth
      '' else ''
        rfkill block wlan
        rfkill block bluetooth
      '') + ''
        sleep 2.5
        connmanctl connect ethernet_629316761e6d_cable
      '');
      winet = if nixosConfig.services.connman.enable then ''
        connmanctl disable bluetooth
        connmanctl enable wifi
        connmanctl scan wifi
      '' else ''
        rfkill block bluetooth
        rfkill unblock wlan
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
    xsession.windowManager.i3.config.keybindings = {
      "XF86MonBrightnessUp" = "exec --no-startup-id xbacklight -inc 10";
      "XF86MonBrightnessDown" = "exec --no-startup-id xbacklight -dec 10";
    };
  };
}
