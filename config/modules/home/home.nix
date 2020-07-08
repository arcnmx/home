{ lib, meta, config, ... }: with lib; {
  options.home = {
    hostName = mkOption {
      type = types.nullOr types.str;
      default = null;
    };
    nixosConfig = mkOption {
      type = types.nullOr types.unspecified;
      default = null;
    };
  };
  config = {
    home.nix.nixPath = mapAttrs (_: path: mkForce (toString path)) meta.channels.imports;
    _module.args = {
      pkgs = mkIf (config.home.nixosConfig == null) (mkForce meta.channels.nixpkgs);
      pkgs_i686 = mkForce null;
    };
  };
}
