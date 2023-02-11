{ config, lib, pkgs, inputs, ... }: with lib; let
  cfg = config.qemucomm;
in {
  options = {
    qemucomm = {
      enable = mkEnableOption "qemucomm" // {
        default = true;
      };
      package = mkOption {
        type = types.package;
        default = pkgs.callPackage (inputs.qemucomm.outPath + "/derivation.nix") { };
      };
    };
    exec = {
      qmp = mkOption {
        type = with types; nullOr package;
        default = null;
      };
      qga = mkOption {
        type = with types; nullOr package;
        default = null;
      };
    };
  };
  config.exec = {
    qga = mkIf (cfg.enable && config.qga.enable) (pkgs.writeShellScriptBin "qga-${config.name}" ''
      export QEMUCOMM_QGA_SOCKET_PATH=${config.qga.path}
      ${cfg.package}/bin/qga "$@"
    '');
    qmp = mkIf (cfg.enable && config.qmp.enable) (pkgs.writeShellScriptBin "qmp-${config.name}" ''
      export QEMUCOMM_QMP_SOCKET_PATH=${config.qmp.path}
      ${cfg.package}/bin/qmp "$@"
    '');
  };
}
