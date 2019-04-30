{ pkgs, config, lib, ... }: with lib; let
  cfg = config.services.yggdrasil-7n;
in {
  options.services.yggdrasil-7n = {
    enable = mkEnableOption "yggdrasil-7n";
    group = mkOption {
      type = types.str;
      default = "yggdrasil";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.arc.yggdrasil-7n;
    };
    configFile = mkOption {
      type = types.path;
    };
  };

  config = mkIf cfg.enable {
    systemd.services.yggdrasil-7n = {
      description = "yggdrasil-7n";
      wants = ["network.target"];
      after = ["network.target"];

      serviceConfig = {
        Group = cfg.group;
        ProtectHome = true;
        ProtectSystem = true;
        SyslogIdentifier = "yggdrasil-7n";
        ExecStart = "${cfg.package}/bin/yggdrasil -useconffile ${cfg.configFile}";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        Restart = "always";
      };

      wantedBy = ["multi-user.target"];
    };
  };
}
