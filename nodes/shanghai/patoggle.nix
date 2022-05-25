{ config, pkgs, lib, nixosConfig, ... }: with lib; let
  pactl = "${nixosConfig.hardware.pulseaudio.package}/bin/pactl";
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

  config = {
    home.packages = [
      config.home.programs.paswitch.patoggle
    ];
  };
}
