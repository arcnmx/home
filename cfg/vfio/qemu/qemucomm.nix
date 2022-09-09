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
        default = pkgs.qemucomm or (pkgs.callPackage (inputs.qemucomm.outPath + "/derivation.nix") {
          _arg'qemucomm = inputs.qemucomm.outPath;
        });
      };
    };
    exec = {
      qmp = mkOption {
        type = with types; nullOr package;
        default = null;
      };
    };
  };
  config.exec = {
    qmp = mkIf (cfg.enable && config.qmp.enable) (pkgs.writeShellScriptBin "qmp-${config.name}" ''
      export QEMUCOMM_QMP_SOCKET_PATH=${config.qmp.path}
      ${cfg.package}/bin/qmp "$@"
    '');
  };
}
