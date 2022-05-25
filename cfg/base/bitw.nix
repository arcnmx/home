{ pkgs, config, lib, ... }: with lib; let
  cfg = config.programs.bitw;
in {
  options.programs.bitw = {
    enable = mkEnableOption "rbw-bitw";
    package = mkOption {
      type = types.package;
      default = pkgs.rbw-bitw;
    };
  };
  config.home.packages = mkIf cfg.enable [
    cfg.package
  ];
}
