{ pkgs, nixosConfig, config, lib, ... }: with lib; let
  cfg = config.services.idle;
in {
  options.services.idle = with types; {
    enable = mkEnableOption "idle service";
    xss-lock = {
      arguments = mkOption {
        type = listOf str;
        default = [];
      };
      command = mkOption {
        type = listOf str;
        default = [ "${nixosConfig.services.dpms-standby.control}" "start" ];
      };
      package = mkOption {
        type = package;
        default = pkgs.xss-lock;
        defaultText = "pkgs.xss-lock";
      };
    };
  };
  config.services.idle = {
    xss-lock = {
      arguments = [ "--ignore-sleep" ];
    };
  };
  config.systemd.user.services.idle = mkIf cfg.enable {
    Unix = rec {
      WantedBy = "graphical-session.target";
      BindsTo = WantedBy;
    };
    Service = {
      ExecStart = [
        ''${getExe cfg.xss-lock.package} ${escapeShellArgs cfg.xss-lock.arguments} -- ${escapeShellArgs cfg.xss-lock.command}''
      ];
    };
  };
}
