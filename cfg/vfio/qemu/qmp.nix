{ pkgs, config, lib, ... }: with lib; let
  cfg = config.qmp;
in {
  options = {
    qmp = {
      enable = mkEnableOption "QMP";
      path = mkOption {
        type = with types; nullOr path;
        default = config.state.runtimePath + "/qmp";
      };
      monitorPath = mkOption {
        type = with types; nullOr path;
        default = config.state.runtimePath + "/monitor";
      };
    };
    exec = {
      monitor = mkOption {
        type = with types; nullOr package;
        default = null;
      };
    };
  };
  config = mkIf cfg.enable (mkMerge [
    (mkIf (cfg.path != null) {
      chardevs.qmp.settings = {
        backend = "socket";
        id = "qmpsock";
        inherit (cfg) path;
        server = true;
        wait = false;
      };
      monitors.qmp = {
        cli.dependsOn = [ config.chardevs.qmp.id ];
        settings = {
          mode = "control";
          chardev = config.chardevs.qmp.id;
        };
      };
    })
    (mkIf (cfg.monitorPath != null) {
      chardevs.monitor.settings = {
        backend = "socket";
        id = "monitorsock";
        path = cfg.monitorPath;
        server = true;
        wait = false;
      };
      monitors.monitor = {
        cli.dependsOn = [ config.chardevs.monitor.id ];
        settings = {
          mode = "readline";
          chardev = config.chardevs.monitor.id;
        };
      };
      exec.monitor = pkgs.writeShellScriptBin "mon-${config.name}" ''
        ${pkgs.socat}/bin/socat UNIX-CONNECT:${cfg.monitorPath} STDIO "$@"
      '';
    })
  ]);
}
