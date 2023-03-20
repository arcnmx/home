{ config, lib, ... }: with lib; let
  cfg = config.nix.build;
in {
  options.nix.build = with types; {
    enable = mkEnableOption "nix build directory" // {
      default = config.boot.tmpOnTmpfs;
    };
    path = mkOption {
      type = types.path;
      default = "/nix/var/tmp";
    };
  };
  config = mkIf cfg.enable {
    systemd = {
      tmpfiles.rules = [
        "R! ${cfg.path}"
        "d ${cfg.path} 1777 root root -"
      ];
      services.nix-daemon = {
        environment.TMPDIR = "/tmp";
        serviceConfig.BindPaths = [
          "${cfg.path}:/tmp"
        ];
      };
    };
  };
}
