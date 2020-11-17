{ config, pkgs, lib, ... }: with lib; let
  patoggle = pkgs.writeShellScriptBin "patoggle" ''
    set -eu
    SINKS=(headphones speakers)

    DEFAULT_SINK=$(${pkgs.pulseaudio}/bin/pactl info | ${pkgs.gnugrep}/bin/grep Sink | ${pkgs.coreutils}/bin/cut -d ' ' -f 3)
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
    home.programs.paswitch.patoggle = mkOption {
      type = types.package;
      default = patoggle;
    };
  };

  config = mkMerge [ {
  } (mkIf config.home.profiles.host.shanghai {
    home.profiles.trusted = true;
    home.profiles.personal = true;
    home.profiles.gui = true;
    home.profiles.hw.nvidia = true;
    home.profiles.hw.x370gpc = true;

    xdg.configFile."i3status/config".source = ./files/i3status;

    home.packages = [ pkgs.paswitch config.home.programs.paswitch.patoggle ];
    services.konawall.tags = ["score:>=200" "width:>=1600" "rating:safe"];
    home.shell.functions = {
      _paswitch_sinks = ''
        ${pkgs.pulseaudio}/bin/pactl list short sinks | ${pkgs.coreutils}/bin/cut -d $'\t' -f 2
      '';
      _paswitch = ''
        _alternative 'preset:preset:(headphones speakers)' 'sink:sink:($(_paswitch_sinks))'
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
        workspace 2:2 output ${benq.output}
        workspace 3:3 output ${lg.output}

        workspace 11:F1 output ${dell.output}
        workspace 12:F2 output ${benq.output}
      '';
      config = {
        assigns = {
          "number 11:F1" = [
            { class = "^screenstub$"; instance = "Dell"; }
          ];
          "number 12:F2" = [
            { class = "^screenstub$"; instance = "BenQ"; }
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

    systemd.user.services.getquote = {
      Unit = {
        Description = "getquote";
      };
      Service = {
        Type = "simple";
        ExecStart = "${config.home.homeDirectory}/projects/gensokyo/ledger/update_prices";
      };
    };
  }) ];
}
