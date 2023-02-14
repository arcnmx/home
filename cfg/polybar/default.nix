{ base16, nixosConfig, config, pkgs, lib, ... } @ args: with lib; let
  enableOled = nixosConfig.hardware.display.oled != [ ];
in {
  services.polybar = {
    enable = true;
    script = let
      xrandr = filter: "${pkgs.xorg.xrandr}/bin/xrandr -q | ${pkgs.gnugrep}/bin/grep -F ' ${filter}' | ${pkgs.coreutils}/bin/cut -d' ' -f1";
      oled = ''
        export POLYBAR_OLED_SEP="$(printf "%$((RANDOM % 3 + 1))s")"
        export POLYBAR_OLED_MARGIN=$((RANDOM % 6))
        if [[ $((RANDOM % 2)) -eq 0 ]]; then
          export POLYBAR_OLED_BOOL_BOTTOM=true
        fi
        export POLYBAR_OLED_WM_MARGIN=$((RANDOM % 8))
        OLED_RAND=$RANDOM
        export POLYBAR_OLED_PADDING_LEFT=$((OLED_RANDOM % 12))
        export POLYBAR_OLED_PADDING_RIGHT=$((OLED_RANDOM % 12))
        OLED_RAND=$RANDOM
        export POLYBAR_OLED_BORDER_TOP=$((OLED_RANDOM % 4))
        export POLYBAR_OLED_BORDER_BOTTOM=$((OLED_RANDOM % 4))
        OLED_RAND=$RANDOM
        export POLYBAR_OLED_BORDER_LEFT=$((OLED_RANDOM % 4))
        export POLYBAR_OLED_BORDER_RIGHT=$((OLED_RANDOM % 4))
      '';
    in mkIf config.xsession.enable ''
      primary=$(${xrandr "connected primary"})
      for display in $(${xrandr "connected"}); do
        export POLYBAR_MONITOR=$display
        export POLYBAR_MONITOR_PRIMARY=$([[ $primary = $display ]] && echo true || echo false)
        export POLYBAR_TRAY_POSITION=$([[ $primary = $display ]] && echo right || echo none)
        POLYBAR_BAR=arc
        ${optionalString enableOled ''
          if echo ${escapeShellArg (toString nixosConfig.hardware.display.oled)} | ${pkgs.gnugrep}/bin/grep -w -q "$POLYBAR_MONITOR"; then
            POLYBAR_BAR=oled
            ${oled}
          fi
        ''}
        polybar $POLYBAR_BAR &
      done
    '';
    package = pkgs.polybarFull;
    config = {
      "bar/base" = {
        modules-left = mkIf config.xsession.windowManager.i3.enable (
          mkBefore [ "i3" ]
        );
        modules-center = mkMerge [
          (mkIf (nixosConfig.hardware.pulseaudio.enable or false || nixosConfig.services.pipewire.enable or false) (mkBefore [ "pulseaudio" "mic" ]))
          (mkIf config.services.playerctld.enable [ "sep" "mpris" ])
          (mkIf (config.programs.ncmpcpp.enable && !config.services.playerctld.enable) [ "sep" "mpd" ])
        ];
        modules-right = mkMerge [
          (mkBefore [ "fs-prefix" "fs-root" ])
          (mkOrder 990 [ "sep" ])
          (mkIf (nixosConfig.networking.wireless.enable or false || nixosConfig.networking.wireless.iwd.enable or false) [ "net-wlan" ])
          [ "net-ethb2b" ]
          (mkOrder 1240 [ "sep" ])
          (mkOrder 1250 [ "cpu" "temp" "ram" ])
          (mkOrder 1490 [ "sep" ])
          (mkAfter [ "utc" "date" ])
        ];
      };
    };
    settings = let
      colours = base16.map.hash.argb;
      warn-colour = colours.constant; # or deleted
    in with colours; {
      "bar/arc" = {
        "inherit" = "bar/base";
        monitor = {
          text = mkIf config.xsession.enable "\${env:POLYBAR_MONITOR:}";
        };
        enable-ipc = true;
        tray.position = "\${env:POLYBAR_TRAY_POSITION:right}";
        dpi = {
          x = 0;
          y = 0;
        };
        scroll = {
          up = "#i3.prev";
          down = "#i3.next";
        };
        font = [
          "monospace:size=${config.lib.gui.size 8 { }}"
          "Noto Mono:size=${config.lib.gui.size 8 { }}"
          "Symbola:size=${config.lib.gui.size 9 { }}"
        ];
        padding = {
          right = 1;
        };
        separator = {
          text = " ";
          foreground = foreground_status;
        };
        background = background_status;
        foreground = foreground_alt;
        border = {
          bottom = {
            size = 1;
            color = background_light;
          };
        };
        module-margin = 0;
        #click-right = ""; menu of some sort?
      };
      "bar/oled" = mkIf enableOled {
        "inherit" = "bar/arc";
        separator.text = "\${env:POLYBAR_OLED_SEP: }";
        module-margin = "\${env:POLYBAR_OLED_MARGIN:0}";
        bottom = "\${env:POLYBAR_OLED_BOOL_BOTTOM:false}";
        padding = {
          left = "\${env:POLYBAR_OLED_PADDING_LEFT:1}";
          right = "\${env:POLYBAR_OLED_PADDING_RIGHT:0}";
        };
        border = {
          left.size = "\${env:POLYBAR_OLED_BORDER_LEFT:0}";
          right.size = "\${env:POLYBAR_OLED_BORDER_RIGHT:0}";
          top.size = "\${env:POLYBAR_OLED_BORDER_TOP:0}";
          bottom.size = "\${env:POLYBAR_OLED_BORDER_BOTTOM:0}";
        };
      };
      "global/wm" = mkIf enableOled {
        margin = rec {
          bottom = "\${env:POLYBAR_OLED_WM_MARGIN:0}";
          top = bottom;
        };
      };
      "module/i3" = mkIf config.xsession.windowManager.i3.enable {
        type = "internal/i3";
        pin-workspaces = true;
        strip-wsnumbers = true;
        wrapping-scroll = false;
        enable-scroll = false; # handled by bar instead
        label = {
          mode = {
            padding = 2;
            foreground = constant;
            background = background_selection;
          };
          focused = {
            text = "%name%";
            padding = 1;
            foreground = attribute;
            background = background_light;
          };
          unfocused = {
            text = "%name%";
            padding = 1;
            foreground = comment;
            #background = background;
          };
          visible = {
            text = "%name%";
            padding = 1;
            foreground = foreground;
            #background = background;
          };
          urgent = {
            text = "%name%";
            padding = 1;
            foreground = foreground_status;
            background = link;
          };
          separator = {
            text = "|";
            foreground = foreground_status;
          };
        };
      };
      "module/sep" = {
        type = "custom/text";
        content = {
          text = "|";
          foreground = comment;
        };
      };
      "module/ram" = {
        type = "internal/memory";
        interval = 4;
        label = "%gb_used% %percentage_used%% ~ %gb_free%";
        warn-percentage = 90;
        format.warn.foreground = warn-colour;
      };
      "module/cpu" = {
        type = "internal/cpu";
        label = "🖥️ %percentage%%"; # 🧮
        interval = 2;
        warn-percentage = 90;
        format.warn.foreground = warn-colour;
      };
      "module/mpd" = let
        inherit (config.programs) mpc;
        default = mpc.servers.${mpc.defaultServer} or { enable = false; };
      in mkIf mpc.enable {
        type = "internal/mpd";

        host = mkIf default.enable default.connection.host;
        password = mkIf (default.enable && default.password != null) default.password;
        port = mkIf (default.enable && default.out.MPD_PORT != null) default.out.MPD_PORT;

        interval = 1;
        label-song = "♪ %artist% - %title%";
        format = {
          online = "<label-time> <label-song>";
          playing = "\${self.format-online}";
        };
      };
      "module/mpris" = mkIf config.services.playerctld.enable {
        type = "custom/script";
        format = "<label>";
        interval = 10;
        click-left = "${pkgs.playerctl}/bin/playerctl play-pause";
        exec = let
          lazy = pkgs.writeShellScript "polybar-mpris" ''
            ${pkgs.playerctl}/bin/playerctl \
              metadata \
              --format "{{ emoji(status) }} ~{{ duration(mpris:length) }} ♪ {{ artist }} - {{ title }}"
          '';
          mpris-tail = pkgs.fetchurl {
            url = "https://github.com/polybar/polybar-scripts/raw/a588bfc/polybar-scripts/player-mpris-tail/player-mpris-tail.py";
            sha256 = "sha256-FTbU8dzUUVVYHFHPWa9Pjgyb7Amvf0c8gNRpf87YuMM=";
          };
          python = pkgs.python3.withPackages (p: with p; [ dbus-python pygobject3 ]);
        in "${getExe python} ${mpris-tail} -f '{icon} ~{fmt-length} ♪ {artist} - {title}'";
        tail = true;
      };
      "module/net-ethb2b" = {
        type = "internal/network";
        interface = "ethb2b";
      };
      "module/pulseaudio" = {
        type = "internal/pulseaudio";
        use-ui-max = false;
        interval = 5;
        format.volume = "<ramp-volume> <label-volume>";
        ramp.volume = [ "🔈" "🔉" "🔊" ];
        label = {
          muted = {
            text = "🔇 muted";
            foreground = warn-colour;
          };
        };
      };
      "module/date" = {
        type = "internal/date";
        label = "%date%, %time%";
        format = "<label>";
        interval = 60;
        date = "%a %b %d";
        time = "%I:%M %p";
      };
      "module/utc" = {
        type = "custom/script";
        exec = "${pkgs.coreutils}/bin/date -u +%H:%M";
        format = "🕓 <label>Z";
        interval = 60;
      };
      "module/temp" = {
        type = "internal/temperature";

        interval = mkDefault 5;
        base-temperature = mkDefault 30;
        label = {
          text = "%temperature-c%";
          warn.foreground = warn-colour;
        };

        # $ for i in /sys/class/thermal/thermal_zone*; do echo "$i: $(<$i/type)"; done
        #thermal-zone = 0;

        # Full path of temperature sysfs path
        # Use `sensors` to find preferred temperature source, then run
        # $ for i in /sys/class/hwmon/hwmon*/temp*_input; do echo "$(<$(dirname $i)/name): $(cat ${i%_*}_label 2>/dev/null || echo $(basename ${i%_*})) $(readlink -f $i)"; done
        # Default reverts to thermal zone setting
        #hwmon-path = ?
      };
      "module/net-wlan" = {
        type = "internal/network";
        interface = mkIf (nixosConfig.networking.wireless.mainInterface.name or null != null) (mkDefault nixosConfig.networking.wireless.mainInterface.name);
        label = {
          connected = {
            text = "📶 %essid% %downspeed:9%";
            foreground = inserted;
          };
          disconnected = {
            text = "Disconnected.";
            foreground = warn-colour;
          };
        };
        format-packetloss = "<animation-packetloss> <label-connected>";
        animation-packetloss = [
          {
            text = "!"; # ⚠
            foreground = warn-colour;
          }
          {
            text = "📶";
            foreground = warn-colour;
          }
        ];
      };
      "module/net-wired" = {
        type = "internal/network";
        label = {
          connected = {
            text = "%ifname% %local_ip%";
            foreground = inserted;
          };
          disconnected = {
            text = "Unconnected.";
            foreground = warn-colour; # or deleted
          };
        };
        # TODO: formatting
      };
      "module/fs-prefix" = {
        type = "custom/text";
        content = {
          text = "💽";
        };
      };
      "module/fs-root" = {
        type = "internal/fs";
        mount = mkBefore [ "/" ];
        label-mounted = "%mountpoint% %free% %percentage_used%%";
        label-warn = "%mountpoint% %{F${warn-colour}}%free% %percentage_used%%%{F-}";
        label-unmounted = "";
        warn-percentage = 90;
        spacing = 1;
      };
      "module/mic" = {
        type = "custom/ipc";
        format = "🎤 <output>";
        initial = 1;
        click.left = "${nixosConfig.hardware.pulseaudio.package or pkgs.pulseaudio}/bin/pactl set-source-mute @DEFAULT_SOURCE@ toggle && ${config.services.polybar.package}/bin/polybar-msg hook mic 1";
        # check if pa default-source is muted, if so, show warning!
        # also we trigger an immediate refresh when hitting the keybind
        hook = let
          pamixer = "${pkgs.pamixer}/bin/pamixer --default-source";
          script = pkgs.writeShellScript "checkmute" ''
            set -eu

            MUTE=$(${pamixer} --get-mute || true)
            if [[ $MUTE = true ]]; then
              echo muted
            else
              echo "$(${pamixer} --get-volume)%"
            fi
          '';
        in singleton "${script}";
      };
    };
  };
}
