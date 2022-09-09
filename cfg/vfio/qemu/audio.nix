{ nixosConfig, config, lib, ... }: with lib; let
    cfg = config.audio;
    hda = "ich9-intel-hda";
    ac97 = "AC97";
in {
  options.audio = {
    enable = mkEnableOption "sound";
    driver = mkOption {
      type = types.enum [ ac97 hda ];
      default = hda;
    };
    backend = mkOption {
      type = types.enum [ "alsa" "pa" ];
      default = if nixosConfig.hardware.pulseaudio.enable || nixosConfig.services.pipewire.enable then "pa" else "alsa";
    };
    pulseaudio = mkOption {
      type = with types; attrsOf unspecified;
      default = { };
    };
    alsa = mkOption {
      type = with types; attrsOf unspecified;
      default = { };
    };
  };
  config = mkIf cfg.enable {
    audiodevs.audio0.settings = mkMerge [
      {
        inherit (cfg) backend;
      }
      (mkIf (cfg.backend == "alsa") cfg.alsa)
      (mkIf (cfg.backend == "pa") cfg.pulseaudio)
    ];
    pci.devices.sound0 = {
      device.cli.dependsOn = mkIf (cfg.driver == ac97) [ config.audiodevs.audio0.id ];
      settings = {
        driver = cfg.driver;
        audiodev = mkIf (cfg.driver == ac97) config.audiodevs.audio0.id;
      };
    };
    devices.mic0 = mkIf (cfg.driver == hda) {
      cli.dependsOn = [
        config.devices.sound0.id
        config.audiodevs.audio0.id
      ];
      settings = {
        driver = "hda-micro";
        audiodev = config.audiodevs.audio0.id;
      };
    };
    exec.scriptText = mkIf (cfg.backend == "pa" && cfg.pulseaudio.server or null == null) ''
      if [ -z "''${PULSE_SERVER-}" ] && [ -z "''${DISPLAY-}" ]; then
        PULSE_SERVER=/run/user/$(id -u)/pulse/native
        if [ -e "$PULSE_SERVER" ]; then
          export PULSE_SERVER=unix:$PULSE_SERVER
          PULSE_COOKIE=$HOME/.config/pulse/cookie
          if [ -e "$PULSE_COOKIE" ]; then
            export PULSE_COOKIE
          else
            unset PULSE_COOKIE
          fi
          if ! timeout 2 ${nixosConfig.hardware.pulseaudio.package}/bin/pactl info 2> /dev/null >&2; then
            echo "pulse not running" >&2
            unset PULSE_SERVER PULSE_COOKIE
          fi
        else
          unset PULSE_SERVER
        fi
      fi
    '';
  };
}
