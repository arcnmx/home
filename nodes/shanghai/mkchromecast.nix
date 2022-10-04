{ pkgs, config, lib, ... }: with lib; let
  cfg = config.programs.mkchromecast;
in {
  options.programs.mkchromecast = {
    enable = mkEnableOption "mkchromecast";
    package = mkOption {
      type = types.package;
      default = pkgs.mkchromecast;
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = singleton cfg.package;
  };
}
