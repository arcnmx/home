{ config, pkgs, lib, ... }: with lib; let
  pulseaudio = config.home.nixosConfig.hardware.pulseaudio.package or pkgs.pulseaudio;
  pactl = "${pulseaudio}/bin/pactl";
  patoggle = pkgs.writeShellScriptBin "patoggle" ''
    set -eu
    SINKS=(${concatStringsSep " " config.home.programs.paswitch.sinks})

    DEFAULT_SINK=$(${pactl} info | ${pkgs.gnugrep}/bin/grep Sink | ${pkgs.coreutils}/bin/cut -d ' ' -f 3)
    SINK_INDEX=0
    for sink in "''${SINKS[@]}"; do
      ((++SINK_INDEX))
      if [[ $sink == $DEFAULT_SINK ]]; then
        break
      fi
    done
    SINK_INDEX=$((SINK_INDEX % ''${#SINKS[@]}))

    exec ${pkgs.paswitch}/bin/paswitch ''${SINKS[$SINK_INDEX]}
  '';
in {
  options = {
    home.profiles.host.shanghai = mkEnableOption "hostname: shanghai";
    home.programs.paswitch = {
      sinks = mkOption {
        type = types.listOf types.str;
        default = [ "headphones" "speakers" ];
      };
      patoggle = mkOption {
        type = types.package;
        default = patoggle;
      };
    };
  };

  imports = [ ./screenstub.nix ];

  config = mkIf config.home.profiles.host.shanghai {
    home.profiles.trusted = true;
    home.profiles.personal = true;
    home.profiles.gui = true;
    home.profiles.hw.nvidia = true;
    home.profiles.hw.x570am = true;

    xdg.configFile."i3status/config".source = ./files/i3status;

    home.packages = [
      pkgs.paswitch
      config.home.programs.paswitch.patoggle
    ];
    services.konawall = {
      commonTags = [ "width:>=1600" ];
      tags = [ "score:>=200" "rating:safe" ];
    };
    services.polybar.settings = {
      "module/fs-root" = {
        mount = mkAfter [ "/mnt/enc" "/nix" "/mnt/data" ];
      };
    };
    services.dunst.iconTheme.size = "64x64";
    home.shell.functions = {
      _paswitch_sinks = ''
        ${pactl} list short sinks | ${pkgs.coreutils}/bin/cut -d $'\t' -f 2
      '';
      _paswitch = ''
        _alternative 'preset:preset:(headphones speakers)' 'sink:sink:($(_paswitch_sinks))'
      '';
      ryzen-watch = ''
        sudo watch -ctn1 'ryzen_monitor -u0'
      '';
    };
    programs.zsh.initExtra = ''
      compdef _paswitch paswitch
    '';
    hardware.display = mapAttrs (k: v: {
      nvidia.enable = mkDefault config.home.nixosConfig.hardware.display.nvidia.enable;
      monitors = v config.hardware.display.${k}.monitors;
    }) (import ./displays.nix { inherit lib; }).monitors;
    xsession.windowManager.i3 = with config.home.nixosConfig.hardware.display.monitors; {
      extraConfig = ''
        workspace 1:1 output ${dell.output}
        workspace 2:2 output ${spectrum.output}
        workspace 3:3 output ${lg.output}

        workspace 11:F1 output ${dell.output}
        workspace 12:F2 output ${spectrum.output}
      '';
      config = {
        assigns = {
          "number 11:F1" = [
            { class = "^screenstub$"; instance = "Dell"; }
          ];
          "number 12:F2" = [
            { class = "^screenstub$"; instance = "Spectrum"; }
          ];
        };
      };
    };
    services.mpd = {
      extraConfig = ''
        samplerate_converter "1"

        audio_output {
          type "httpd"
          name "httpd-high"
          encoder "opus"
          bitrate "96000"
          port "32101"
          max_clients "4"
          format "48000:16:2"
          always_on "yes"
          tags "yes"
        }

        audio_output {
          type "httpd"
          name "httpd-low"
          encoder "opus"
          bitrate "58000"
          port "32102"
          max_clients "4"
          format "48000:16:2"
          always_on "yes"
          tags "yes"
        }
      '';
    };
    programs.mpv = {
      config = {
        # may as well use the excess RAM for something
        demuxer-max-bytes = "2000MiB";
        demuxer-max-back-bytes = "250MiB";
      };
    };
  };
}
