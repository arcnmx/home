{ pkgs, config, lib, ... }: with lib; let
  cfg = config.programs.yggdrasil-7n;
in {
  options = {
    programs.yggdrasil-7n.enable = mkEnableOption "yggdrasil-7n";
  };

  config = mkIf cfg.enable {
    home.shell.aliases = {
      "7ctl" = "${pkgs.arc.yggdrasilctl-7n.exec} -endpoint=unix:///run/yggdrasil-7n.sock";
    };
  };
}
