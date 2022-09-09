{ nixosConfig, config, lib, pkgs, ... }: with lib; let
  cfg = config.scream;
  defaults = {
    port = 4010;
    multicast = "239.255.77.77";
  };
in {
  options.scream = {
    enable = mkEnableOption "scream";
    mode = mkOption {
      type = types.enum [ "ip" "ivshmem" ];
      default = "ip";
    };
    ip = {
      mode = mkOption {
        type = types.enum [ "multicast" "unicast" ];
        default = "multicast";
      };
      port = mkOption {
        type = types.port;
        default = defaults.port;
      };
      multicast.address = mkOption {
        type = types.str;
        default = defaults.multicast;
      };
      unicast.address = mkOption {
        type = with types; nullOr str;
        default = null;
      };
    };
    ivshmem = {
      path = mkOption {
        type = types.path;
        default = config.state.runtimePath + "/scream";
      };
      sizeMB = mkOption {
        type = types.int;
        default = 2;
      };
    };
    playback = {
      backend = mkOption {
        type = types.enum [ "pulse" "alsa" "jack" "raw" ];
        default = "pulse";
      };
      interface = mkOption {
        type = with types; nullOr str;
        default = null;
      };
      latency = {
        target = mkOption {
          type = with types; nullOr int;
          default = null;
        };
        max = mkOption {
          type = with types; nullOr int;
          default = null;
        };
      };
      package = mkOption {
        type = types.package;
        default = pkgs.scream;
      };
      cli = {
        command = mkOption {
          type = types.str;
        };
        extraArgs = mkOption {
          type = with types; listOf str;
          default = [ ];
        };
      };
    };
  };
  config = mkMerge [
    (mkIf cfg.enable {
      ivshmem.devices.scream = mkIf (cfg.mode == "ivshmem") {
        inherit (cfg.ivshmem) sizeMB path;
      };
    })
    {
      scream = {
        playback = {
          cli.command = escapeShellArgs ([
            (getExe cfg.playback.package)
            "-o" cfg.playback.backend
          ] ++ optionals (cfg.mode == "ivshmem") [
            "-m" cfg.ivshmem.path
          ] ++ optionals (cfg.mode == "ip") (
            optionals (cfg.ip.port != defaults.port) [
              "-p" (toString cfg.ip.port)
            ] ++ optional (cfg.ip.mode == "unicast") "-u"
            ++ optionals (cfg.playback.interface != null) [
              "-i" cfg.playback.interface
            ] ++ optionals (cfg.ip.mode == "multicast" && cfg.ip.multicast.address != defaults.multicast) [
              "-g" cfg.ip.multicast.address
            ]
          ) ++ optionals (cfg.playback.latency.target != null) [
            "-t" (toString cfg.playback.latency.target)
          ] ++ optionals (cfg.playback.latency.max != null) [
            "-l" (toString cfg.playback.latency.max)
          ] ++ cfg.playback.cli.extraArgs);
        };
      };
    }
  ];
}
