{ config, lib, ... }: with lib; let
  inherit (config) networking;
  cfg = config.services.mradio;
in {
  imports = [ ./mkchromecast.nix ];

  options.services.mradio = with types; {
    enable = mkEnableOption "mradio";
    targetDevice = mkOption {
      type = nullOr str;
      default = null;
    };
    url = mkOption {
      type = str;
    };
    user = mkOption {
      type = nullOr str;
      default = null;
    };
  };
  config = mkIf cfg.enable {
    programs.mkchromecast.enable = mkDefault cfg.enable;
    systemd.services.mradio = {
      path = [ config.programs.mkchromecast.package ];
      script = "exec mkchromecast " + cli.toGNUCommandLineShell { } {
        n  = optional (cfg.targetDevice != null) cfg.targetDevice;
        source-url = cfg.url;
      };
      serviceConfig = {
        User = mkIf (cfg.user != null) "arc";
        Type = "exec";
        Restart = "on-failure";
        RestartSec = 1;
      };
      unitConfig = {
        StartLimitBurst = 5;
        StartLimitIntervalSec = 8;
      };
    };
  };
}
